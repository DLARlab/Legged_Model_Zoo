classdef BipedRenderer < handle
    %BIPEDRENDERER Frame renderer for source-equivalent biped simulation.
    properties (SetAccess=private)
        Axes
        Simulation
        Handles=struct()
        CurrentIndex=1
    end
    methods
        function obj=BipedRenderer(axesHandle,simulation)
            if nargin>=1,obj.Axes=axesHandle;end
            if nargin>=2,obj.initialize(simulation);end
        end
        function initialize(obj,simulation)
            if isempty(obj.Axes)||~isgraphics(obj.Axes)
                error('lmz:Renderer:Axes','A valid axes is required.');
            end
            obj.Simulation=simulation;cla(obj.Axes);hold(obj.Axes,'on');grid(obj.Axes,'on');
            k=simulation.Kinematics;
            if isempty(fieldnames(k)),k=lmzmodels.slip_biped.KinematicsProvider.compute(simulation);end
            xmin=min(k.FootX(:));xmax=max(k.FootX(:));span=max(xmax-xmin,1);
            obj.Handles.Ground=plot(obj.Axes,[xmin-0.1*span xmax+0.1*span],[0 0], ...
                'k-','LineWidth',1.5);
            obj.Handles.Center=plot(obj.Axes,nan,nan,'ko','MarkerFaceColor',[0.12 0.12 0.12], ...
                'MarkerSize',10);
            colors=[0.12 0.48 0.85;0.9 0.35 0.18];
            obj.Handles.Legs=gobjects(1,2);obj.Handles.Feet=gobjects(1,2);
            for leg=1:2
                obj.Handles.Legs(leg)=plot(obj.Axes,nan(1,2),nan(1,2),'-', ...
                    'Color',colors(leg,:),'LineWidth',3);
                obj.Handles.Feet(leg)=plot(obj.Axes,nan,nan,'o','Color',colors(leg,:), ...
                    'MarkerSize',7,'MarkerFaceColor','w');
            end
            obj.Handles.Phase=text(obj.Axes,0,0,'','VerticalAlignment','top','FontWeight','bold');
            axis(obj.Axes,'equal');xlim(obj.Axes,[xmin-0.05*span xmax+0.05*span]);
            ylim(obj.Axes,[-0.05 max(1.2,max(k.CenterOfMass(:,2))+0.2)]);
            xlabel(obj.Axes,'x');ylabel(obj.Axes,'y');title(obj.Axes,'Scientific SLIP biped stride');
            obj.updateFrame(1);
        end
        function updateFrame(obj,index)
            if index>=0&&index<=1&&index~=fix(index)
                index=1+round(index*(numel(obj.Simulation.Time)-1));
            end
            index=max(1,min(numel(obj.Simulation.Time),round(index)));obj.CurrentIndex=index;
            k=obj.Simulation.Kinematics;
            set(obj.Handles.Center,'XData',k.CenterOfMass(index,1),'YData',k.CenterOfMass(index,2));
            contacts={'left','right'};
            for leg=1:2
                set(obj.Handles.Legs(leg),'XData',[k.AttachmentX(index,leg),k.FootX(index,leg)], ...
                    'YData',[k.AttachmentY(index,leg),k.FootY(index,leg)]);
                if obj.Simulation.Modes.(contacts{leg})(index),face=[0.9 0.2 0.15];else,face='w';end
                set(obj.Handles.Feet(leg),'XData',k.FootX(index,leg),'YData',k.FootY(index,leg), ...
                    'MarkerFaceColor',face);
            end
            limits=xlim(obj.Axes);vertical=ylim(obj.Axes);
            set(obj.Handles.Phase,'Position',[limits(1)+0.02*diff(limits), ...
                vertical(2)-0.02*diff(vertical),0],'String',sprintf('t/T = %.3f', ...
                obj.Simulation.Time(index)/obj.Simulation.Time(end)));
            drawnow limitrate
        end
        function clear(obj)
            if ~isempty(obj.Axes)&&isgraphics(obj.Axes),cla(obj.Axes);end
            obj.Handles=struct();obj.Simulation=[];obj.CurrentIndex=1;
        end
    end
end
