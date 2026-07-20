classdef GenericResetMap < lmz.simulation.ResetMap
    properties (SetAccess = private), Id, end
    methods
        function obj = GenericResetMap(id), obj.Id = id; end
        function value = apply(obj, event, ~, preState, parameters, context) %#ok<INUSD>
            context.check(); value = preState(:);
            switch obj.Id
                case 'increment'
                    value(1) = value(1) + parameters.increment;
                case 'guard_reset'
                    value(1) = parameters.resetValue;
                otherwise
                    error('lmztest:Reset', 'Unknown generic reset map.');
            end
        end
    end
end
