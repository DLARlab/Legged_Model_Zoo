classdef FlightMode < lmz.simulation.HybridMode
    methods
        function obj = FlightMode(id)
            obj@lmz.simulation.HybridMode(id);
        end
        function value = derivative(~, ~, state, parameters, context)
            context.check();
            value = [state(2); 0; state(4); -parameters.gravity];
        end
    end
end
