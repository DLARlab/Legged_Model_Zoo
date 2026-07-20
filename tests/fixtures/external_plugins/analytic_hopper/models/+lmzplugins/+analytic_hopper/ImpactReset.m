classdef ImpactReset < lmz.simulation.ResetMap
    methods
        function postState = apply(~, ~, ~, preState, parameters, context)
            context.check();
            postState = preState(:);
            postState(3) = 0;
            postState(4) = postState(4) + parameters.impulse;
        end
    end
end
