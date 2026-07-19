classdef PauseToken < handle
    properties (SetAccess=private), IsPaused=false; end
    methods
        function pause(obj), obj.IsPaused=true; end
        function resume(obj), obj.IsPaused=false; end
        function wait(obj,cancellation)
            while obj.IsPaused
                cancellation.throwIfCancellationRequested();
                drawnow limitrate;
                pause(0.05);
            end
        end
    end
end
