classdef SceneSpec
    %SCENESPEC Immutable validated declarative 2-D scene.
    properties (SetAccess = private)
        SchemaVersion
        Frames
        Primitives
        Options
    end
    methods (Static)
        function obj = fromJson(path, root)
            if nargin < 2
                root = fileparts(path);
            end
            value = lmz.io.SafeJson.read(path, 'Root', root);
            obj = lmz.viz.SceneSpec(value);
        end
    end
    methods
        function obj = SceneSpec(value)
            value = lmz.viz.SceneValidator.validate(value);
            obj.SchemaVersion = value.schemaVersion;
            obj.Frames = value.frames;
            obj.Primitives = value.primitives;
            if isfield(value, 'options')
                if ~isstruct(value.options) || ~isscalar(value.options)
                    error('lmz:Scene:Options', ...
                        'Scene options must be a scalar object.');
                end
                obj.Options = value.options;
            else
                obj.Options = struct();
            end
        end

        function value = toStruct(obj)
            value = struct('schemaVersion', obj.SchemaVersion, ...
                'frames', {obj.Frames}, 'primitives', {obj.Primitives});
            if ~isempty(fieldnames(obj.Options))
                value.options = obj.Options;
            end
        end
    end
end
