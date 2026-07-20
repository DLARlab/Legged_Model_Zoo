classdef QuadLoadRenderer < lmz.viz.Renderer
    %QUADLOADRENDERER Stable clean-generic quadruped/load renderer.
    properties
        ForceScale=0.02
    end
    properties (Access=private)
        Kinematics=struct()
        Style=struct()
    end

    methods
        function obj=QuadLoadRenderer(axesHandle,simulation,profile,options)
            if nargin<1,axesHandle=[];end
            if nargin<2,simulation=[];end
            if nargin<3,profile=[];end
            if nargin<4,options=struct();end
            obj@lmz.viz.Renderer(axesHandle,[],profile,options);
            if ~isfield(options,'DetailedOverlay')&&hasOverlay(profile,'phase_labels')
                obj.DetailedOverlay=true;
            end
            if ~isfield(options,'ShowForces')&&~isempty(profile)
                obj.ShowForces=hasOverlay(profile,'force_vectors');
            end
            if ~isempty(simulation),obj.initialize(simulation);end
        end
    end

    methods (Access=protected)
        function buildHandles(obj)
            obj.Style=genericStyle(obj.Profile);obj.ForceScale=obj.Style.forces.scale;
            k=obj.Simulation.Kinematics;
            if isempty(fieldnames(k))
                k=lmzmodels.slip_quad_load.KinematicsProvider.compute(obj.Simulation);
            end
            obj.Kinematics=k;
            allX=[k.FootX(:);k.LoadPosition(:,1);k.CenterOfMass(:,1)];
            xmin=min(allX);xmax=max(allX);span=max(1,xmax-xmin);
            xlim(obj.Axes,[xmin-obj.Style.camera.marginFraction*span, ...
                xmax+obj.Style.camera.marginFraction*span]);
            ylim(obj.Axes,[-0.05,max(1,max(k.CenterOfMass(:,2))+ ...
                obj.Style.camera.verticalPadding)]);

            obj.Handles.Ground=plot(obj.Axes,[xmin-.1*span xmax+.1*span], ...
                [0 0],'-','Color',obj.Style.ground.color, ...
                'LineWidth',obj.Style.ground.lineWidth);
            obj.Handles.Body=plot(obj.Axes,nan(1,2),nan(1,2),'-', ...
                'Color',obj.Style.body.color,'LineWidth',obj.Style.body.lineWidth);
            obj.Handles.Center=plot(obj.Axes,nan,nan,'o', ...
                'Color',obj.Style.center.color, ...
                'MarkerFaceColor',obj.Style.center.color, ...
                'MarkerSize',obj.Style.center.markerSize);
            obj.Handles.Load=plot(obj.Axes,nan,nan,'s', ...
                'MarkerSize',obj.Style.load.markerSize, ...
                'MarkerFaceColor',obj.Style.load.faceColor, ...
                'Color',obj.Style.load.edgeColor);
            obj.Handles.Rope=plot(obj.Axes,nan(1,2),nan(1,2),'-', ...
                'Color',obj.Style.rope.color,'LineWidth',obj.Style.rope.lineWidth);
            obj.Handles.Legs=gobjects(1,4);obj.Handles.Feet=gobjects(1,4);
            obj.Handles.Forces=gobjects(1,4);
            for leg=1:4
                color=obj.Style.legs.colors(leg,:);
                obj.Handles.Legs(leg)=plot(obj.Axes,nan(1,2),nan(1,2),'-', ...
                    'Color',color,'LineWidth',obj.Style.legs.lineWidth);
                obj.Handles.Feet(leg)=plot(obj.Axes,nan,nan,'o','Color',color, ...
                    'MarkerSize',obj.Style.legs.markerSize,'MarkerFaceColor','w');
                obj.Handles.Forces(leg)=quiver(obj.Axes,nan,nan,nan,nan,0, ...
                    'Color',obj.Style.forces.color, ...
                    'LineWidth',obj.Style.forces.lineWidth);
            end
            limits=xlim(obj.Axes);vertical=ylim(obj.Axes);
            obj.Handles.Phase=text(obj.Axes,limits(1),vertical(2),'', ...
                'VerticalAlignment','top','FontWeight','bold');
            obj.applyOptions();
        end

        function updateHandles(obj,index)
            k=obj.Kinematics;
            set(obj.Handles.Body,'XData',[k.BackAttachment(index,1) ...
                k.FrontAttachment(index,1)],'YData',[k.BackAttachment(index,2) ...
                k.FrontAttachment(index,2)]);
            set(obj.Handles.Center,'XData',k.CenterOfMass(index,1), ...
                'YData',k.CenterOfMass(index,2));
            set(obj.Handles.Load,'XData',k.LoadPosition(index,1), ...
                'YData',k.LoadPosition(index,2));
            set(obj.Handles.Rope,'XData',[k.RopeStart(index,1) k.RopeEnd(index,1)], ...
                'YData',[k.RopeStart(index,2) k.RopeEnd(index,2)]);
            contacts={'back_left','front_left','back_right','front_right'};
            for leg=1:4
                set(obj.Handles.Legs(leg),'XData',[k.AttachmentX(index,leg) ...
                    k.FootX(index,leg)],'YData',[k.AttachmentY(index,leg) ...
                    k.FootY(index,leg)]);
                inContact=obj.Simulation.Modes.(contacts{leg})(index);
                if inContact,face=[.9 .2 .15];else,face='w';end
                set(obj.Handles.Feet(leg),'XData',k.FootX(index,leg), ...
                    'YData',k.FootY(index,leg),'MarkerFaceColor',face);
                if obj.ShowForces&&~isempty(obj.Simulation.GroundReactionForces)
                    set(obj.Handles.Forces(leg),'XData',k.FootX(index,leg), ...
                        'YData',k.FootY(index,leg), ...
                        'UData',obj.ForceScale* ...
                            obj.Simulation.GroundReactionForces(index,4+leg), ...
                        'VData',obj.ForceScale* ...
                            obj.Simulation.GroundReactionForces(index,8+leg), ...
                        'Visible','on');
                else
                    set(obj.Handles.Forces(leg),'Visible','off');
                end
            end
            if obj.CameraFollow
                limits=xlim(obj.Axes);halfWidth=diff(limits)/2;
                xlim(obj.Axes,k.CenterOfMass(index,1)+[-halfWidth halfWidth]);
            end
            limits=xlim(obj.Axes);vertical=ylim(obj.Axes);
            phase=obj.Simulation.Observables.normalized_stride_time(index);
            set(obj.Handles.Phase,'Position',[limits(1)+.02*diff(limits), ...
                vertical(2)-.02*diff(vertical),0], ...
                'String',sprintf('stride time = %.3f',phase));
            obj.applyOptions();
        end

        function applyOptions(obj)
            if isempty(fieldnames(obj.Handles)),return,end
            setVisible(obj.Handles,'Ground',obj.GroundVisible);
            setVisible(obj.Handles,'Forces',obj.ShowForces);
            setVisible(obj.Handles,'Phase',obj.DetailedOverlay);
        end
    end
end

function value=genericStyle(profile)
value=struct();
value.ground=struct('color',[0 0 0],'lineWidth',1.5);
value.body=struct('color',[0 0 0],'lineWidth',7);
value.center=struct('color',[.15 .15 .15],'markerSize',7);
value.load=struct('faceColor',[.5 .5 .55],'edgeColor',[.2 .2 .2], ...
    'markerSize',14);
value.rope=struct('color',[.45 .25 .1],'lineWidth',2);
value.legs=struct('colors',[.2 .45 .85;.85 .35 .2;.2 .65 .35;.65 .3 .8], ...
    'lineWidth',2.5,'markerSize',7);
value.forces=struct('color',[.75 .1 .1],'lineWidth',1.2,'scale',.02);
value.camera=struct('marginFraction',.05,'verticalPadding',.35);
if ~isempty(profile)&&isa(profile,'lmz.viz.VisualizationProfile')
    value=mergeRecursive(value,profile.Style);
end
end

function value=mergeRecursive(first,second)
value=first;names=fieldnames(second);
for index=1:numel(names)
    name=names{index};incoming=second.(name);
    if isfield(value,name)&&isstruct(value.(name))&&isstruct(incoming)
        value.(name)=mergeRecursive(value.(name),incoming);
    else
        value.(name)=incoming;
    end
end
end

function result=hasOverlay(profile,name)
result=~isempty(profile)&&isa(profile,'lmz.viz.VisualizationProfile')&& ...
    any(strcmp(name,profile.Overlays));
end

function setVisible(handles,name,visible)
if ~isfield(handles,name),return,end
if visible,state='on';else,state='off';end
value=handles.(name);
for index=1:numel(value)
    if isgraphics(value(index)),set(value(index),'Visible',state);end
end
end
