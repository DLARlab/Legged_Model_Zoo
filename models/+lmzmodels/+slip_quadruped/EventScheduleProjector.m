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
                [~,~,~,legacyParameters] = ...
                    lmzmodels.slip_quadruped.legacy.QuadrupedalZeroFun( ...
                    decision(1:13),before,solution.ParameterValues,{});
                after = legacyParameters(1:9).';
                method = 'legacy-ground-contact-fsolve';
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
        end
    end
end
