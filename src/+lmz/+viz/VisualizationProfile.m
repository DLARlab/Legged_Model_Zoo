classdef VisualizationProfile
    %VISUALIZATIONPROFILE Immutable, validated rendering-profile metadata.
    properties (SetAccess=private)
        Id
        Label
        RendererClass
        ScenePath
        StylePath
        Style
        Camera
        Axis
        Layers
        Overlays
        PlotProfile
        RecordingProfile
        Maturities
    end

    methods
        function obj=VisualizationProfile(value,scenePath,stylePath,style)
            if nargin==0,return,end
            if nargin<2,scenePath='';end
            if nargin<3,stylePath='';end
            if nargin<4,style=struct();end
            required={'id','label','rendererClass','camera','axis','layers', ...
                'overlays','plotProfile','recordingProfile','maturities'};
            if ~isstruct(value)||~isscalar(value)
                error('lmz:Graphics:ProfileType', ...
                    'Each visualization profile must be one object.');
            end
            for index=1:numel(required)
                if ~isfield(value,required{index})
                    error('lmz:Graphics:ProfileField', ...
                        'Visualization profile is missing %s.',required{index});
                end
            end
            identifier(value.id,'profile ID');
            nonemptyText(value.label,'profile label');
            className(value.rendererClass);
            if ~isstruct(value.camera)||~isscalar(value.camera)|| ...
                    ~isstruct(value.axis)||~isscalar(value.axis)|| ...
                    ~isstruct(value.recordingProfile)||~isscalar(value.recordingProfile)
                error('lmz:Graphics:ProfileObject', ...
                    'Camera, axis, and recordingProfile must be objects.');
            end
            obj.Id=value.id;obj.Label=value.label;
            obj.RendererClass=value.rendererClass;
            obj.ScenePath=scenePath;obj.StylePath=stylePath;obj.Style=style;
            obj.Camera=value.camera;obj.Axis=value.axis;
            obj.Layers=textList(value.layers,'layers');
            obj.Overlays=textList(value.overlays,'overlays');
            identifier(value.plotProfile,'plot profile');
            obj.PlotProfile=value.plotProfile;
            obj.RecordingProfile=value.recordingProfile;
            obj.Maturities=textList(value.maturities,'maturities');
            allowed={'tutorial','compatibility','validated','experimental'};
            if isempty(obj.Maturities)||~all(ismember(obj.Maturities,allowed))
                error('lmz:Graphics:ProfileMaturity', ...
                    'Profile maturities contain an unsupported value.');
            end
        end

        function result=appliesTo(obj,maturity)
            result=any(strcmp(char(maturity),obj.Maturities));
        end

        function value=toStruct(obj)
            value=struct('id',obj.Id,'label',obj.Label, ...
                'rendererClass',obj.RendererClass,'scenePath',obj.ScenePath, ...
                'stylePath',obj.StylePath,'camera',obj.Camera,'axis',obj.Axis, ...
                'layers',{obj.Layers},'overlays',{obj.Overlays}, ...
                'plotProfile',obj.PlotProfile, ...
                'recordingProfile',obj.RecordingProfile, ...
                'maturities',{obj.Maturities});
        end
    end
end

function identifier(value,description)
if ~ischar(value)||isempty(regexp(value,'^[A-Za-z][A-Za-z0-9_]*$','once'))
    error('lmz:Graphics:Identifier', ...
        '%s must be a simple identifier, never an expression.',description);
end
end

function className(value)
if ~ischar(value)||isempty(regexp(value, ...
        '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$','once'))
    error('lmz:Graphics:RendererClass','Renderer class name is invalid.');
end
end

function nonemptyText(value,description)
if ~ischar(value)||isempty(strtrim(value))
    error('lmz:Graphics:Text','%s must be nonempty text.',description);
end
end

function values=textList(value,description)
if isempty(value)
    values={};
elseif ischar(value)
    values={value};
elseif iscell(value)&&all(cellfun(@ischar,value))
    values=reshape(value,1,[]);
else
    error('lmz:Graphics:TextList','%s must be a string list.',description);
end
for index=1:numel(values),identifier(values{index},description);end
end
