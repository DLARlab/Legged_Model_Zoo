classdef BranchInteractionController < handle
    %BRANCHINTERACTIONCONTROLLER Multiplex branch input without callback loss.
    properties (SetAccess=private)
        Figure = []
    end
    properties (Access=private)
        MotionFcn = []
        KeyFcn = []
        PriorMotionFcn = []
        PriorKeyFcn = []
    end

    methods
        function obj=BranchInteractionController(figureHandle,motionFcn,keyFcn)
            if nargin>=1&&~isempty(figureHandle)
                obj.attach(figureHandle,motionFcn,keyFcn);
            end
        end

        function attach(obj,figureHandle,motionFcn,keyFcn)
            obj.detach();obj.Figure=figureHandle;
            obj.MotionFcn=motionFcn;obj.KeyFcn=keyFcn;
            obj.PriorMotionFcn=figureHandle.WindowButtonMotionFcn;
            obj.PriorKeyFcn=figureHandle.KeyPressFcn;
            figureHandle.WindowButtonMotionFcn=@(source,event) ...
                obj.dispatchMotion(source,event);
            figureHandle.KeyPressFcn=@(source,event) ...
                obj.dispatchKey(source,event);
        end

        function detach(obj)
            if ~isempty(obj.Figure)&&isvalid(obj.Figure)
                obj.Figure.WindowButtonMotionFcn=obj.PriorMotionFcn;
                obj.Figure.KeyPressFcn=obj.PriorKeyFcn;
            end
            obj.Figure=[];obj.MotionFcn=[];obj.KeyFcn=[];
            obj.PriorMotionFcn=[];obj.PriorKeyFcn=[];
        end

        function delete(obj),obj.detach();end
    end

    methods (Access=private)
        function dispatchMotion(obj,source,event)
            invoke(obj.MotionFcn,source,event);invoke(obj.PriorMotionFcn,source,event);
        end
        function dispatchKey(obj,source,event)
            invoke(obj.KeyFcn,source,event);invoke(obj.PriorKeyFcn,source,event);
        end
    end
end

function invoke(callback,source,event)
if isempty(callback),return,end
try
    if iscell(callback),feval(callback{:});else,callback(source,event);end
catch
end
end
