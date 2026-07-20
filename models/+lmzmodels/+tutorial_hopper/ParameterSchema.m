classdef ParameterSchema
    %PARAMETERSCHEMA Physical parameters for the tutorial hopper.
    methods (Static)
        function value = create()
            value = lmz.schema.VariableSchema( ...
                lmz.schema.VariableSpec('gravity', 'Unit', 'm/s^2', ...
                'DefaultValue', 9.81, 'LowerBound', 0.1, ...
                'UpperBound', 50, 'Scale', 10, 'Topology', 'bounded'));
        end
    end
end
