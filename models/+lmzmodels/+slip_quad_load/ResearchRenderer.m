classdef ResearchRenderer < lmz.viz.ResearchRenderer
    %RESEARCHRENDERER Source-derived compound quadruped/load visualization.
    properties (SetAccess=private)
        ActiveStrideIndex=1
        ActiveParameters=[]
        FrameGeometry=struct()
    end
    properties (Access=private)
        Kinematics=struct()
        QuadrupedStyle=struct()
        LoadStyle=struct()
    end

    methods
        function obj=ResearchRenderer(axesHandle,simulation,profile,options)
            if nargin<1,axesHandle=[];end
            if nargin<2,simulation=[];end
            if nargin<3,profile=[];end
            if nargin<4,options=struct();end
            obj@lmz.viz.ResearchRenderer(axesHandle,[],profile,options);
            if ~isfield(options,'CameraFollow')
                obj.CameraFollow=profileField(profile,'Camera','follow',true);
            end
            if ~isfield(options,'ShowForces'),obj.ShowForces=false;end
            if ~isempty(simulation),obj.initialize(simulation);end
        end
    end

    methods (Access=protected)
        function configureAxes(obj)
            obj.QuadrupedStyle=lmzmodels.slip_quadruped.ResearchStyle.resolve(obj.Profile);
            obj.LoadStyle=lmzmodels.slip_quad_load.ResearchStyle.resolve(obj.Profile);
            axisSpec=profileGroup(obj.Profile,'Axis');
            camera=profileGroup(obj.Profile,'Camera');
            hold(obj.Axes,'on');box(obj.Axes,'off');axis(obj.Axes,'normal');
            if fieldOr(axisSpec,'grid',false)
                grid(obj.Axes,'on');
            else
                grid(obj.Axes,'off');
            end
            if fieldOr(axisSpec,'equal',false)
                axis(obj.Axes,'equal');
            else
                pbaspect(obj.Axes,obj.LoadStyle.axes.plotBoxAspect);
            end
            if fieldOr(axisSpec,'visible',false)
                axis(obj.Axes,'on');
            else
                axis(obj.Axes,'off');
            end
            xlabel(obj.Axes,fieldOr(axisSpec,'xLabel',''),'Interpreter','none');
            ylabel(obj.Axes,fieldOr(axisSpec,'yLabel',''),'Interpreter','none');
            title(obj.Axes,fieldOr(axisSpec,'title',obj.LoadStyle.axes.title), ...
                'Interpreter','none');
            obj.Axes.Color=fieldOr(axisSpec,'backgroundColor', ...
                obj.LoadStyle.axes.backgroundColor);
            if isfield(camera,'xLimits'),xlim(obj.Axes,camera.xLimits);end
            ylim(obj.Axes,fieldOr(camera,'yLimits',obj.LoadStyle.axes.yLimits));
            if isfield(camera,'dataAspectRatio')
                daspect(obj.Axes,camera.dataAspectRatio);
            end
            if ~isfield(obj.Options,'CameraFollow')
                obj.CameraFollow=fieldOr(camera,'follow',true);
            end
            if isprop(obj.Axes,'SortMethod'),obj.Axes.SortMethod='childorder';end
        end

        function buildHandles(obj)
            k=obj.Simulation.Kinematics;
            if isempty(fieldnames(k))
                k=lmzmodels.slip_quad_load.KinematicsProvider.compute(obj.Simulation);
            end
            obj.Kinematics=k;frame=obj.computeFrameGeometry(1);
            obj.FrameGeometry=frame;obj.ActiveStrideIndex=frame.Active.StrideIndex;
            obj.ActiveParameters=frame.Active.GlobalRow;

            % Preserve source child order: left legs, ground, body/COM,
            % right legs, load, then rope.
            obj.Handles.Leg_BL=createLeg(obj.Axes,frame.Legs{1},obj.QuadrupedStyle.leg);
            obj.Handles.Leg_FL=createLeg(obj.Axes,frame.Legs{2},obj.QuadrupedStyle.leg);
            ground=lmzmodels.slip_quadruped.ResearchGroundGeometry.compute();
            obj.Handles.Ground=createGround(obj.Axes,ground,obj.QuadrupedStyle.ground);
            obj.Handles.Body=createBody(obj.Axes,frame.Body,obj.QuadrupedStyle.body);
            obj.Handles.COM=createCOM(obj.Axes,frame.COM,obj.QuadrupedStyle.com);
            obj.Handles.Leg_BR=createLeg(obj.Axes,frame.Legs{3},obj.QuadrupedStyle.leg);
            obj.Handles.Leg_FR=createLeg(obj.Axes,frame.Legs{4},obj.QuadrupedStyle.leg);
            obj.Handles.Load=createPatch(obj.Axes,frame.Load, ...
                'FaceColor',obj.LoadStyle.load.faceColor, ...
                'FaceAlpha',obj.LoadStyle.load.faceAlpha, ...
                'EdgeColor',obj.LoadStyle.load.edgeColor, ...
                'LineWidth',obj.LoadStyle.load.lineWidth);
            obj.Handles.Rope=createPatch(obj.Axes,frame.Rope, ...
                'FaceColor',obj.LoadStyle.rope.faceColor, ...
                'FaceAlpha',obj.LoadStyle.rope.faceAlpha, ...
                'EdgeColor',obj.LoadStyle.rope.edgeColor, ...
                'LineWidth',obj.LoadStyle.rope.lineWidth);
            obj.Handles.Title=obj.Axes.Title;
            obj.applyOptions();
        end

        function updateHandles(obj,index)
            frame=obj.computeFrameGeometry(index);obj.FrameGeometry=frame;
            obj.ActiveStrideIndex=frame.Active.StrideIndex;
            obj.ActiveParameters=frame.Active.GlobalRow;
            updateLeg(obj.Handles.Leg_BL,frame.Legs{1});
            updateLeg(obj.Handles.Leg_FL,frame.Legs{2});
            updateBody(obj.Handles.Body,frame.Body);
            updateCOM(obj.Handles.COM,frame.COM);
            updateLeg(obj.Handles.Leg_BR,frame.Legs{3});
            updateLeg(obj.Handles.Leg_FR,frame.Legs{4});
            updatePatch(obj.Handles.Load,frame.Load);
            updatePatch(obj.Handles.Rope,frame.Rope);
            if frame.BackFraction==0.5,visible='off';else,visible='on';end
            setStructVisible(obj.Handles.COM,visible);
            if obj.CameraFollow
                window=profileField(obj.Profile,'Camera','followWindow', ...
                    obj.LoadStyle.axes.xOffsets);
                if isnumeric(window)&&numel(window)==2&&all(isfinite(window))
                    xlim(obj.Axes,frame.BodyFrame(1)+reshape(window,1,2));
                else
                    error('lmz:slip_quad_load:ResearchCameraWindow', ...
                        'Camera followWindow must contain two finite offsets.');
                end
            end
            ylim(obj.Axes,profileField(obj.Profile,'Camera','yLimits', ...
                obj.LoadStyle.axes.yLimits));
            if ~profileField(obj.Profile,'Axis','equal',false)
                pbaspect(obj.Axes,obj.LoadStyle.axes.plotBoxAspect);
            end
            obj.applyOptions();
        end

        function applyOptions(obj)
            if isempty(fieldnames(obj.Handles)),return,end
            if obj.GroundVisible,state='on';else,state='off';end
            if isfield(obj.Handles,'Ground'),setStructVisible(obj.Handles.Ground,state);end
        end

        function frame=computeFrameGeometry(obj,index)
            active=lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
                forFrame(obj.Simulation,index);
            row=active.GlobalRow;restLength=row(13);backFraction=row(15);
            x=namedState(obj.Simulation,'quad_x',index);
            y=namedState(obj.Simulation,'quad_y',index);
            pitch=namedState(obj.Simulation,'quad_phi',index);
            bodyFrame=[x y pitch];
            back=[x-backFraction*cos(pitch),y-backFraction*sin(pitch)];
            front=[x+(1-backFraction)*cos(pitch), ...
                y+(1-backFraction)*sin(pitch)];
            attachments=[back;front;back;front];
            alphaNames={'alphaBL','alphaFL','alphaBR','alphaFR'};
            modeNames={'back_left','front_left','back_right','front_right'};
            legs=cell(1,4);angles=zeros(1,4);lengths=restLength*ones(1,4);
            for leg=1:4
                angles(leg)=pitch+namedState(obj.Simulation,alphaNames{leg},index);
                contact=logical(obj.Simulation.Modes.(modeNames{leg})(index));
                if contact
                    denominator=cos(angles(leg));
                    if denominator==0
                        error('lmz:slip_quad_load:SingularResearchLeg', ...
                            'Source stance-length geometry is singular.');
                    end
                    lengths(leg)=attachments(leg,2)/denominator;
                end
                legs{leg}=lmzmodels.slip_quadruped.ResearchLegGeometry.compute( ...
                    attachments(leg,:),lengths(leg),restLength,angles(leg));
            end
            body=lmzmodels.slip_quadruped.ResearchBodyGeometry.compute( ...
                bodyFrame,backFraction);
            com=lmzmodels.slip_quadruped.ResearchCOMGeometry.compute( ...
                bodyFrame,obj.QuadrupedStyle.com.radius);
            loadCenter=[namedState(obj.Simulation,'load_x',index), ...
                namedState(obj.Simulation,'load_y',index)];
            loadGeometry=lmzmodels.slip_quad_load.ResearchLoadGeometry.compute(loadCenter);
            rope=lmzmodels.slip_quad_load.ResearchRopeGeometry.compute( ...
                bodyFrame(1:2),loadCenter);
            frame=struct('Active',active,'BodyFrame',bodyFrame, ...
                'BackFraction',backFraction,'RestLength',restLength, ...
                'Attachments',attachments,'Angles',angles,'Lengths',lengths, ...
                'Legs',{legs},'Body',body,'COM',com,'Load',loadGeometry, ...
                'Rope',rope,'LoadCenter',loadCenter,'Index',index, ...
                'Time',obj.Simulation.Time(index));
        end
    end
end

function value=namedState(simulation,name,index)
values=simulation.state(name);value=values(index);
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)
    error('lmz:slip_quad_load:ResearchState', ...
        'Named state %s is unavailable or invalid.',name);
end
end

function value=profileGroup(profile,name)
value=struct();
if ~isempty(profile)&&isa(profile,'lmz.viz.VisualizationProfile')
    value=profile.(name);
end
end

function value=profileField(profile,group,name,fallback)
spec=profileGroup(profile,group);
if isfield(spec,name),value=spec.(name);else,value=fallback;end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end

function handles=createBody(ax,geometry,style)
handles=struct();
handles.Background=createPatch(ax,geometry.Background, ...
    'FaceColor',style.backgroundColor,'LineStyle','none');
handles.Shading=createPatch(ax,geometry.Shading, ...
    'FaceColor',style.backgroundColor,'EdgeColor',style.shadeColor, ...
    'LineWidth',style.shadeWidth);
handles.Outline=patch('Parent',ax,'XData',geometry.Outline.Points(:,1), ...
    'YData',geometry.Outline.Points(:,2),'FaceColor','none', ...
    'EdgeColor',style.edgeColor,'LineWidth',style.outlineWidth);
end

function handles=createLeg(ax,geometry,style)
handles=struct();
handles.Spring1=createPatch(ax,geometry.Spring1,'FaceColor',style.springColor, ...
    'EdgeColor',style.springColor,'LineWidth',style.springWidth);
handles.UpperBackground=createPatch(ax,geometry.UpperBackground, ...
    'FaceColor',style.upperBackgroundColor,'LineStyle','none');
handles.UpperShading=createPatch(ax,geometry.UpperShading, ...
    'FaceColor','none','EdgeColor',style.shadeColor,'LineWidth',style.shadeWidth);
handles.UpperOutline=createPatch(ax,geometry.UpperOutline, ...
    'FaceColor','none','EdgeColor',style.outlineColor, ...
    'LineWidth',style.outlineWidth);
handles.Lower=createPatch(ax,geometry.Lower,'FaceColor',style.lowerColor, ...
    'EdgeColor',style.lowerEdgeColor,'LineWidth',style.lowerWidth);
handles.Spring2=createPatch(ax,geometry.Spring2,'FaceColor',style.springColor, ...
    'EdgeColor',style.springColor,'LineWidth',style.springWidth);
end

function handles=createCOM(ax,geometry,style)
handles=struct();
handles.Outer=createPatch(ax,geometry.Outer,'FaceColor',style.outerColor, ...
    'EdgeColor',style.edgeColor,'LineWidth',style.outerWidth);
handles.Inner=patch('Parent',ax,'Faces',geometry.Inner.Faces, ...
    'Vertices',geometry.Inner.Vertices,'FaceVertexCData',geometry.InnerFaceColors, ...
    'FaceColor','flat','EdgeColor',style.edgeColor,'LineWidth',style.innerWidth);
end

function handles=createGround(ax,geometry,style)
handles=struct();
handles.Field=createPatch(ax,geometry.Field,'FaceColor',style.fieldColor, ...
    'EdgeColor',style.edgeColor,'LineWidth',style.lineWidth);
handles.Hatch=createPatch(ax,geometry.Hatch,'FaceColor',style.hatchColor, ...
    'EdgeColor',style.hatchColor,'LineWidth',style.lineWidth);
end

function handle=createPatch(ax,geometry,varargin)
handle=patch('Parent',ax,'Faces',geometry.Faces, ...
    'Vertices',geometry.Vertices,varargin{:});
end

function updateBody(handles,geometry)
updatePatch(handles.Background,geometry.Background);
updatePatch(handles.Shading,geometry.Shading);
set(handles.Outline,'XData',geometry.Outline.Points(:,1), ...
    'YData',geometry.Outline.Points(:,2));
end

function updateLeg(handles,geometry)
names={'Spring1','UpperBackground','UpperShading','UpperOutline','Lower','Spring2'};
for index=1:numel(names),updatePatch(handles.(names{index}),geometry.(names{index}));end
end

function updateCOM(handles,geometry)
updatePatch(handles.Outer,geometry.Outer);updatePatch(handles.Inner,geometry.Inner);
set(handles.Inner,'FaceVertexCData',geometry.InnerFaceColors);
end

function updatePatch(handle,geometry)
set(handle,'Faces',geometry.Faces,'Vertices',geometry.Vertices);
end

function setStructVisible(value,state)
names=fieldnames(value);
for index=1:numel(names)
    item=value.(names{index});
    if isgraphics(item),set(item,'Visible',state);end
end
end
