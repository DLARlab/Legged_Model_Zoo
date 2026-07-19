classdef AnimationController < handle
    properties, Result; Renderer; Model; CurrentTime=0; Speed=1; Repeat=false; State='stopped'; Side='post'; end
    methods
        function obj=AnimationController(result,renderer,model),obj.Result=result;obj.Renderer=renderer;obj.Model=model;if ~isempty(result.time),obj.CurrentTime=result.time(1);end,end
        function frame=seek(obj,t),obj.CurrentTime=min(max(t,obj.Result.time(1)),obj.Result.time(end));x=lmz.hybrid.TrajectoryInterpolator.sample(obj.Result,obj.CurrentTime,obj.Side);k=obj.Model.kinematics(x,obj.Result.parameters,struct('time',obj.CurrentTime));frame=struct('time',obj.CurrentTime,'state',x,'kinematics',k,'event_side',obj.Side);obj.Renderer.update(frame);end
        function play(obj,callback),if nargin<2,callback=[];end;obj.State='playing';timeline=unique(obj.Result.time,'stable');for i=1:numel(timeline),if ~strcmp(obj.State,'playing'),break;end;frame=obj.seek(timeline(i));if ~isempty(callback),callback(frame);end;drawnow limitrate;end;if strcmp(obj.State,'playing'),obj.State='stopped';end,end
        function pause(obj),obj.State='paused';end
        function stop(obj),obj.State='stopped';obj.CurrentTime=obj.Result.time(1);end
    end
end
