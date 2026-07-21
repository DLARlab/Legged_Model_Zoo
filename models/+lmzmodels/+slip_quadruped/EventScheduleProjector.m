classdef EventScheduleProjector
    %EVENTSCHEDULEPROJECTOR Explicit, opt-in legacy timing projection.
    methods
        function [candidate, diagnostics] = project(~, solution, options, context)
            if nargin < 3, options = struct(); end
            if nargin < 4, context = lmz.api.RunContext.synchronous(0); end
            context.check();
            enforce = isfield(options,'EnforceGroundContact') && options.EnforceGroundContact;
            decision = solution.DecisionValues;
            before = decision(14:22);
            if enforce
                provider=lmzmodels.slip_quadruped.ContactConstraintProvider();
                schedule=lmz.schedule.EventSchedule.fromCyclic( ...
                    provider.eventNames(),before(1:8),before(9), ...
                    'StartSectionId','apex','StopSectionId','apex');
                registry=lmz.registry.ModelRegistry.discover();
                model=registry.createModel(solution.ModelId);
                problem=model.createProblem('section_return_timing',struct( ...
                    'InitialState',decision(1:13), ...
                    'PhysicalParameters',solution.ParameterValues, ...
                    'EventSchedule',schedule));
                solverOptions=options;
                if isfield(solverOptions,'EnforceGroundContact')
                    solverOptions=rmfield(solverOptions,'EnforceGroundContact');
                end
                timing=lmz.services.ContactTimingService().solve(problem, ...
                    schedule,solverOptions,context);
                after=[timing.SolvedSchedule.namedTimes(provider.eventNames()); ...
                    timing.SolvedSchedule.ReturnTime];
                method = 'contact-timing-service-v1';
            else
                after = lmzmodels.slip_quadruped.legacy.EventTimingRegulation(before);
                after = after(:);
                method = 'cyclic-wrap';
            end
            decision(14:22) = after;
            candidate = solution.withDecisionValues(decision);
            diagnostics = struct('Method',method,'Before',before(:), ...
                'After',after(:),'ChangeNorm',norm(after(:)-before(:)), ...
                'HiddenRepairInResidual',false);
            if enforce
                diagnostics.SolverDiagnostics=timing.SolverDiagnostics;
                diagnostics.FixedInitialState=timing.FixedInitialState;
                diagnostics.FixedPhysicalParameters=timing.FixedPhysicalParameters;
            end
        end
    end
end
