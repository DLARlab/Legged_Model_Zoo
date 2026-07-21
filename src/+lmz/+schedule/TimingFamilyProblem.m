classdef TimingFamilyProblem < lmz.api.NonlinearEquationProblem
    %TIMINGFAMILYPROBLEM Timing residuals augmented by declarative gauges.
    properties (SetAccess=private)
        BaseProblem
        Gauges
        Provider
        InputSchedule
        ScheduleChart
        FixedInitialState
        FixedPhysicalParameters
        FixedRowPolicy
        FixedRowTolerance
        ExpectedDimension
    end

    methods
        function obj=TimingFamilyProblem(baseProblem,gauges,configuration)
            if nargin<3,configuration=struct();end
            if ~isa(baseProblem,'lmz.schedule.SectionReturnTimingProblem')
                error('lmz:Timing:FamilyBaseProblem', ...
                    ['TimingFamilyProblem requires a ' ...
                    'SectionReturnTimingProblem.']);
            end
            gauges=lmz.schedule.TimingGauge.arrayFrom(gauges);
            combined=mergeStructs(baseProblem.Configuration,configuration);
            combined.TimingFamily=true;
            combined.TimingGauges=gaugeStructs(gauges);
            empty=lmz.schema.VariableSchema( ...
                lmz.schema.VariableSpec.empty(0,1),'1.0.0');
            obj@lmz.api.NonlinearEquationProblem(baseProblem.Model, ...
                baseProblem.Id,'nonlinear_equation', ...
                baseProblem.getDecisionSchema(),empty,[],combined);
            obj.Version=baseProblem.Version;
            obj.BaseProblem=baseProblem;obj.Gauges=gauges;
            obj.Provider=baseProblem.Provider;
            obj.InputSchedule=baseProblem.InputSchedule;
            obj.ScheduleChart=baseProblem.ScheduleChart;
            obj.FixedInitialState=baseProblem.FixedInitialState;
            obj.FixedPhysicalParameters=baseProblem.FixedPhysicalParameters;
            obj.FixedRowPolicy=baseProblem.FixedRowPolicy;
            obj.FixedRowTolerance=baseProblem.FixedRowTolerance;
            fallback=1;if ~isempty(gauges),fallback=0;end
            obj.ExpectedDimension=fieldOr(configuration, ...
                'ExpectedLocalDimension',fallback);
            if ~isnumeric(obj.ExpectedDimension)|| ...
                    ~isscalar(obj.ExpectedDimension)|| ...
                    ~isfinite(obj.ExpectedDimension)|| ...
                    obj.ExpectedDimension<0|| ...
                    obj.ExpectedDimension~=fix(obj.ExpectedDimension)
                error('lmz:Timing:ExpectedLocalDimension', ...
                    'ExpectedLocalDimension must be a nonnegative integer.');
            end
        end

        function evaluation=evaluate(obj,u,p,context,includeSimulation) %#ok<INUSD>
            if nargin<5,includeSimulation=false;end
            base=obj.BaseProblem.evaluate(u,[],context,includeSimulation);
            schedule=obj.BaseProblem.scheduleFromDecision(u);
            blocks=base.ResidualBlocks;
            gaugeValues=zeros(numel(obj.Gauges),1);
            for index=1:numel(obj.Gauges)
                gaugeValues(index)=obj.Gauges(index).evaluate(schedule);
                blocks(end+1,1)=lmz.data.ResidualBlock( ...
                    ['timing_gauge_' obj.Gauges(index).Id], ...
                    gaugeValues(index),obj.Gauges(index).Scale); %#ok<AGROW>
            end
            feasibility=base.Feasibility;
            feasibility.GaugesFinite=all(isfinite(gaugeValues));
            feasibility.Valid=feasibility.Valid&&feasibility.GaugesFinite;
            diagnostics=base.Diagnostics;
            diagnostics.TimingFamily=true;
            diagnostics.TimingGauges=gaugeStructs(obj.Gauges);
            diagnostics.GaugeResiduals=gaugeValues;
            evaluation=lmz.data.ProblemEvaluation(blocks, ...
                'Simulation',base.Simulation,'Feasibility',feasibility, ...
                'PhysicalValidity',base.PhysicalValidity&& ...
                feasibility.GaugesFinite,'Warnings',base.Warnings, ...
                'Diagnostics',diagnostics);
        end

        function value=evaluateTiming(obj,schedule,context,includeSimulation)
            if nargin<4,includeSimulation=true;end
            value=obj.BaseProblem.evaluateTiming( ...
                schedule,context,includeSimulation);
        end

        function schedule=scheduleFromDecision(obj,u)
            schedule=obj.BaseProblem.scheduleFromDecision(u);
        end

        function u=decisionFromSchedule(obj,schedule)
            u=obj.BaseProblem.decisionFromSchedule(schedule);
        end

        function value=expectedLocalDimension(obj)
            value=obj.ExpectedDimension;
        end

        function value=gaugeIndependence(obj,u,p,options,context)
            if nargin<3||isempty(p),p=[];end
            if nargin<4||isempty(options),options=struct();end
            if nargin<5||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            analyzer=lmz.solvers.RankAwareNonlinearSolver();
            base=analyzer.analyze(obj.BaseProblem,u,p,options,context);
            total=analyzer.analyze(obj,u,p,options,context);
            increment=total.Rank-base.Rank;
            value=struct('BaseRank',base.Rank, ...
                'AugmentedRank',total.Rank,'RankIncrement',increment, ...
                'GaugeCount',numel(obj.Gauges), ...
                'Independent',increment==numel(obj.Gauges), ...
                'BaseNullity',base.Nullity, ...
                'AugmentedNullity',total.Nullity);
        end
    end
end

function value=gaugeStructs(gauges)
value=cell(numel(gauges),1);
for index=1:numel(gauges),value{index}=gauges(index).toStruct();end
end

function value=mergeStructs(first,second)
value=first;
if ~isstruct(value)||~isscalar(value),value=struct();end
if ~isstruct(second)||~isscalar(second)
    error('lmz:Timing:FamilyConfiguration', ...
        'Timing family configuration must be a scalar struct.');
end
names=fieldnames(second);
for index=1:numel(names),value.(names{index})=second.(names{index});end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
