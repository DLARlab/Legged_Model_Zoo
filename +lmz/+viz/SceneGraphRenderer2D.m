classdef SceneGraphRenderer2D < lmz.viz.Renderer
    properties, Axes; Model; Spec; Handles=struct(); end
    methods
        function initialize(obj,ax,model,spec,first),obj.Axes=ax;obj.Model=model;obj.Spec=spec;cla(ax);hold(ax,'on');axis(ax,'equal');if isfield(spec,'camera'),xlim(ax,spec.camera.xlim);ylim(ax,spec.camera.ylim);end;obj.Handles.body=plot(ax,NaN,NaN,'o','MarkerSize',14,'MarkerFaceColor',[.1 .2 .4]);if ~isempty(first),obj.update(first);end,end
        function update(obj,frame),if isfield(frame,'kinematics')&&isfield(frame.kinematics,'body'),b=frame.kinematics.body;set(obj.Handles.body,'XData',b(1),'YData',b(2));end,end
        function reset(obj),if isgraphics(obj.Axes),cla(obj.Axes);end;obj.Handles=struct();end
        function destroy(obj),f=fieldnames(obj.Handles);for i=1:numel(f),if isgraphics(obj.Handles.(f{i})),delete(obj.Handles.(f{i}));end,end;obj.Handles=struct();end
    end
end
