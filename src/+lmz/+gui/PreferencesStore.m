classdef PreferencesStore < handle
    %PREFERENCESSTORE Versioned, resettable GUI preferences.
    properties (SetAccess=private)
        Namespace
        ProjectRoot
    end
    properties (Constant)
        SchemaVersion = 4
    end

    methods
        function obj = PreferencesStore(varargin)
            parser = inputParser;
            addParameter(parser,'Namespace','LeggedModelZoo_GUI_v1', ...
                @(value)ischar(value)||(isstring(value)&&isscalar(value)));
            addParameter(parser,'ProjectRoot',lmz.util.ProjectPaths.root(), ...
                @(value)ischar(value)||(isstring(value)&&isscalar(value)));
            parse(parser,varargin{:});
            obj.Namespace = char(parser.Results.Namespace);
            obj.ProjectRoot = canonicalPath(char(parser.Results.ProjectRoot));
        end

        function value = palette(obj)
            value = obj.get('Palette','default');
            if ~any(strcmp(value,{'default','high-contrast'})), value = 'default'; end
        end

        function setPalette(obj,value)
            value = char(value);
            if ~any(strcmp(value,{'default','high-contrast'}))
                error('lmz:GUI:Palette','Palette must be default or high-contrast.');
            end
            obj.set('Palette',value);
        end

        function value = windowPosition(obj,fallback)
            value = obj.get('WindowPosition',fallback);
            if ~isnumeric(value)||numel(value)~=4||any(~isfinite(value))|| ...
                    any(value(3:4)<1)
                value = fallback;
            end
            value = reshape(value,1,4);
        end

        function setWindowPosition(obj,value)
            if ~isnumeric(value)||numel(value)~=4||any(~isfinite(value))|| ...
                    any(value(3:4)<1)
                error('lmz:GUI:WindowPosition','Window position must contain four finite values.');
            end
            obj.set('WindowPosition',reshape(value,1,4));
        end

        function value=layoutProfile(obj,fallback)
            %LAYOUTPROFILE Selected application-shell layout identifier.
            if nargin<2,fallback='classic_tabs';end
            fallback=validIdentifierFallback(fallback,'classic_tabs');
            value=obj.get('LayoutProfile',fallback);
            if ~isLowerIdentifier(value),value=fallback;else,value=char(value);end
        end

        function setLayoutProfile(obj,value)
            if ~isLowerIdentifier(value)
                error('lmz:GUI:LayoutProfilePreference', ...
                    'Layout profile must be a lowercase identifier.');
            end
            obj.set('LayoutProfile',char(value));
        end

        function value=sidebarTab(obj,fallback)
            %SIDEBARTAB Persistent selected sidebar tab ID or title.
            if nargin<2,fallback='info_selection';end
            fallback=validTabFallback(fallback,'info_selection');
            value=obj.get('SidebarTab',fallback);
            if ~isTabValue(value),value=fallback;else,value=char(value);end
        end

        function setSidebarTab(obj,value)
            if ~isTabValue(value)
                error('lmz:GUI:SidebarTabPreference', ...
                    'Sidebar tab must be nonempty scalar text.');
            end
            obj.set('SidebarTab',char(value));
        end

        function value=centralViewTab(obj,fallback)
            %CENTRALVIEWTAB Persistent selected central-workspace view.
            if nargin<2,fallback='branch_state';end
            fallback=validTabFallback(fallback,'branch_state');
            value=obj.get('CentralViewTab',fallback);
            if ~isTabValue(value),value=fallback;else,value=char(value);end
        end

        function setCentralViewTab(obj,value)
            if ~isTabValue(value)
                error('lmz:GUI:CentralViewTabPreference', ...
                    'Central view tab must be nonempty scalar text.');
            end
            obj.set('CentralViewTab',char(value));
        end

        function value=sidebarWidthRatio(obj,fallback)
            %SIDEBARWIDTHRATIO Fraction of workbench width used by sidebar.
            if nargin<2,fallback=1.85/(3.35+1.85);end
            if ~isSidebarRatio(fallback),fallback=1.85/(3.35+1.85);end
            value=obj.get('SidebarWidthRatio',fallback);
            if ~isSidebarRatio(value),value=fallback;end
            value=double(value);
        end

        function setSidebarWidthRatio(obj,value)
            if ~isSidebarRatio(value)
                error('lmz:GUI:SidebarWidthRatioPreference', ...
                    'Sidebar width ratio must be a finite scalar between zero and one.');
            end
            obj.set('SidebarWidthRatio',double(value));
        end

        function value = recentDataFolder(obj,fallback)
            if nargin<2, fallback = pwd; end
            value = obj.validRecent('RecentDataFolder',fallback);
        end

        function value = recentOutputFolder(obj,fallback)
            if nargin<2, fallback = pwd; end
            value = obj.validRecent('RecentOutputFolder',fallback);
        end

        function rememberDataFolder(obj,value)
            obj.rememberRecent('RecentDataFolder',value);
        end

        function rememberOutputFolder(obj,value)
            obj.rememberRecent('RecentOutputFolder',value);
        end

        function value=visualizationProfile(obj,modelId,problemId,fallback)
            if nargin<4,fallback='';end
            name=profilePreferenceName(modelId,problemId);
            value=obj.get(name,fallback);
            if ~ischar(value)||isempty(regexp(value, ...
                    '^[A-Za-z][A-Za-z0-9_]*$','once'))
                value=fallback;
            end
        end

        function setVisualizationProfile(obj,modelId,problemId,profileId)
            name=profilePreferenceName(modelId,problemId);
            if ~ischar(profileId)||isempty(regexp(profileId, ...
                    '^[A-Za-z][A-Za-z0-9_]*$','once'))
                error('lmz:GUI:VisualizationProfile', ...
                    'Visualization profile must be a simple identifier.');
            end
            obj.set(name,profileId);
        end

        function value=sectionPreference(obj,modelId,problemId,fallback)
            if nargin<4,fallback=struct();end
            name=workflowPreferenceName('Section',modelId,problemId);
            value=obj.get(name,fallback);
            required={'StartSectionId','StopSectionId','StartStateSide', ...
                'StopStateSide','CrossingDirection','MinimumReturnTime'};
            if ~isstruct(value)||~isscalar(value)||~all(isfield(value,required))
                value=fallback;return
            end
            identifiers={value.StartSectionId,value.StopSectionId};
            validIds=all(cellfun(@(item)ischar(item)&&~isempty(regexp( ...
                item,'^[A-Za-z][A-Za-z0-9_]*$','once')),identifiers));
            validSides=ischar(value.StartStateSide)&& ...
                ischar(value.StopStateSide)&& ...
                any(strcmp(value.StartStateSide,{'pre','post'}))&& ...
                any(strcmp(value.StopStateSide,{'pre','post'}));
            validNumbers=isnumeric(value.CrossingDirection)&& ...
                isscalar(value.CrossingDirection)&& ...
                ismember(value.CrossingDirection,[-1 0 1])&& ...
                isnumeric(value.MinimumReturnTime)&& ...
                isscalar(value.MinimumReturnTime)&& ...
                isfinite(value.MinimumReturnTime)&&value.MinimumReturnTime>=0;
            if ~(validIds&&validSides&&validNumbers),value=fallback;end
        end

        function setSectionPreference(obj,modelId,problemId,value)
            fallback=struct('StartSectionId','apex','StopSectionId','apex', ...
                'StartStateSide','post','StopStateSide','post', ...
                'CrossingDirection',0,'MinimumReturnTime',0);
            name=workflowPreferenceName('Section',modelId,problemId);
            obj.set(name,value);
            if ~isequaln(obj.sectionPreference(modelId,problemId,fallback),value)
                if ispref(obj.Namespace,name),rmpref(obj.Namespace,name);end
                error('lmz:GUI:SectionPreference', ...
                    'Poincare section preference is invalid.');
            end
        end

        function value=stridePreference(obj,modelId,problemId,fallback)
            if nargin<4
                fallback=struct('RequestedStrideCount',1, ...
                    'CompletionPolicy','error_if_missing', ...
                    'FailurePolicy','return_partial','EnergyNeutralOnly',true);
            end
            name=workflowPreferenceName('Stride',modelId,problemId);
            value=obj.get(name,fallback);
            if ~isstruct(value)||~isscalar(value)|| ...
                    ~all(isfield(value,fieldnames(fallback)))|| ...
                    ~isnumeric(value.RequestedStrideCount)|| ...
                    ~isscalar(value.RequestedStrideCount)|| ...
                    value.RequestedStrideCount<1|| ...
                    value.RequestedStrideCount~=fix(value.RequestedStrideCount)
                value=fallback;
            end
        end

        function setStridePreference(obj,modelId,problemId,value)
            name=workflowPreferenceName('Stride',modelId,problemId);
            obj.set(name,value);
        end

        function reset(obj)
            if ispref(obj.Namespace), rmpref(obj.Namespace); end
        end

        function value = snapshot(obj)
            value = struct('SchemaVersion',obj.SchemaVersion, ...
                'Palette',obj.palette(), ...
                'WindowPosition',obj.windowPosition([40 40 1460 900]), ...
                'LayoutProfile',obj.layoutProfile(), ...
                'SidebarTab',obj.sidebarTab(), ...
                'CentralViewTab',obj.centralViewTab(), ...
                'SidebarWidthRatio',obj.sidebarWidthRatio(), ...
                'RecentDataFolder',obj.recentDataFolder(''), ...
                'RecentOutputFolder',obj.recentOutputFolder(''), ...
                'VisualizationProfiles',obj.visualizationProfiles(), ...
                'WorkflowPreferences',obj.workflowPreferences());
        end
    end

    methods (Access=private)
        function value = get(obj,name,fallback)
            if ispref(obj.Namespace,name), value = getpref(obj.Namespace,name); ...
            else, value = fallback; end
        end

        function set(obj,name,value)
            setpref(obj.Namespace,name,value);
            setpref(obj.Namespace,'SchemaVersion',obj.SchemaVersion);
        end

        function rememberRecent(obj,name,value)
            if isstring(value), value = char(value); end
            if isempty(value), return, end
            value = canonicalPath(value);
            if exist(value,'dir')~=7
                error('lmz:GUI:RecentFolder','Recent folder does not exist: %s.',value);
            end
            if isInside(value,obj.ProjectRoot)
                return
            end
            obj.set(name,value);
        end

        function value = validRecent(obj,name,fallback)
            value = obj.get(name,fallback);
            if isstring(value), value = char(value); end
            if isempty(value), return, end
            value = canonicalPath(value);
            if exist(value,'dir')~=7||isInside(value,obj.ProjectRoot)
                value = fallback;
            end
        end

        function values=visualizationProfiles(obj)
            values=struct();
            if ~ispref(obj.Namespace),return,end
            preferences=getpref(obj.Namespace);names=fieldnames(preferences);
            prefix='VisualizationProfile_';
            for index=1:numel(names)
                name=names{index};
                if strncmp(name,prefix,numel(prefix))
                    values.(name(numel(prefix)+1:end))=preferences.(name);
                end
            end
        end

        function values=workflowPreferences(obj)
            values=struct();
            if ~ispref(obj.Namespace),return,end
            preferences=getpref(obj.Namespace);names=fieldnames(preferences);
            prefixes={'SectionPreference_','StridePreference_'};
            for index=1:numel(names)
                name=names{index};
                if any(cellfun(@(prefix)strncmp(name,prefix,numel(prefix)), ...
                        prefixes))
                    values.(name)=preferences.(name);
                end
            end
        end
    end
end

function name=profilePreferenceName(modelId,problemId)
modelId=char(modelId);problemId=char(problemId);
expression='^[a-z][a-z0-9_]*$';
if isempty(regexp(modelId,expression,'once'))|| ...
        isempty(regexp(problemId,expression,'once'))
    error('lmz:GUI:VisualizationPreferenceKey', ...
        'Model and problem IDs must be lowercase identifiers.');
end
name=['VisualizationProfile_' modelId '__' problemId];
end

function name=workflowPreferenceName(kind,modelId,problemId)
modelId=char(modelId);problemId=char(problemId);
expression='^[a-z][a-z0-9_]*$';
if isempty(regexp(modelId,expression,'once'))|| ...
        isempty(regexp(problemId,expression,'once'))
    error('lmz:GUI:WorkflowPreferenceKey', ...
        'Model and problem IDs must be lowercase identifiers.');
end
name=[kind 'Preference_' modelId '__' problemId];
end

function value = canonicalPath(value)
value = char(value);
try
    value = char(java.io.File(value).getCanonicalPath());
catch
    value = char(value);
end
end

function value=isLowerIdentifier(source)
value=(ischar(source)&&isrow(source))|| ...
    (isstring(source)&&isscalar(source));
if ~value,return,end
value=~isempty(regexp(char(source),'^[a-z][a-z0-9_]*$','once'));
end

function value=validIdentifierFallback(source,defaultValue)
if isLowerIdentifier(source),value=char(source);else,value=defaultValue;end
end

function value=isTabValue(source)
value=(ischar(source)&&isrow(source))|| ...
    (isstring(source)&&isscalar(source));
if ~value,return,end
source=char(source);
value=~isempty(strtrim(source))&&numel(source)<=256&& ...
    isempty(regexp(source,'[\x00-\x1F\x7F]','once'));
end

function value=validTabFallback(source,defaultValue)
if isTabValue(source),value=char(source);else,value=defaultValue;end
end

function value=isSidebarRatio(source)
value=isnumeric(source)&&isreal(source)&&isscalar(source)&& ...
    isfinite(source)&&source>0&&source<1;
end

function result = isInside(pathValue,root)
if isempty(pathValue)||isempty(root), result = false; return, end
pathValue = [canonicalPath(pathValue) filesep];
root = [canonicalPath(root) filesep];
if ispc
    result = strncmpi(pathValue,root,numel(root));
else
    result = strncmp(pathValue,root,numel(root));
end
end
