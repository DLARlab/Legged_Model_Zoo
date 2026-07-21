classdef ContactTimingService
    %CONTACTTIMINGSERVICE Solve explicit schedules without changing fixed data.
    methods
        function result=solve(obj,problem,seed,options,context)
            if nargin<4||isempty(options), options=struct(); end
            if nargin<5||isempty(context), context=lmz.api.RunContext.synchronous(0); end
            if ~isTimingProblem(problem)
                error('lmz:Timing:ProblemType', ...
                    ['ContactTimingService requires SectionReturnTimingProblem ' ...
                    'or TimingFamilyProblem.']);
            end
            context.check();
            if isa(seed,'lmz.schedule.EventSchedule')
                seedVector=problem.decisionFromSchedule(seed);
                inputSchedule=seed;
            elseif isa(seed,'lmz.data.Solution')
                seedVector=seed.DecisionValues;
                inputSchedule=problem.scheduleFromDecision(seedVector);
            else
                seedVector=seed(:);
                inputSchedule=problem.scheduleFromDecision(seedVector);
            end
            fixedState=problem.FixedInitialState;
            fixedParameters=problem.FixedPhysicalParameters;
            optionStruct=obj.optionStruct(options);
            multistart=obj.fieldOr(optionStruct,'MultistartCount',1);
            perturbation=obj.fieldOr(optionStruct,'MultistartScale',0.05);
            if ~isnumeric(multistart)||~isscalar(multistart)||multistart<1|| ...
                    multistart~=floor(multistart)
                error('lmz:Timing:MultistartCount', ...
                    'MultistartCount must be a positive integer.');
            end
            solverOptions=rmfieldIfPresent(optionStruct, ...
                {'MultistartCount','MultistartScale'});
            stream=RandStream('mt19937ar','Seed',context.RandomSeed);
            best=[]; attempts=repmat(struct('Index',0,'ExitFlag',0, ...
                'ResidualNorm',Inf,'MaximumPhysicalViolation',Inf, ...
                'PhysicalValid',false,'Status','not_run','Seed',[], ...
                'SolverSelected','','Rank',0,'Nullity',0),multistart,1);
            bestScore=[];bestRank=struct();
            for index=1:multistart
                context.check(); trialSeed=seedVector;
                if index>1
                    trialSeed=trialSeed+perturbation*randn(stream,size(trialSeed));
                end
                [solved,rankDiagnostics]= ...
                    lmz.solvers.RankAwareNonlinearSolver().solve( ...
                    problem,trialSeed,[],solverOptions,context);
                physicalValid=logicalField( ...
                    solved.Evaluation.Feasibility,'Valid',false);
                maximumViolation=physicalViolation( ...
                    solved.Evaluation.Feasibility);
                accepted=physicalValid&&solved.ExitFlag>0;
                attemptStatus=conditionalText(accepted,'accepted','rejected');
                attempts(index)=struct('Index',index,'ExitFlag',solved.ExitFlag, ...
                    'ResidualNorm',solved.Evaluation.ScaledResidualNorm, ...
                    'MaximumPhysicalViolation',maximumViolation, ...
                    'PhysicalValid',physicalValid,'Status',attemptStatus, ...
                    'Seed',trialSeed,'SolverSelected', ...
                    rankDiagnostics.SolverSelected,'Rank', ...
                    rankDiagnostics.Rank,'Nullity',rankDiagnostics.Nullity);
                score=[~accepted,~physicalValid,maximumViolation, ...
                    solved.Evaluation.ScaledResidualNorm];
                if isempty(best)||lexicographicallyLess(score,bestScore)
                    best=solved;bestScore=score;bestRank=rankDiagnostics;
                end
            end
            solvedSchedule=problem.scheduleFromDecision(best.Solution.DecisionValues);
            details=problem.evaluateTiming(solvedSchedule,context,true);
            finalEvaluation=problem.evaluate( ...
                best.Solution.DecisionValues,[],context,false);
            if ~isequaln(fixedState,problem.FixedInitialState)|| ...
                    ~isequaln(fixedParameters,problem.FixedPhysicalParameters)
                error('lmz:Timing:FixedDataMutated', ...
                    'Timing solve changed fixed initial state or physical parameters.');
            end
            descriptor=problem.getDescriptor();
            residualTolerance=obj.fieldOr(optionStruct, ...
                'ResidualTolerance',1e-8);
            validateTolerance(residualTolerance,'ResidualTolerance');
            gaugeDiagnostics=struct();
            if isa(problem,'lmz.schedule.TimingFamilyProblem')
                gaugeDiagnostics=problem.gaugeIndependence( ...
                    best.Solution.DecisionValues,[],solverOptions,context);
            end
            criteria=successCriteria(best,finalEvaluation, ...
                solvedSchedule,residualTolerance,bestRank, ...
                problem.expectedLocalDimension(),gaugeDiagnostics, ...
                rankConditionRequired(problem));
            status=solveStatus(criteria,finalEvaluation);
            diagnostics=struct('ExitFlag',best.ExitFlag,'Output',best.Output, ...
                'ResidualNorm',best.Evaluation.ScaledResidualNorm, ...
                'Attempts',attempts,'Options',optionStruct, ...
                'Status',status,'Success',criteria.Success, ...
                'TerminationReason',terminationReason(status,best.ExitFlag), ...
                'SuccessCriteria',criteria,'Feasibility', ...
                finalEvaluation.Feasibility,'RankDiagnostics',bestRank, ...
                'GaugeDiagnostics',gaugeDiagnostics, ...
                'ProblemConfiguration', ...
                serializableConfiguration(problem.Configuration), ...
                'InitialStateBitwiseUnchanged', ...
                isequaln(fixedState,problem.FixedInitialState), ...
                'PhysicalParametersBitwiseUnchanged', ...
                isequaln(fixedParameters,problem.FixedPhysicalParameters), ...
                'NoPeriodicityResidual',true);
            values=struct('ModelId',descriptor.modelId,'ProblemId',problem.Id, ...
                'FixedInitialState',fixedState,'FixedPhysicalParameters',fixedParameters, ...
                'InputSchedule',inputSchedule,'SolvedSchedule',solvedSchedule, ...
                'FreeMask',[solvedSchedule.freeMask();~solvedSchedule.ReturnTimeFixed], ...
                'FixedMask',[solvedSchedule.fixedMask();solvedSchedule.ReturnTimeFixed], ...
                'ContactResiduals',details.ContactResidual(:), ...
                'SectionResidual',details.SectionResidual(:), ...
                'TerminalState',details.TerminalState(:), ...
                'SectionCrossing',details.SectionCrossing, ...
                'Simulation',details.Simulation,'SolverDiagnostics',diagnostics, ...
                'RandomSeed',context.RandomSeed,'Provenance',struct( ...
                'service','ContactTimingService','formulation', ...
                'rank-aware-explicit-fixed-state-fixed-physics-v2'));
            result=lmz.data.ContactTimingResult(values);
            context.progress(1,'Contact timing solve complete.');
        end
    end

    methods (Static, Access=private)
        function value=optionStruct(options)
            if isa(options,'lmz.solvers.SolverOptions')
                value=options.toStruct();
            elseif isstruct(options)&&isscalar(options)
                value=options;
            else
                error('lmz:Timing:SolverOptions', ...
                    'Solver options are invalid.');
            end
        end
        function value=fieldOr(source,name,fallback)
            if isfield(source,name), value=source.(name); else, value=fallback; end
        end
    end
end

function value=rmfieldIfPresent(value,names)
for index=1:numel(names)
    if isfield(value,names{index}), value=rmfield(value,names{index}); end
end
end

function value=isTimingProblem(problem)
value=isa(problem,'lmz.schedule.SectionReturnTimingProblem')|| ...
    isa(problem,'lmz.schedule.TimingFamilyProblem');
end

function value=physicalViolation(feasibility)
value=0;
if isstruct(feasibility)&&isfield(feasibility,'MaximumFixedResidual')&& ...
        isfinite(feasibility.MaximumFixedResidual)
    tolerance=0;
    if isfield(feasibility,'FixedRowTolerance')
        tolerance=feasibility.FixedRowTolerance;
    end
    value=max(0,feasibility.MaximumFixedResidual-tolerance);
end
checks={'EventOrderValid','FixedRowsValid','SectionCrossingAccepted', ...
    'FiniteData','EnergyValid'};
for index=1:numel(checks)
    if isstruct(feasibility)&&isfield(feasibility,checks{index})&& ...
            ~logical(feasibility.(checks{index}))
        value=max(value,1);
    end
end
end

function value=logicalField(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name)&&isscalar(source.(name))
    value=logical(source.(name));
end
end

function value=conditionalText(condition,yes,no)
if condition,value=yes;else,value=no;end
end

function valid=lexicographicallyLess(first,second)
valid=false;
for index=1:numel(first)
    if first(index)<second(index),valid=true;return,end
    if first(index)>second(index),return,end
end
end

function criteria=successCriteria(result,evaluation,schedule,tolerance, ...
        rankDiagnostics,expectedNullity,gaugeDiagnostics,rankRequired)
feasibility=evaluation.Feasibility;
gaps=diff([0;schedule.times();schedule.ReturnTime]);
eventOrder=all(isfinite(gaps))&&all(gaps>schedule.MinimumGap);
criteria=struct('SolverTerminationAcceptable',result.ExitFlag>0, ...
    'ActiveResidualValid',evaluation.ScaledResidualNorm<=tolerance, ...
    'ActiveResidualTolerance',tolerance, ...
    'FixedRowsValid',logicalField(feasibility,'FixedRowsValid',true), ...
    'SectionCrossingAccepted',logicalField(feasibility, ...
    'SectionCrossingAccepted',false),'EventOrderValid',eventOrder, ...
    'FiniteData',logicalField(feasibility,'FiniteData',false), ...
    'EnergyValid',logicalField(feasibility,'EnergyValid',true), ...
    'RankConditionValid',rankDiagnostics.Nullity==expectedNullity, ...
    'RankConditionRequired',logical(rankRequired), ...
    'UniquenessValidated',rankDiagnostics.Nullity==0, ...
    'ExpectedNullity',expectedNullity, ...
    'GaugeIndependenceValid',gaugeIndependence(gaugeDiagnostics));
values=[criteria.SolverTerminationAcceptable, ...
    criteria.ActiveResidualValid,criteria.FixedRowsValid, ...
    criteria.SectionCrossingAccepted,criteria.EventOrderValid, ...
    criteria.FiniteData,criteria.EnergyValid, ...
    (~criteria.RankConditionRequired||criteria.RankConditionValid), ...
    criteria.GaugeIndependenceValid];
criteria.Success=all(values);
if criteria.UniquenessValidated
    criteria.RankQualification='isolated_root_rank_validated';
elseif criteria.RankConditionValid
    criteria.RankQualification='configured_family_dimension_validated';
else
    criteria.RankQualification= ...
        'rank_deficient_root_not_a_unique_parameterization';
end
end

function value=gaugeIndependence(diagnostics)
value=true;
if isstruct(diagnostics)&&isfield(diagnostics,'Independent')
    value=logical(diagnostics.Independent);
end
end

function value=rankConditionRequired(problem)
value=isa(problem,'lmz.schedule.TimingFamilyProblem');
if isstruct(problem.Configuration)&& ...
        isfield(problem.Configuration,'RequireRankCondition')
    configured=problem.Configuration.RequireRankCondition;
    if ~(islogical(configured)||isnumeric(configured))|| ...
            ~isscalar(configured)||~isfinite(configured)|| ...
            ~ismember(configured,[0 1])
        error('lmz:Timing:RequireRankCondition', ...
            'RequireRankCondition must be a logical scalar.');
    end
    value=logical(configured);
end
end

function value=solveStatus(criteria,evaluation)
if criteria.Success,value='converged';return,end
if ~criteria.FiniteData||any(~isfinite(evaluation.ScaledResidual))
    value='invalid';
elseif ~criteria.FixedRowsValid|| ...
        ~criteria.SectionCrossingAccepted||~criteria.EventOrderValid|| ...
        ~criteria.EnergyValid
    value='infeasible';
elseif criteria.SolverTerminationAcceptable&&criteria.ActiveResidualValid
    value='infeasible';
else
    value='numerical_failure';
end
end

function value=terminationReason(status,exitFlag)
if strcmp(status,'converged')
    value='all_success_criteria_satisfied';
elseif strcmp(status,'infeasible')
    value='physical_validation_failed';
elseif strcmp(status,'invalid')
    value='invalid_nonfinite_result';
elseif exitFlag==0
    value='iteration_or_evaluation_limit';
else
    value='solver_failure';
end
end

function validateTolerance(value,name)
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)||value<0
    error('lmz:Timing:Tolerance','%s must be finite and nonnegative.',name);
end
end

function value=serializableConfiguration(source)
if isa(source,'lmz.schedule.EventSchedule')
    value=source.toStruct();
elseif isa(source,'lmz.schedule.TimingGauge')
    value=source.toStruct();
elseif isstruct(source)
    value=source;
    names=fieldnames(source);
    for index=1:numel(names)
        value.(names{index})=serializableConfiguration(source.(names{index}));
    end
elseif iscell(source)
    value=cell(size(source));
    for index=1:numel(source)
        value{index}=serializableConfiguration(source{index});
    end
elseif isa(source,'function_handle')
    error('lmz:Timing:ConfigurationCallback', ...
        'Timing run configuration cannot persist callbacks.');
else
    value=source;
end
end
