classdef AnimationController < handle
    %ANIMATIONCONTROLLER Synchronized normalized-time playback controller.
    properties (SetAccess=private)
        Simulation
        Renderer
        NormalizedTime = 0
        IsPlaying = false
    end
    properties
        FPS = 25
        Speed = 1
        Loop = false
        FrameChangedFcn = []
    end
    properties (Access=private)
        PauseRequested = false
        StopRequested = false
    end
    methods
        function obj=AnimationController(simulation,renderer)
            obj.Simulation=simulation;obj.Renderer=renderer;
        end
        function index=setNormalizedTime(obj,value)
            obj.NormalizedTime=max(0,min(1,value));
            index=1+round(obj.NormalizedTime*(numel(obj.Simulation.Time)-1));
            obj.Renderer.updateFrame(index);
            if isa(obj.FrameChangedFcn,'function_handle')
                obj.FrameChangedFcn(obj.NormalizedTime,index);
            end
        end
        function play(obj)
            obj.IsPlaying=true;obj.PauseRequested=false;obj.StopRequested=false;
            startIndex=1+round(obj.NormalizedTime*(numel(obj.Simulation.Time)-1));
            while obj.IsPlaying
                for index=startIndex:numel(obj.Simulation.Time)
                    if obj.StopRequested||obj.PauseRequested,obj.IsPlaying=false;break,end
                    obj.setNormalizedTime((index-1)/(numel(obj.Simulation.Time)-1));
                    pause(max(0,1/(obj.FPS*max(obj.Speed,eps))));drawnow;
                end
                if ~obj.Loop||obj.StopRequested||obj.PauseRequested,obj.IsPlaying=false;break,end
                startIndex=1;
            end
        end
        function pause(obj),obj.PauseRequested=true;obj.IsPlaying=false;end
        function stop(obj),obj.StopRequested=true;obj.IsPlaying=false;obj.setNormalizedTime(0);end
        function reset(obj),obj.PauseRequested=false;obj.StopRequested=false;obj.IsPlaying=false;obj.setNormalizedTime(0);end
    end
end
