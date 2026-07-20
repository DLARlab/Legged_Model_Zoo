classdef GenericHybridMode < lmz.simulation.HybridMode
    methods
        function obj = GenericHybridMode(id)
            obj@lmz.simulation.HybridMode(id);
        end
        function value = derivative(~, ~, state, parameters, context)
            context.check();
            value = zeros(size(state));
            if isfield(parameters, 'rate')
                value(1) = parameters.rate;
            end
        end
    end
end
