classdef ValidationReport
    properties
        IsValid (1,1) logical = true
        Errors cell = {}
        Warnings cell = {}
        Transformations cell = {}
    end
    methods
        function obj = addError(obj, message)
            obj.IsValid = false; obj.Errors{end+1} = char(message);
        end
        function obj = addWarning(obj, message), obj.Warnings{end+1} = char(message); end
        function obj = addTransformation(obj, message), obj.Transformations{end+1} = char(message); end
        function throwIfInvalid(obj)
            if ~obj.IsValid, error('lmz:Validation', '%s', strjoin(obj.Errors, newline)); end
        end
    end
end
