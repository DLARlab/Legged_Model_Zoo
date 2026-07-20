classdef (Abstract) ResetMap < handle
    %RESETMAP Discrete state update associated with a hybrid event.
    methods (Abstract)
        postState = apply(obj, event, time, preState, parameters, context)
    end
end
