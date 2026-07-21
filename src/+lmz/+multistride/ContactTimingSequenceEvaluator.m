classdef ContactTimingSequenceEvaluator < handle
    %CONTACTTIMINGSEQUENCEEVALUATOR Propagate section returns without solves.
    properties (SetAccess=private)
        Provider
        ScheduleChart
        NumberOfStrides
        LocalDecisionCount
    end

    methods
        function obj=ContactTimingSequenceEvaluator(provider,chart,count)
            if ~isa(provider,'lmz.schedule.ContactConstraintProvider')|| ...
                    ~isa(chart,'lmz.schedule.EventScheduleChart')
                error('lmz:MultiStride:TimingSequenceProvider', ...
                    'A contact provider and event-schedule chart are required.');
            end
            obj.Provider=provider;obj.ScheduleChart=chart;
            obj.NumberOfStrides=count;
            obj.LocalDecisionCount=chart.DecisionSchema.count();
        end

        function value=evaluate(obj,u,fixedInitialState, ...
                fixedPhysicalParameters,context,includeSimulation,contract) %#ok<INUSD>
            context.check();
            if contract.NumberOfStrides~=obj.NumberOfStrides|| ...
                    numel(u)~=obj.NumberOfStrides*obj.LocalDecisionCount
                error('lmz:MultiStride:TimingSequenceDimension', ...
                    'Timing-sequence decision length does not match its stride count.');
            end
            state=fixedInitialState(:);parameters=fixedPhysicalParameters(:);
            contacts=cell(obj.NumberOfStrides,1);
            sections=cell(obj.NumberOfStrides,1);
            records=cell(obj.NumberOfStrides,1);
            for stride=1:obj.NumberOfStrides
                context.check();
                rows=(stride-1)*obj.LocalDecisionCount+ ...
                    (1:obj.LocalDecisionCount);
                schedule=obj.ScheduleChart.decode(u(rows));
                result=obj.Provider.evaluate(state,parameters,schedule, ...
                    context,false);
                active=schedule.freeMask();
                contact=result.ContactResidual(:);
                contacts{stride}=contact(active);
                if schedule.ReturnTimeFixed
                    sections{stride}=zeros(0,1);
                else
                    sections{stride}=result.SectionResidual(:);
                end
                terminal=result.TerminalState(:);
                if numel(terminal)~=numel(state)||any(~isfinite(terminal))
                    error('lmz:MultiStride:TimingSequenceTerminalState', ...
                        ['Each timing-only stride must return a finite terminal ' ...
                        'state in the fixed initial-state coordinates.']);
                end
                records{stride}=struct('StrideIndex',stride, ...
                    'InputState',state,'Schedule',schedule.toStruct(), ...
                    'ContactResidual',contact, ...
                    'SectionResidual',result.SectionResidual(:), ...
                    'TerminalState',terminal, ...
                    'ProviderDiagnostics',result.Diagnostics);
                state=terminal;
            end
            residual=[vertcat(contacts{:});vertcat(sections{:})];
            value=struct('ContactResiduals',{contacts}, ...
                'SectionResiduals',{sections},'Simulation',[], ...
                'Feasibility',struct('Valid',all(isfinite(residual))), ...
                'PhysicalValidity',all(isfinite(residual)), ...
                'Diagnostics',struct('StrideEvaluations',{records}, ...
                'FinalState',state,'StatePropagation', ...
                'previous_terminal_state','PhysicalParametersFixed',true, ...
                'StatePeriodicityImposed',false,'HiddenTimingSolve',false, ...
                'NestedSolverCalls',0));
        end
    end
end
