classdef SectionReturnTimingProblem < lmz.api.NonlinearEquationProblem
    %SECTIONRETURNTIMINGPROBLEM Event/return timing with fixed state/physics.
    properties (SetAccess=private)
        Provider
        InputSchedule
        ScheduleChart
        FixedInitialState
        FixedPhysicalParameters
    end

    methods
        function obj=SectionReturnTimingProblem(model,id,provider, ...
                initialState,physicalParameters,schedule,configuration)
            if nargin<7, configuration=struct(); end
            if ~isa(provider,'lmz.schedule.ContactConstraintProvider')
                error('lmz:Timing:ProviderType', ...
                    'Timing problems require a ContactConstraintProvider.');
            end
            if ~isnumeric(initialState)||~isreal(initialState)|| ...
                    any(~isfinite(initialState(:)))
                error('lmz:Timing:InitialState', ...
                    'Fixed initial state must be finite real numeric data.');
            end
            if ~isnumeric(physicalParameters)||~isreal(physicalParameters)|| ...
                    any(~isfinite(physicalParameters(:)))
                error('lmz:Timing:PhysicalParameters', ...
                    'Fixed physical parameters must be finite real numeric data.');
            end
            chart=lmz.schedule.EventScheduleChart(schedule);
            emptyParameters=lmz.schema.VariableSchema( ...
                lmz.schema.VariableSpec.empty(0,1),'1.0.0');
            obj@lmz.api.NonlinearEquationProblem(model,id, ...
                'nonlinear_equation',chart.DecisionSchema,emptyParameters,[],configuration);
            obj.Version='1.0.0';
            obj.Provider=provider;
            obj.InputSchedule=schedule;
            obj.ScheduleChart=chart;
            obj.FixedInitialState=initialState(:);
            obj.FixedPhysicalParameters=physicalParameters(:);
            expected=chart.Schema.freeCount();
            actual=numel(obj.evaluate(chart.DecisionSchema.defaults(),[], ...
                lmz.api.RunContext.synchronous(0),false).Residual);
            if expected~=actual
                error('lmz:Timing:DimensionMismatch', ...
                    ['Timing problem has %d free variables but %d explicit ' ...
                    'contact/section residuals. Adjust the fixed/free mask.'], ...
                    expected,actual);
            end
        end

        function evaluation=evaluate(obj,u,p,context,includeSimulation) %#ok<INUSD>
            if nargin<5, includeSimulation=false; end
            context.check();
            obj.DecisionSchema.validateVector(u);
            schedule=obj.ScheduleChart.decode(u);
            value=obj.evaluateTiming(schedule,context,includeSimulation);
            contact=value.ContactResidual(:);
            if numel(contact)~=schedule.count()
                error('lmz:Timing:ProviderContactCount', ...
                    'Provider contact rows must match scheduled events.');
            end
            activeContact=schedule.freeMask();
            blocks=lmz.data.ResidualBlock.empty(0,1);
            if any(activeContact)
                blocks(end+1,1)=lmz.data.ResidualBlock( ...
                    'contact_constraints',contact(activeContact), ...
                    ones(sum(activeContact),1));
            end
            if ~schedule.ReturnTimeFixed
                blocks(end+1,1)=lmz.data.ResidualBlock('section_return', ...
                    value.SectionResidual(:), ...
                    ones(numel(value.SectionResidual),1));
            end
            if includeSimulation, simulation=value.Simulation; else, simulation=[]; end
            feasibility=struct('Valid',all(isfinite([value.ContactResidual(:); ...
                value.SectionResidual(:)])),'EventOrderValid',true);
            diagnostics=struct('Formulation','timing-only-section-return-v1', ...
                'HiddenPeriodicityResidual',false,'FixedInitialState', ...
                obj.FixedInitialState,'FixedPhysicalParameters', ...
                obj.FixedPhysicalParameters,'SolvedSchedule',schedule.toStruct(), ...
                'TerminalState',value.TerminalState, ...
                'SectionCrossing',obj.serializable(value.SectionCrossing), ...
                'FixedEventResiduals',contact(~activeContact), ...
                'FixedReturnSectionResidual',conditionalValue( ...
                schedule.ReturnTimeFixed,value.SectionResidual(:)), ...
                'ProviderDiagnostics',value.Diagnostics);
            evaluation=lmz.data.ProblemEvaluation(blocks, ...
                'Simulation',simulation,'Feasibility',feasibility, ...
                'PhysicalValidity',feasibility.Valid,'Diagnostics',diagnostics);
        end

        function value=evaluateTiming(obj,schedule,context,includeSimulation)
            if nargin<4, includeSimulation=true; end
            value=obj.Provider.evaluate(obj.FixedInitialState, ...
                obj.FixedPhysicalParameters,schedule,context,includeSimulation);
            required={'ContactResidual','SectionResidual','TerminalState', ...
                'SectionCrossing','Simulation','Diagnostics'};
            for index=1:numel(required)
                if ~isfield(value,required{index})
                    error('lmz:Timing:ProviderContract', ...
                        'Contact provider omitted %s.',required{index});
                end
            end
        end

        function schedule=scheduleFromDecision(obj,u)
            schedule=obj.ScheduleChart.decode(u);
        end

        function u=decisionFromSchedule(obj,schedule)
            u=obj.ScheduleChart.encode(schedule);
        end
    end

    methods (Static, Access=private)
        function value=serializable(item)
            if isobject(item)&&ismethod(item,'toStruct')
                value=item.toStruct();
            else
                value=item;
            end
        end
    end
end

function value=conditionalValue(condition,source)
if condition,value=source;else,value=zeros(0,1);end
end
