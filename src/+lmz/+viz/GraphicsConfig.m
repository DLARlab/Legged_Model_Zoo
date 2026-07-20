classdef GraphicsConfig
    %GRAPHICSCONFIG Validated declarative visualization configuration.
    properties (SetAccess=private)
        SchemaVersion
        CatalogDirectory
        TrustedCodeRoot
        TrustedNamespace
        Profiles
        DefaultProfileByMaturity
        RequiredFrames
        RequiredParameters
    end

    methods (Static)
        function obj=fromJson(path,catalogDirectory,trustedCodeRoot,trustedNamespace)
            if nargin<2,catalogDirectory=fileparts(path);end
            if nargin<3,trustedCodeRoot=lmz.util.ProjectPaths.models();end
            if nargin<4,trustedNamespace='lmzmodels';end
            path=lmz.util.PathGuard.canonical(path,true);
            lmz.util.PathGuard.assertWithin(catalogDirectory,path);
            value=lmz.io.SafeJson.read(path,'Root',catalogDirectory);
            obj=lmz.viz.GraphicsConfig(value,catalogDirectory, ...
                trustedCodeRoot,trustedNamespace);
        end

        function obj=cleanGeneric(catalogDirectory,trustedCodeRoot,trustedNamespace)
            if nargin<3,trustedNamespace='lmzmodels';end
            scene='scene.lmz.json';
            value=struct('schemaVersion','1.0.0', ...
                'defaultProfileByMaturity',struct('tutorial','clean_generic', ...
                'compatibility','clean_generic','validated','clean_generic', ...
                'experimental','clean_generic'), ...
                'requiredFrames',{{}},'requiredParameters',{{}}, ...
                'profiles',struct('id','clean_generic','label','Clean generic', ...
                'rendererClass','lmz.viz.SceneRenderer2D','sceneFile',scene, ...
                'styleFile','','camera',struct(),'axis',struct(), ...
                'layers',{{'ground','model','overlay'}},'overlays',{{}}, ...
                'plotProfile','clean_generic','recordingProfile',struct(), ...
                'maturities',{{'tutorial','compatibility','validated','experimental'}}));
            obj=lmz.viz.GraphicsConfig(value,catalogDirectory, ...
                trustedCodeRoot,trustedNamespace);
        end
    end

    methods
        function obj=GraphicsConfig(value,catalogDirectory,trustedCodeRoot,trustedNamespace)
            if nargin==0,return,end
            if ~isstruct(value)||~isscalar(value)
                error('lmz:Graphics:ConfigType','Graphics JSON must contain one object.');
            end
            required={'schemaVersion','defaultProfileByMaturity','profiles'};
            for index=1:numel(required)
                if ~isfield(value,required{index})
                    error('lmz:Graphics:ConfigField', ...
                        'Graphics config is missing %s.',required{index});
                end
            end
            if ~ischar(value.schemaVersion)||~strcmp(value.schemaVersion,'1.0.0')
                error('lmz:Graphics:SchemaVersion', ...
                    'Unsupported graphics schema version.');
            end
            catalogDirectory=lmz.util.PathGuard.canonical(catalogDirectory,true);
            trustedCodeRoot=lmz.util.PathGuard.canonical(trustedCodeRoot,true);
            if ~ischar(trustedNamespace)||isempty(regexp(trustedNamespace, ...
                    '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*$','once'))
                error('lmz:Graphics:TrustedNamespace','Trusted namespace is invalid.');
            end
            obj.SchemaVersion=value.schemaVersion;
            obj.CatalogDirectory=catalogDirectory;
            obj.TrustedCodeRoot=trustedCodeRoot;
            obj.TrustedNamespace=trustedNamespace;
            obj.RequiredFrames=optionalTextList(value,'requiredFrames');
            obj.RequiredParameters=optionalTextList(value,'requiredParameters');
            rawProfiles=objectCells(value.profiles);
            if isempty(rawProfiles)||numel(rawProfiles)>32
                error('lmz:Graphics:ProfileCount', ...
                    'Graphics config must declare between 1 and 32 profiles.');
            end
            profiles=cell(1,numel(rawProfiles));ids=cell(1,numel(rawProfiles));
            for index=1:numel(rawProfiles)
                raw=rawProfiles{index};
                scenePath=resolveOptionalFile(raw,'sceneFile',catalogDirectory);
                if ~isempty(scenePath)
                    scene=lmz.viz.SceneSpec.fromJson(scenePath,catalogDirectory);
                    if ~all(ismember(obj.RequiredFrames,scene.Frames))
                        error('lmz:Graphics:UnknownRequiredFrame', ...
                            'Graphics config requires a frame absent from its scene.');
                    end
                end
                stylePath=resolveOptionalFile(raw,'styleFile',catalogDirectory);
                if isempty(stylePath),style=struct();else
                    style=lmz.io.SafeJson.read(stylePath,'Root',catalogDirectory);
                    validateStyle(style,'style');
                end
                profile=lmz.viz.VisualizationProfile(raw,scenePath,stylePath,style);
                assertRendererClass(profile.RendererClass,trustedCodeRoot,trustedNamespace);
                validateCamera(profile.Camera);validateAxis(profile.Axis);
                validateLayers(profile.Layers);validateOverlays(profile.Overlays);
                validateRecording(profile.RecordingProfile);
                profiles{index}=profile;ids{index}=profile.Id;
            end
            if numel(unique(ids))~=numel(ids)
                error('lmz:Graphics:DuplicateProfile','Visualization profile IDs must be unique.');
            end
            defaults=value.defaultProfileByMaturity;
            if ~isstruct(defaults)||~isscalar(defaults)
                error('lmz:Graphics:DefaultProfiles', ...
                    'defaultProfileByMaturity must be an object.');
            end
            maturities=fieldnames(defaults);
            allowed={'tutorial','compatibility','validated','experimental'};
            if isempty(maturities)||~all(ismember(maturities,allowed))|| ...
                    ~all(ismember(allowed,maturities))
                error('lmz:Graphics:DefaultMaturity', ...
                    'Every known maturity must declare a default profile.');
            end
            for index=1:numel(maturities)
                maturity=maturities{index};profileId=defaults.(maturity);
                match=find(strcmp(profileId,ids),1);
                if ~ischar(profileId)||isempty(match)
                    error('lmz:Graphics:MissingDefaultProfile', ...
                        'Default profile for %s does not exist.',maturity);
                end
                if ~profiles{match}.appliesTo(maturity)
                    error('lmz:Graphics:DefaultProfileMaturity', ...
                        'Default profile %s does not apply to %s.',profileId,maturity);
                end
            end
            obj.Profiles=profiles;obj.DefaultProfileByMaturity=defaults;
        end

        function profile=getProfile(obj,id)
            ids=cellfun(@(item)item.Id,obj.Profiles,'UniformOutput',false);
            index=find(strcmp(char(id),ids),1);
            if isempty(index)
                error('lmz:Graphics:UnknownProfile','Unknown visualization profile: %s.',char(id));
            end
            profile=obj.Profiles{index};
        end

        function profiles=profilesForMaturity(obj,maturity)
            selected=cellfun(@(item)item.appliesTo(maturity),obj.Profiles);
            profiles=obj.Profiles(selected);
        end

        function id=defaultForMaturity(obj,maturity)
            maturity=char(maturity);
            if isfield(obj.DefaultProfileByMaturity,maturity)
                id=obj.DefaultProfileByMaturity.(maturity);
            else
                error('lmz:Graphics:UnknownMaturity', ...
                    'Unknown problem maturity: %s.',maturity);
            end
            obj.getProfile(id);
        end

        function validateContract(obj,availableFrames,availableParameters)
            %VALIDATECONTRACT Bind declarative requirements to model metadata.
            availableFrames=contractNames(availableFrames,'frames');
            availableParameters=contractNames(availableParameters,'parameters');
            missingFrames=setdiff(obj.RequiredFrames,availableFrames);
            if ~isempty(missingFrames)
                error('lmz:Graphics:UnknownRequiredFrame', ...
                    'Graphics config requires unknown frame %s.',missingFrames{1});
            end
            missingParameters=setdiff(obj.RequiredParameters,availableParameters);
            if ~isempty(missingParameters)
                error('lmz:Graphics:UnknownRequiredParameter', ...
                    'Graphics config requires unknown parameter %s.', ...
                    missingParameters{1});
            end
        end
    end
end

function values=optionalTextList(source,name)
if ~isfield(source,name)||isempty(source.(name)),values={};return,end
value=source.(name);
if ischar(value)
    values={value};
elseif iscell(value)&&all(cellfun(@ischar,value))
    values=reshape(value,1,[]);
else
    error('lmz:Graphics:TextList','%s must be a string list.',name);
end
for index=1:numel(values)
    if isempty(regexp(values{index},'^[A-Za-z][A-Za-z0-9_]*$','once'))
        error('lmz:Graphics:Identifier','%s contains an invalid identifier.',name);
    end
end
end

function values=contractNames(value,description)
if ischar(value),values={value};else,values=value;end
if isempty(values),values={};end
if ~iscell(values)||~all(cellfun(@ischar,values))
    error('lmz:Graphics:ContractNames', ...
        'Visualization contract %s must be a text list.',description);
end
values=reshape(values,1,[]);
if numel(unique(values))~=numel(values)||any(cellfun(@(item)isempty(regexp( ...
        item,'^[A-Za-z][A-Za-z0-9_]*$','once')),values))
    error('lmz:Graphics:ContractNames', ...
        'Visualization contract %s contain invalid or duplicate names.',description);
end
end

function values=objectCells(value)
if isstruct(value)
    values=num2cell(value(:).');
elseif iscell(value)&& ...
        all(cellfun(@(item)isstruct(item)&&isscalar(item),value))
    values=reshape(value,1,[]);
else
    error('lmz:Graphics:Profiles','profiles must be an object array.');
end
end

function path=resolveOptionalFile(source,name,root)
path='';if ~isfield(source,name)||isempty(source.(name)),return,end
if ~ischar(source.(name)),error('lmz:Graphics:File','%s must be relative text.',name);end
path=lmz.util.PathGuard.resolveWithin(root,source.(name),true);
end

function assertRendererClass(className,codeRoot,trustedNamespace)
framework=strcmp(className,'lmz.viz.SceneRenderer2D');
prefix=[trustedNamespace '.'];
if ~framework&&~strncmp(className,prefix,numel(prefix))
    error('lmz:Graphics:UntrustedRenderer', ...
        'Renderer class is outside its approved namespace.');
end
matches=which(className,'-all');
if isempty(matches)
    error('lmz:Graphics:MissingRenderer','Renderer class is unavailable: %s.',className);
end
if ischar(matches),matches={matches};end
canonical=cellfun(@(item)lmz.util.PathGuard.canonical(item,true),matches, ...
    'UniformOutput',false);canonical=unique(canonical);
if numel(canonical)~=1
    error('lmz:Graphics:AmbiguousRenderer','Renderer class is ambiguous: %s.',className);
end
if framework,root=lmz.util.ProjectPaths.src();else,root=codeRoot;end
if ~lmz.util.PathGuard.isWithin(root,canonical{1})
    error('lmz:Graphics:RendererOutsideRoot', ...
        'Renderer class resolves outside its trusted code root.');
end
definition=meta.class.fromName(className);
if isempty(definition)||~derivesFrom(definition,'lmz.viz.Renderer')
    error('lmz:Graphics:RendererContract', ...
        'Configured renderer must derive from lmz.viz.Renderer.');
end
end

function result=derivesFrom(definition,baseName)
result=strcmp(definition.Name,baseName);
if result,return,end
parents=definition.SuperclassList;
for index=1:numel(parents)
    if derivesFrom(parents(index),baseName),result=true;return,end
end
end

function validateCamera(value)
allowed={'xLimits','yLimits','dataAspectRatio','follow','followWindow','position'};
if ~all(ismember(fieldnames(value),allowed))
    error('lmz:Graphics:CameraField','Camera contains an unknown field.');
end
limits={'xLimits','yLimits'};
for index=1:numel(limits)
    name=limits{index};
    if isfield(value,name)
        limitsValue=value.(name);
        if ~isnumeric(limitsValue)||numel(limitsValue)~=2|| ...
                any(~isfinite(limitsValue))||limitsValue(2)<=limitsValue(1)
            error('lmz:Graphics:CameraLimits','Camera %s must increase.',name);
        end
    end
end
if isfield(value,'dataAspectRatio')&&(~isnumeric(value.dataAspectRatio)|| ...
        numel(value.dataAspectRatio)~=3||any(~isfinite(value.dataAspectRatio))|| ...
        any(value.dataAspectRatio<=0))
    error('lmz:Graphics:CameraAspect','Camera aspect must contain three positive values.');
end
if isfield(value,'follow')&&(~islogical(value.follow)||~isscalar(value.follow))
    error('lmz:Graphics:CameraFollow','Camera follow must be logical.');
end
if isfield(value,'followWindow')
    window=value.followWindow;
    validScalar=isnumeric(window)&&isreal(window)&&isscalar(window)&& ...
        isfinite(window)&&window>0;
    validOffsets=isnumeric(window)&&isreal(window)&&numel(window)==2&& ...
        all(isfinite(window(:)))&&window(2)>window(1);
    if ~(validScalar||validOffsets)
        error('lmz:Graphics:CameraValue', ...
            'Camera followWindow must be positive width or increasing offsets.');
    end
end
if isfield(value,'position')
    position=value.position;
    if ~isnumeric(position)||~isreal(position)||numel(position)~=4|| ...
            any(~isfinite(position(:)))||any(position(3:4)<=0)
        error('lmz:Graphics:CameraValue', ...
            'Camera position must be [x y width height] with positive size.');
    end
end
end

function validateAxis(value)
allowed={'equal','grid','visible','xLabel','yLabel','title','backgroundColor'};
if ~all(ismember(fieldnames(value),allowed)),error('lmz:Graphics:AxisField', ...
        'Axis contains an unknown field.');end
for name={'equal','grid','visible'}
    if isfield(value,name{1})&&(~islogical(value.(name{1}))||~isscalar(value.(name{1})))
        error('lmz:Graphics:AxisFlag','Axis %s must be logical.',name{1});
    end
end
for name={'xLabel','yLabel','title'}
    if isfield(value,name{1})&&~ischar(value.(name{1}))
        error('lmz:Graphics:AxisText','Axis %s must be text.',name{1});
    end
end
if isfield(value,'backgroundColor'),validateColor(value.backgroundColor,'backgroundColor');end
end

function validateLayers(values)
allowed={'ground','shadow','model','body','legs','com','load','rope','forces', ...
    'phase','labels','overlay'};
if ~all(ismember(values,allowed))||numel(unique(values))~=numel(values)
    error('lmz:Graphics:LayerType','Layer types must be known and unique.');
end
end
function validateOverlays(values)
allowed={'detailed_phase','phase_labels','force_vectors','contacts','trajectory'};
if ~all(ismember(values,allowed)),error('lmz:Graphics:OverlayType','Unknown overlay type.');end
end
function validateRecording(value)
allowed={'frameCount','fps','dpi','backgroundColor'};
if ~all(ismember(fieldnames(value),allowed)),error('lmz:Graphics:RecordingField', ...
        'Recording profile contains an unknown field.');end
if isfield(value,'frameCount')
    frameCount=value.frameCount;
    if ~isnumeric(frameCount)||~isreal(frameCount)||~isscalar(frameCount)|| ...
            ~isfinite(frameCount)||frameCount~=fix(frameCount)||frameCount<2
        error('lmz:Graphics:RecordingFrameCount', ...
            'Recording frameCount must be an integer of at least 2.');
    end
end
for name={'fps','dpi'}
    if isfield(value,name{1})&&(~isnumeric(value.(name{1}))|| ...
            ~isreal(value.(name{1}))||~isscalar(value.(name{1}))|| ...
            ~isfinite(value.(name{1}))||value.(name{1})<=0)
        error('lmz:Graphics:RecordingValue','Recording %s must be positive.',name{1});
    end
end
if isfield(value,'backgroundColor')
    validateRgbColor(value.backgroundColor,'recordingProfile.backgroundColor');
end
end

function validateStyle(value,path)
if ~isstruct(value)||~isscalar(value),error('lmz:Graphics:StyleType', ...
        'Style file must contain one object.');end
names=fieldnames(value);
for index=1:numel(names)
    name=names{index};item=value.(name);itemPath=[path '.' name];
    if isstruct(item),validateStyle(item,itemPath);continue,end
    if isnumeric(item)
        if ~isreal(item)||any(~isfinite(item(:)))
            error('lmz:Graphics:StyleNumeric','%s must be finite and real.',itemPath);
        end
        if ~isempty(regexpi(name,'colors$','once'))
            validateColorTable(item,itemPath);
        elseif ~isempty(regexpi(name,'color$','once'))
            validateColor(item,itemPath);
        end
        if ~isempty(regexpi(name,'(width|size|radius|length|scale)$','once'))&&any(item(:)<=0)
            error('lmz:Graphics:StylePositive','%s must be positive.',itemPath);
        end
        if ~isempty(regexpi(name,'alpha$','once'))&&(any(item(:)<0)||any(item(:)>1))
            error('lmz:Graphics:StyleAlpha','%s must lie in [0,1].',itemPath);
        end
    elseif ~(ischar(item)||islogical(item)||iscell(item))
        error('lmz:Graphics:StyleValue','%s has an unsupported value.',itemPath);
    end
end
end
function validateColor(value,description)
if ~isnumeric(value)||~any(numel(value)==[3 4])||any(~isfinite(value(:)))|| ...
        any(value(:)<0)||any(value(:)>1)
    error('lmz:Graphics:Color','%s must be RGB or RGBA in [0,1].',description);
end
end

function validateColorTable(value,description)
if ~isnumeric(value)||~ismatrix(value)||~any(size(value,2)==[3 4])|| ...
        isempty(value)||any(~isfinite(value(:)))||any(value(:)<0)||any(value(:)>1)
    error('lmz:Graphics:Color', ...
        '%s must contain RGB or RGBA rows in [0,1].',description);
end
end
function validateRgbColor(value,description)
if ~isnumeric(value)||~isreal(value)||numel(value)~=3|| ...
        any(~isfinite(value(:)))||any(value(:)<0)||any(value(:)>1)
    error('lmz:Graphics:Color','%s must be RGB in [0,1].',description);
end
end
