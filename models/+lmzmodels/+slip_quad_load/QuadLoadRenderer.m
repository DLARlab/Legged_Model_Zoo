classdef QuadLoadRenderer < handle
    %QUADLOADRENDERER Physical quadruped, load, rope, contacts, and forces.
    properties (SetAccess=private)
        Axes
        Simulation
        Handles=struct()
        CurrentIndex=1
    end
    properties
        ShowForces=true
        ForceScale=0.02
    end
    methods
        function obj=QuadLoadRenderer(axesHandle,simulation)
            if nargin>=1,obj.Axes=axesHandle;end
            if nargin>=2,obj.initialize(simulation);end
        end
        function initialize(obj,simulation)
            if isempty(obj.Axes)||~isgraphics(obj.Axes),error('lmz:QuadLoad:RendererAxes','A valid axes is required.');end
            obj.Simulation=simulation;cla(obj.Axes);hold(obj.Axes,'on');grid(obj.Axes,'on');
            k=simulation.Kinematics;if isempty(fieldnames(k)),k=lmzmodels.slip_quad_load.KinematicsProvider.compute(simulation);end
            allX=[k.FootX(:);k.LoadPosition(:,1);k.CenterOfMass(:,1)];xmin=min(allX);xmax=max(allX);span=max(1,xmax-xmin);
            obj.Handles.Ground=plot(obj.Axes,[xmin-.1*span xmax+.1*span],[0 0],'k-','LineWidth',1.5);
            obj.Handles.Body=plot(obj.Axes,nan(1,2),nan(1,2),'k-','LineWidth',7);
            obj.Handles.Center=plot(obj.Axes,nan,nan,'ko','MarkerFaceColor',[.15 .15 .15],'MarkerSize',7);
            obj.Handles.Load=plot(obj.Axes,nan,nan,'s','MarkerSize',14,'MarkerFaceColor',[.5 .5 .55],'Color',[.2 .2 .2]);
            obj.Handles.Rope=plot(obj.Axes,nan(1,2),nan(1,2),'-','Color',[.45 .25 .1],'LineWidth',2);
            colors=[.2 .45 .85;.85 .35 .2;.2 .65 .35;.65 .3 .8];
            obj.Handles.Legs=gobjects(1,4);obj.Handles.Feet=gobjects(1,4);obj.Handles.Forces=gobjects(1,4);
            for leg=1:4
                obj.Handles.Legs(leg)=plot(obj.Axes,nan(1,2),nan(1,2),'-','Color',colors(leg,:),'LineWidth',2.5);
                obj.Handles.Feet(leg)=plot(obj.Axes,nan,nan,'o','Color',colors(leg,:),'MarkerSize',7,'MarkerFaceColor','w');
                obj.Handles.Forces(leg)=quiver(obj.Axes,nan,nan,nan,nan,0,'Color',[.75 .1 .1],'LineWidth',1.2);
            end
            obj.Handles.Phase=text(obj.Axes,0,0,'','VerticalAlignment','top','FontWeight','bold');
            axis(obj.Axes,'equal');xlim(obj.Axes,[xmin-.05*span xmax+.05*span]);
            ylim(obj.Axes,[-.05,max(1,max(k.CenterOfMass(:,2))+.35)]);xlabel(obj.Axes,'x');ylabel(obj.Axes,'y');
            title(obj.Axes,'Scientific SLIP quadruped with load');obj.updateFrame(1);
        end
        function updateFrame(obj,index)
            if index>=0&&index<=1&&index~=fix(index),index=1+round(index*(numel(obj.Simulation.Time)-1));end
            index=max(1,min(numel(obj.Simulation.Time),round(index)));obj.CurrentIndex=index;k=obj.Simulation.Kinematics;
            set(obj.Handles.Body,'XData',[k.BackAttachment(index,1) k.FrontAttachment(index,1)], ...
                'YData',[k.BackAttachment(index,2) k.FrontAttachment(index,2)]);
            set(obj.Handles.Center,'XData',k.CenterOfMass(index,1),'YData',k.CenterOfMass(index,2));
            set(obj.Handles.Load,'XData',k.LoadPosition(index,1),'YData',k.LoadPosition(index,2));
            set(obj.Handles.Rope,'XData',[k.RopeStart(index,1) k.RopeEnd(index,1)], ...
                'YData',[k.RopeStart(index,2) k.RopeEnd(index,2)]);
            contacts={'back_left','front_left','back_right','front_right'};
            for leg=1:4
                set(obj.Handles.Legs(leg),'XData',[k.AttachmentX(index,leg) k.FootX(index,leg)], ...
                    'YData',[k.AttachmentY(index,leg) k.FootY(index,leg)]);
                inContact=obj.Simulation.Modes.(contacts{leg})(index);if inContact,face=[.9 .2 .15];else,face='w';end
                set(obj.Handles.Feet(leg),'XData',k.FootX(index,leg),'YData',k.FootY(index,leg),'MarkerFaceColor',face);
                if obj.ShowForces&&~isempty(obj.Simulation.GroundReactionForces)
                    set(obj.Handles.Forces(leg),'XData',k.FootX(index,leg),'YData',k.FootY(index,leg), ...
                        'UData',obj.ForceScale*obj.Simulation.GroundReactionForces(index,4+leg), ...
                        'VData',obj.ForceScale*obj.Simulation.GroundReactionForces(index,8+leg),'Visible','on');
                else,set(obj.Handles.Forces(leg),'Visible','off');end
            end
            limits=xlim(obj.Axes);vertical=ylim(obj.Axes);phase=obj.Simulation.Observables.normalized_stride_time(index);
            set(obj.Handles.Phase,'Position',[limits(1)+.02*diff(limits),vertical(2)-.02*diff(vertical),0], ...
                'String',sprintf('stride time = %.3f',phase));drawnow limitrate
        end
        function clear(obj)
            if ~isempty(obj.Axes)&&isgraphics(obj.Axes),cla(obj.Axes);end
            obj.Handles=struct();obj.Simulation=[];obj.CurrentIndex=1;
        end
    end
end
