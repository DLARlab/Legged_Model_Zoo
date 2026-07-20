classdef (Abstract) Renderer < handle
    %RENDERER Stable lifecycle contract for model visualization backends.
    properties (SetAccess=protected)
        Axes
        Simulation
        Profile
        Options=struct()
        Handles=struct()
        CurrentIndex=1
        IsInitialized=false
    end
    properties
        ShowForces=true
        DetailedOverlay=false
        GroundVisible=true
        CameraFollow=false
    end

    methods
        function obj=Renderer(axesHandle,simulation,profile,options)
            if nargin<1,axesHandle=[];end
            if nargin<2,simulation=[];end
            if nargin<3,profile=[];end
            if nargin<4,options=struct();end
            if ~isempty(axesHandle)&&~isgraphics(axesHandle,'axes')
                error('lmz:Renderer:Axes','A valid classic axes or UIAxes is required.');
            end
            obj.Axes=axesHandle;obj.Profile=profile;obj.setOptions(options,false);
            if ~isempty(simulation),obj.initialize(simulation);end
        end

        function initialize(obj,simulation)
            if isempty(obj.Axes)||~isgraphics(obj.Axes,'axes')
                error('lmz:Renderer:Axes','A valid classic axes or UIAxes is required.');
            end
            if ~isa(simulation,'lmz.api.SimulationResult')
                error('lmz:Renderer:Simulation','SimulationResult is required.');
            end
            obj.clear();obj.Simulation=simulation;obj.CurrentIndex=1;
            originalGraphics=findall(obj.Axes);
            try
                obj.configureAxes();obj.buildHandles();obj.IsInitialized=true;
                obj.updateFrame(1);
            catch exception
                deleteNewGraphics(obj.Axes,originalGraphics);
                obj.Handles=struct();obj.IsInitialized=false;
                obj.CurrentIndex=1;obj.Simulation=[];
                rethrow(exception)
            end
        end

        function updateFrame(obj,index)
            if ~obj.IsInitialized||isempty(obj.Simulation),return,end
            count=obj.frameCount();
            if index>=0&&index<=1&&index~=fix(index)
                index=1+round(index*(count-1));
            end
            index=max(1,min(count,round(index)));
            obj.updateHandles(index);obj.CurrentIndex=index;
            drawnow limitrate
        end

        function setOptions(obj,options,rebuild)
            if nargin<2||isempty(options),options=struct();end
            if nargin<3,rebuild=false;end
            if ~isstruct(options)||~isscalar(options)
                error('lmz:Renderer:Options','Renderer options must be a scalar object.');
            end
            allowed={'ShowForces','DetailedOverlay','GroundVisible','CameraFollow', ...
                'GroundStyle','Palette'};
            names=fieldnames(options);
            if ~all(ismember(names,allowed))
                error('lmz:Renderer:Option','Renderer options contain an unknown field.');
            end
            logicalNames={'ShowForces','DetailedOverlay','GroundVisible','CameraFollow'};
            for index=1:numel(logicalNames)
                name=logicalNames{index};
                if isfield(options,name)
                    value=options.(name);
                    if ~islogical(value)||~isscalar(value)
                        error('lmz:Renderer:OptionType','%s must be logical.',name);
                    end
                end
            end
            if isfield(options,'GroundStyle')
                options.GroundStyle=validatedTextOption(options.GroundStyle, ...
                    'GroundStyle');
                known={'hatched','line','plain','hidden','none'};
                options.GroundStyle=lower(options.GroundStyle);
                if ~ismember(options.GroundStyle,known)
                    error('lmz:Renderer:GroundStyle', ...
                        'GroundStyle must be hatched, line, plain, hidden, or none.');
                end
            end
            if isfield(options,'Palette')
                options.Palette=validatedTextOption(options.Palette,'Palette');
                if isempty(regexp(options.Palette, ...
                        '^[A-Za-z][A-Za-z0-9_-]*$','once'))
                    error('lmz:Renderer:Palette', ...
                        'Palette must be a declarative profile identifier.');
                end
            end
            for index=1:numel(logicalNames)
                name=logicalNames{index};
                if isfield(options,name),obj.(name)=options.(name);end
            end
            obj.Options=mergeStruct(obj.Options,options);
            if rebuild&&obj.IsInitialized
                simulation=obj.Simulation;index=obj.CurrentIndex;
                obj.initialize(simulation);obj.updateFrame(index);
            elseif obj.IsInitialized
                obj.applyOptions();obj.updateFrame(obj.CurrentIndex);
            end
        end

        function setProfile(obj,profile)
            if ~isempty(profile)&&~isa(profile,'lmz.viz.VisualizationProfile')
                error('lmz:Renderer:Profile','VisualizationProfile is required.');
            end
            unchanged=~isempty(obj.Profile)&&~isempty(profile)&& ...
                isequal(obj.Profile,profile);
            obj.Profile=profile;
            if obj.IsInitialized&&~unchanged
                simulation=obj.Simulation;index=obj.CurrentIndex;
                obj.initialize(simulation);obj.updateFrame(index);
            end
        end

        function count=frameCount(obj)
            if isempty(obj.Simulation),count=0;else,count=numel(obj.Simulation.Time);end
        end

        function imageData=captureFrame(obj)
            if ~obj.IsInitialized||isempty(obj.Simulation)|| ...
                    isempty(obj.Axes)||~isgraphics(obj.Axes,'axes')
                error('lmz:Renderer:Capture', ...
                    'An initialized renderer with valid axes is required.');
            end
            imageData=lmz.compat.Graphics.captureAxes(obj.Axes,120);
        end

        function resetCamera(obj)
            if isempty(obj.Axes)||~isgraphics(obj.Axes,'axes')||isempty(obj.Profile),return,end
            camera=obj.Profile.Camera;
            if isfield(camera,'xLimits'),xlim(obj.Axes,camera.xLimits);end
            if isfield(camera,'yLimits'),ylim(obj.Axes,camera.yLimits);end
            if isfield(camera,'dataAspectRatio'),daspect(obj.Axes,camera.dataAspectRatio);end
            if isfield(camera,'follow'),obj.CameraFollow=camera.follow;else,obj.CameraFollow=false;end
        end

        function clear(obj)
            deleteGraphics(obj.Handles);obj.Handles=struct();
            obj.IsInitialized=false;obj.CurrentIndex=1;
        end

        function delete(obj)
            obj.clear();obj.Simulation=[];obj.Profile=[];obj.Axes=[];
        end
    end

    methods (Access=protected)
        function configureAxes(obj)
            hold(obj.Axes,'on');
            if isempty(obj.Profile)
                grid(obj.Axes,'on');axis(obj.Axes,'equal');return
            end
            spec=obj.Profile.Axis;
            if fieldOr(spec,'grid',true),grid(obj.Axes,'on');else,grid(obj.Axes,'off');end
            if fieldOr(spec,'equal',true),axis(obj.Axes,'equal');end
            if isfield(spec,'visible')&&~spec.visible,axis(obj.Axes,'off');else,axis(obj.Axes,'on');end
            if isfield(spec,'xLabel'),xlabel(obj.Axes,spec.xLabel,'Interpreter','none');end
            if isfield(spec,'yLabel'),ylabel(obj.Axes,spec.yLabel,'Interpreter','none');end
            if isfield(spec,'title'),title(obj.Axes,spec.title,'Interpreter','none');end
            if isfield(spec,'backgroundColor'),obj.Axes.Color=spec.backgroundColor;end
            camera=obj.Profile.Camera;
            if isfield(camera,'xLimits'),xlim(obj.Axes,camera.xLimits);end
            if isfield(camera,'yLimits'),ylim(obj.Axes,camera.yLimits);end
            if isfield(camera,'dataAspectRatio'),daspect(obj.Axes,camera.dataAspectRatio);end
            if isfield(camera,'follow')&&~isfield(obj.Options,'CameraFollow')
                obj.CameraFollow=camera.follow;
            end
        end

        function applyOptions(obj) %#ok<MANU>
            % Subclasses may update visibility/style without rebuilding.
        end
    end

    methods (Abstract,Access=protected)
        buildHandles(obj)
        updateHandles(obj,index)
    end
end

function result=mergeStruct(first,second)
result=first;names=fieldnames(second);
for index=1:numel(names),result.(names{index})=second.(names{index});end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
function deleteGraphics(value)
if isempty(value),return,end
if isstruct(value)
    names=fieldnames(value);
    for element=1:numel(value)
        for index=1:numel(names)
            deleteGraphics(value(element).(names{index}));
        end
    end
elseif iscell(value)
    for index=1:numel(value),deleteGraphics(value{index});end
else
    for index=1:numel(value)
        try
            if isgraphics(value(index)),delete(value(index));end
        catch
        end
    end
end
end

function value=validatedTextOption(value,name)
if isstring(value)&&isscalar(value),value=char(value);end
if ~ischar(value)||size(value,1)~=1||isempty(strtrim(value))
    error('lmz:Renderer:OptionType','%s must be nonempty scalar text.',name);
end
value=strtrim(value);
end

function deleteNewGraphics(axesHandle,originalGraphics)
if isempty(axesHandle)||~isgraphics(axesHandle,'axes'),return,end
current=findall(axesHandle);
for currentIndex=1:numel(current)
    existed=false;
    for originalIndex=1:numel(originalGraphics)
        if isequal(current(currentIndex),originalGraphics(originalIndex))
            existed=true;break
        end
    end
    if ~existed&&isgraphics(current(currentIndex))
        try
            delete(current(currentIndex));
        catch
        end
    end
end
end
