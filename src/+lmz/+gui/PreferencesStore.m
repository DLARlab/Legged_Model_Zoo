classdef PreferencesStore < handle
    %PREFERENCESSTORE Versioned, resettable GUI preferences.
    properties (SetAccess=private)
        Namespace
        ProjectRoot
    end
    properties (Constant)
        SchemaVersion = 1
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

        function reset(obj)
            if ispref(obj.Namespace), rmpref(obj.Namespace); end
        end

        function value = snapshot(obj)
            value = struct('SchemaVersion',obj.SchemaVersion, ...
                'Palette',obj.palette(), ...
                'WindowPosition',obj.windowPosition([40 40 1460 900]), ...
                'RecentDataFolder',obj.recentDataFolder(''), ...
                'RecentOutputFolder',obj.recentOutputFolder(''));
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
    end
end

function value = canonicalPath(value)
value = char(value);
try
    value = char(java.io.File(value).getCanonicalPath());
catch
    value = char(value);
end
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
