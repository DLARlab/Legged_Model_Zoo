classdef QuadrupedRenderer < handle
    %QUADRUPEDRENDERER Frame renderer using named scientific kinematics.
    properties (SetAccess=private)
        Axes
        Simulation
        Handles = struct()
        CurrentIndex = 1
    end
    properties
        ShowForces = true
        ForceScale = 0.025
    end
    methods
        function obj=QuadrupedRenderer(axesHandle,simulation)
            if nargin>=1,obj.Axes=axesHandle;end
            if nargin>=2,obj.initialize(simulation);end
        end
        function initialize(obj,simulation)
            obj.Simulation=simulation;
            if isempty(obj.Axes)||~isgraphics(obj.Axes),error('lmz:Renderer:Axes','A valid axes is required.');end
            cla(obj.Axes);hold(obj.Axes,'on');grid(obj.Axes,'on');
            k=simulation.Kinematics;
            if isempty(fieldnames(k)),k=lmzmodels.slip_quadruped.KinematicsProvider.compute(simulation);end
            xmin=min(k.FootX(:));xmax=max(k.FootX(:));span=max(xmax-xmin,1);
            obj.Handles.Ground=plot(obj.Axes,[xmin-0.1*span xmax+0.1*span],[0 0],'k-','LineWidth',1.5);
            obj.Handles.Body=plot(obj.Axes,nan(1,2),nan(1,2),'k-','LineWidth',7);
            obj.Handles.Center=plot(obj.Axes,nan,nan,'ko','MarkerFaceColor',[0.15 0.15 0.15],'MarkerSize',7);
            colors=[0.2 0.45 0.85;0.85 0.35 0.2;0.2 0.65 0.35;0.65 0.3 0.8];
            obj.Handles.Legs=gobjects(1,4);obj.Handles.Feet=gobjects(1,4);obj.Handles.Forces=gobjects(1,4);
            for leg=1:4
                obj.Handles.Legs(leg)=plot(obj.Axes,nan(1,2),nan(1,2),'-','Color',colors(leg,:),'LineWidth',2.5);
                obj.Handles.Feet(leg)=plot(obj.Axes,nan,nan,'o','Color',colors(leg,:),'MarkerSize',7,'MarkerFaceColor','w');
                obj.Handles.Forces(leg)=quiver(obj.Axes,nan,nan,nan,nan,0,'Color',[0.75 0.1 0.1],'LineWidth',1.2);
            end
            obj.Handles.Phase=text(obj.Axes,0,0,'','VerticalAlignment','top','FontWeight','bold');
            axis(obj.Axes,'equal');xlim(obj.Axes,[xmin-0.05*span,xmax+0.05*span]);
            ymax=max(k.CenterOfMass(:,2))+0.35;ylim(obj.Axes,[-0.05,max(1,ymax)]);
            xlabel(obj.Axes,'x');ylabel(obj.Axes,'y');title(obj.Axes,'Scientific SLIP quadruped stride');
            obj.updateFrame(1);
        end
        function updateFrame(obj,index)
            if index>=0&&index<=1&&index~=fix(index)
                index=1+round(index*(numel(obj.Simulation.Time)-1));
            end
            index=max(1,min(numel(obj.Simulation.Time),round(index)));obj.CurrentIndex=index;
            k=obj.Simulation.Kinematics;
            if isempty(fieldnames(k)),k=lmzmodels.slip_quadruped.KinematicsProvider.compute(obj.Simulation);end
            set(obj.Handles.Body,'XData',[k.BackAttachment(index,1),k.FrontAttachment(index,1)], ...
                'YData',[k.BackAttachment(index,2),k.FrontAttachment(index,2)]);
            set(obj.Handles.Center,'XData',k.CenterOfMass(index,1),'YData',k.CenterOfMass(index,2));
            contacts={'back_left','front_left','back_right','front_right'};
            for leg=1:4
                set(obj.Handles.Legs(leg),'XData',[k.AttachmentX(index,leg),k.FootX(index,leg)], ...
                    'YData',[k.AttachmentY(index,leg),k.FootY(index,leg)]);
                inContact=obj.Simulation.Modes.(contacts{leg})(index);
                if inContact,face=[0.9 0.2 0.15];else,face='w';end
                set(obj.Handles.Feet(leg),'XData',k.FootX(index,leg),'YData',k.FootY(index,leg),'MarkerFaceColor',face);
                if obj.ShowForces&&~isempty(obj.Simulation.GroundReactionForces)
                    fx=obj.Simulation.GroundReactionForces(index,4+leg);
                    fy=obj.Simulation.GroundReactionForces(index,8+leg);
                    set(obj.Handles.Forces(leg),'XData',k.FootX(index,leg),'YData',k.FootY(index,leg), ...
                        'UData',obj.ForceScale*fx,'VData',obj.ForceScale*fy,'Visible','on');
                else,set(obj.Handles.Forces(leg),'Visible','off');end
            end
            limits=xlim(obj.Axes);vertical=ylim(obj.Axes);
            set(obj.Handles.Phase,'Position',[limits(1)+0.02*diff(limits),vertical(2)-0.02*diff(vertical),0], ...
                'String',sprintf('t/T = %.3f',obj.Simulation.Time(index)/obj.Simulation.Time(end)));
            drawnow limitrate
        end
        function clear(obj)
            if ~isempty(obj.Axes)&&isgraphics(obj.Axes),cla(obj.Axes);end
            obj.Handles=struct();obj.Simulation=[];obj.CurrentIndex=1;
        end
    end
end
