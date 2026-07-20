classdef RunContext
    %RUNCONTEXT Cancellation, pause, progress, logging, and reproducibility state.
    properties, Cancellation; Pause; ProgressFcn; LogFcn; CheckpointFcn; RandomSeed; end
    methods (Static)
        function obj=synchronous(seed)
            if nargin<1, seed=0; end
            obj=lmz.api.RunContext(); obj.Cancellation=lmz.api.CancellationToken(); obj.Pause=lmz.api.PauseToken();
            obj.ProgressFcn=@(~,~)[]; obj.LogFcn=@(~,~)[]; obj.CheckpointFcn=@(~)[]; obj.RandomSeed=seed;
        end
    end
    methods
        function check(obj), obj.Cancellation.throwIfCancellationRequested(); obj.Pause.wait(obj.Cancellation); end
        function progress(obj,fraction,message), obj.ProgressFcn(fraction,message); end
        function log(obj,level,message), obj.LogFcn(level,message); end
        function checkpoint(obj,value), obj.CheckpointFcn(value); end
    end
end
