classdef ResearchRenderer < lmz.viz.ResearchRenderer
    %RESEARCHRENDERER Source-faithful compound biped renderer.
    properties (SetAccess=private)
        Style=struct()
        EventSchedule=zeros(5,1)
        HasEventSchedule=false
    end

    methods
        function obj=ResearchRenderer(axesHandle,simulation,profile,options)
            if nargin<1,axesHandle=[];end
            if nargin<2,simulation=[];end
            if nargin<3,profile=[];end
            if nargin<4,options=struct();end
            obj@lmz.viz.ResearchRenderer(axesHandle,[],profile,options);
            obj.Style=lmzmodels.slip_biped.ResearchStyle.resolve(profile);
            if isempty(profile)&&~isfield(options,'CameraFollow')
                obj.CameraFollow=true;
            end
            if ~isempty(simulation),obj.initialize(simulation);end
        end

        function value=geometryAt(obj,index)
            if isempty(obj.Simulation)
                error('lmz:slip_biped:ResearchRendererSimulation', ...
                    'Renderer has no simulation.');
            end
            count=numel(obj.Simulation.Time);
            index=max(1,min(count,round(index)));
            xValues=obj.Simulation.state('x');yValues=obj.Simulation.state('y');
            leftValues=obj.Simulation.state('alphaL');
            rightValues=obj.Simulation.state('alphaR');
            state=struct('x',xValues(index),'y',yValues(index), ...
                'alphaL',leftValues(index),'alphaR',rightValues(index));
            if obj.HasEventSchedule
                legs=lmzmodels.slip_biped.ResearchLegGeometry.frame( ...
                    state,obj.EventSchedule,obj.Simulation.Time(index));
            else
                leftContact=modeAt(obj.Simulation.Modes,'left',index);
                rightContact=modeAt(obj.Simulation.Modes,'right',index);
                legs=lmzmodels.slip_biped.ResearchLegGeometry.frameFromContacts( ...
                    state,leftContact,rightContact);
                legs.EventTimes=[];legs.Time=obj.Simulation.Time(index);
            end
            value=struct('Body', ...
                lmzmodels.slip_biped.ResearchBodyGeometry.compute(state.x,state.y), ...
                'COG',lmzmodels.slip_biped.ResearchCOGGeometry.compute(state.x,state.y), ...
                'Legs',legs,'BodyCenter',[state.x state.y], ...
                'Time',obj.Simulation.Time(index),'Index',index);
        end
    end

    methods (Access=protected)
        function configureAxes(obj)
            configureAxes@lmz.viz.Renderer(obj);
            hold(obj.Axes,'on');grid(obj.Axes,'off');axis(obj.Axes,'equal');
            axis(obj.Axes,'off');box(obj.Axes,'on');
            obj.Style=lmzmodels.slip_biped.ResearchStyle.resolve(obj.Profile);
            obj.Axes.Color=obj.Style.axes.backgroundColor;
            yLimits=obj.Style.axes.yLimits;
            if ~isempty(obj.Profile)&&isfield(obj.Profile.Camera,'yLimits')
                yLimits=obj.Profile.Camera.yLimits;
            end
            ylim(obj.Axes,yLimits);
        end

        function buildHandles(obj)
            [obj.EventSchedule,obj.HasEventSchedule]= ...
                lmzmodels.slip_biped.ResearchLegGeometry.scheduleFromSimulation( ...
                obj.Simulation);
            frame=obj.geometryAt(1);ground= ...
                lmzmodels.slip_biped.ResearchGroundGeometry.compute();
            style=obj.Style;

            % Creation order is the source z-order, deepest to topmost.
            obj.Handles.Left=createLeg(obj.Axes,frame.Legs.Left,style.leftLeg,style.spring);
            obj.Handles.GroundMask=createPatch(obj.Axes,ground.Layers{1}, ...
                style.ground.maskFaceColor,style.ground.maskEdgeColor, ...
                style.ground.maskLineWidth);
            obj.Handles.GroundHatch=createPatch(obj.Axes,ground.Layers{2}, ...
                style.ground.hatchFaceColor,style.ground.hatchEdgeColor, ...
                style.ground.hatchLineWidth);
            obj.Handles.Body=createPatch(obj.Axes,frame.Body, ...
                style.body.faceColor,style.body.edgeColor,style.body.lineWidth);
            obj.Handles.Right=createLeg(obj.Axes,frame.Legs.Right,style.rightLeg,style.spring);
            obj.Handles.COG=patch(obj.Axes,'Faces',frame.COG.Faces, ...
                'Vertices',frame.COG.Vertices,'FaceVertexCData',style.cog.faceColors, ...
                'FaceColor','flat','EdgeColor',style.cog.edgeColor, ...
                'LineWidth',style.cog.lineWidth);
            obj.applyOptions();
        end

        function updateHandles(obj,index)
            frame=obj.geometryAt(index);
            set(obj.Handles.Body,'Vertices',frame.Body.Vertices);
            updateLeg(obj.Handles.Left,frame.Legs.Left);
            updateLeg(obj.Handles.Right,frame.Legs.Right);
            set(obj.Handles.COG,'Vertices',frame.COG.Vertices);
            if obj.CameraFollow
                halfWidth=obj.Style.axes.xFollowHalfWidth;
                if ~isempty(obj.Profile)&&isfield(obj.Profile.Camera,'followWindow')
                    window=obj.Profile.Camera.followWindow;
                    if isscalar(window)&&window>0,halfWidth=window/2;end
                end
                xlim(obj.Axes,frame.BodyCenter(1)+[-halfWidth halfWidth]);
            end
            yLimits=obj.Style.axes.yLimits;
            if ~isempty(obj.Profile)&&isfield(obj.Profile.Camera,'yLimits')
                yLimits=obj.Profile.Camera.yLimits;
            end
            ylim(obj.Axes,yLimits);box(obj.Axes,'on');
        end

        function applyOptions(obj)
            if isempty(fieldnames(obj.Handles)),return,end
            visibility=onOff(obj.GroundVisible);
            if isfield(obj.Handles,'GroundMask')&&isgraphics(obj.Handles.GroundMask)
                set(obj.Handles.GroundMask,'Visible',visibility);
            end
            if isfield(obj.Handles,'GroundHatch')&&isgraphics(obj.Handles.GroundHatch)
                set(obj.Handles.GroundHatch,'Visible',visibility);
            end
        end
    end
end

function handles=createLeg(ax,parts,legStyle,springStyle)
handles=struct();
handles.Spring1=createPatch(ax,parts.Spring1,springStyle.faceColor, ...
    springStyle.edgeColor,springStyle.lineWidth);
handles.Lower=createPatch(ax,parts.Lower,legStyle.faceColor, ...
    legStyle.edgeColor,legStyle.lineWidth);
handles.Spring2=createPatch(ax,parts.Spring2,springStyle.faceColor, ...
    springStyle.edgeColor,springStyle.lineWidth);
handles.Upper=createPatch(ax,parts.Upper,legStyle.faceColor, ...
    legStyle.edgeColor,legStyle.lineWidth);
end

function handle=createPatch(ax,geometry,faceColor,edgeColor,lineWidth)
handle=patch(ax,'Faces',geometry.Faces,'Vertices',geometry.Vertices, ...
    'FaceColor',faceColor,'EdgeColor',edgeColor,'LineWidth',lineWidth);
end

function updateLeg(handles,parts)
set(handles.Spring1,'Vertices',parts.Spring1.Vertices);
set(handles.Lower,'Vertices',parts.Lower.Vertices);
set(handles.Spring2,'Vertices',parts.Spring2.Vertices);
set(handles.Upper,'Vertices',parts.Upper.Vertices);
end

function value=modeAt(modes,name,index)
if isstruct(modes)&&isfield(modes,name)&&numel(modes.(name))>=index
    value=logical(modes.(name)(index));
else
    value=false;
end
value=logical(value(1));
end

function value=onOff(flag)
if flag,value='on';else,value='off';end
end
