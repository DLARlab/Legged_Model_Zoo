classdef BipedRenderer < lmz.viz.Renderer
    %BIPEDRENDERER Stable clean-generic biped renderer.
    properties (SetAccess=private)
        Style=struct()
        FixedXLimits=[-1 1]
        FixedYLimits=[-0.05 1.2]
    end

    methods
        function obj=BipedRenderer(axesHandle,simulation,profile,options)
            if nargin<1,axesHandle=[];end
            if nargin<2,simulation=[];end
            if nargin<3,profile=[];end
            if nargin<4,options=struct();end
            obj@lmz.viz.Renderer(axesHandle,[],profile,options);
            obj.Style=genericStyle(profile);
            if ~isempty(simulation),obj.initialize(simulation);end
        end
    end

    methods (Access=protected)
        function configureAxes(obj)
            configureAxes@lmz.viz.Renderer(obj);
            hold(obj.Axes,'on');obj.Style=genericStyle(obj.Profile);
        end

        function buildHandles(obj)
            k=obj.Simulation.Kinematics;
            if isempty(fieldnames(k))
                k=lmzmodels.slip_biped.KinematicsProvider.compute(obj.Simulation);
            end
            xmin=min(k.FootX(:));xmax=max(k.FootX(:));span=max(xmax-xmin,1);
            obj.FixedXLimits=[xmin-0.05*span,xmax+0.05*span];
            obj.FixedYLimits=[-0.05,max(1.2,max(k.CenterOfMass(:,2))+0.2)];
            style=obj.Style;
            obj.Handles.Ground=plot(obj.Axes,[xmin-0.1*span,xmax+0.1*span],[0 0], ...
                '-','Color',style.ground.color,'LineWidth',style.ground.lineWidth);
            obj.Handles.Center=plot(obj.Axes,nan,nan,style.center.marker, ...
                'Color',style.center.edgeColor, ...
                'MarkerFaceColor',style.center.faceColor, ...
                'MarkerSize',style.center.markerSize, ...
                'LineWidth',style.center.lineWidth);
            obj.Handles.Legs=gobjects(1,2);obj.Handles.Feet=gobjects(1,2);
            legStyles={style.leftLeg,style.rightLeg};
            for leg=1:2
                legStyle=legStyles{leg};
                obj.Handles.Legs(leg)=plot(obj.Axes,nan(1,2),nan(1,2),'-', ...
                    'Color',legStyle.color,'LineWidth',legStyle.lineWidth);
                obj.Handles.Feet(leg)=plot(obj.Axes,nan,nan,legStyle.marker, ...
                    'Color',legStyle.color,'MarkerSize',legStyle.markerSize, ...
                    'MarkerFaceColor',legStyle.footFaceColor, ...
                    'LineWidth',legStyle.footLineWidth);
            end
            obj.Handles.Phase=text(obj.Axes,0,0,'','VerticalAlignment','top', ...
                'FontWeight','bold','Color',style.phase.color, ...
                'FontSize',style.phase.fontSize,'Interpreter','none');
            axis(obj.Axes,'equal');
            if isempty(obj.Profile)||~isfield(obj.Profile.Camera,'xLimits')
                xlim(obj.Axes,obj.FixedXLimits);
            end
            if isempty(obj.Profile)||~isfield(obj.Profile.Camera,'yLimits')
                ylim(obj.Axes,obj.FixedYLimits);
            end
            if isempty(obj.Profile)
                grid(obj.Axes,'on');xlabel(obj.Axes,'x');ylabel(obj.Axes,'y');
                title(obj.Axes,'Scientific SLIP biped stride');
            end
            obj.applyOptions();
        end

        function updateHandles(obj,index)
            k=obj.Simulation.Kinematics;
            if isempty(fieldnames(k))
                k=lmzmodels.slip_biped.KinematicsProvider.compute(obj.Simulation);
            end
            set(obj.Handles.Center,'XData',k.CenterOfMass(index,1), ...
                'YData',k.CenterOfMass(index,2));
            contacts={'left','right'};legStyles={obj.Style.leftLeg,obj.Style.rightLeg};
            for leg=1:2
                set(obj.Handles.Legs(leg), ...
                    'XData',[k.AttachmentX(index,leg),k.FootX(index,leg)], ...
                    'YData',[k.AttachmentY(index,leg),k.FootY(index,leg)]);
                if obj.Simulation.Modes.(contacts{leg})(index)
                    face=legStyles{leg}.contactFaceColor;
                else
                    face=legStyles{leg}.footFaceColor;
                end
                set(obj.Handles.Feet(leg),'XData',k.FootX(index,leg), ...
                    'YData',k.FootY(index,leg),'MarkerFaceColor',face);
            end
            if obj.CameraFollow
                limits=xlim(obj.Axes);halfWidth=diff(limits)/2;
                if ~isfinite(halfWidth)||halfWidth<=0,halfWidth=1.5;end
                center=k.CenterOfMass(index,1);xlim(obj.Axes,center+[-halfWidth halfWidth]);
            end
            limits=xlim(obj.Axes);vertical=ylim(obj.Axes);
            set(obj.Handles.Phase,'Position',[limits(1)+0.02*diff(limits), ...
                vertical(2)-0.02*diff(vertical),0], ...
                'String',sprintf('t/T = %.3f', ...
                obj.Simulation.Time(index)/obj.Simulation.Time(end)));
        end

        function applyOptions(obj)
            if isempty(fieldnames(obj.Handles)),return,end
            if isfield(obj.Handles,'Ground')&&isgraphics(obj.Handles.Ground)
                if obj.GroundVisible,visible='on';else,visible='off';end
                set(obj.Handles.Ground,'Visible',visible);
            end
        end
    end
end

function value=genericStyle(profile)
value=struct();
value.ground=struct('color',[0 0 0],'lineWidth',1.5);
value.center=struct('marker','o','edgeColor',[0 0 0], ...
    'faceColor',[0.12 0.12 0.12],'markerSize',10,'lineWidth',1);
value.leftLeg=struct('color',[0.12 0.48 0.85],'lineWidth',3, ...
    'marker','o','markerSize',7,'footLineWidth',1, ...
    'footFaceColor',[1 1 1],'contactFaceColor',[0.9 0.2 0.15]);
value.rightLeg=struct('color',[0.9 0.35 0.18],'lineWidth',3, ...
    'marker','o','markerSize',7,'footLineWidth',1, ...
    'footFaceColor',[1 1 1],'contactFaceColor',[0.9 0.2 0.15]);
value.phase=struct('color',[0 0 0],'fontSize',10);
if nargin>=1&&~isempty(profile)&&isa(profile,'lmz.viz.VisualizationProfile')
    value=mergeRecursive(value,profile.Style);
end
end

function value=mergeRecursive(first,second)
value=first;if isempty(second),return,end
names=fieldnames(second);
for index=1:numel(names)
    name=names{index};incoming=second.(name);
    if isfield(value,name)&&isstruct(value.(name))&&isstruct(incoming)
        value.(name)=mergeRecursive(value.(name),incoming);
    else
        value.(name)=incoming;
    end
end
end
