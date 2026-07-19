classdef CancellationToken < handle
    properties (SetAccess=private), IsCancellationRequested=false; end
    methods
        function cancel(obj), obj.IsCancellationRequested=true; end
        function throwIfCancellationRequested(obj)
            if obj.IsCancellationRequested, error('lmz:Cancelled','Run cancelled cooperatively.'); end
        end
    end
end
