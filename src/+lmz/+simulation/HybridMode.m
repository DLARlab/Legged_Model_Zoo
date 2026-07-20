classdef (Abstract) HybridMode < handle
    %HYBRIDMODE Continuous flow associated with one named hybrid mode.
    properties (SetAccess = private)
        Id
    end
    methods
        function obj = HybridMode(id)
            if ~ischar(id) || isempty(regexp(id, ...
                    '^[A-Za-z][A-Za-z0-9_]*$', 'once'))
                error('lmz:Hybrid:ModeId', 'Hybrid mode ID is invalid.');
            end
            obj.Id = id;
        end
    end
    methods (Abstract)
        derivative = derivative(obj, time, state, parameters, context)
    end
end
