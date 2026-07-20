classdef KinematicsFrame
    %KINEMATICSFRAME Finite named 2-D geometry for one simulation frame.
    properties (SetAccess = private)
        Time
        Index
        Frames
        Vectors
        Scalars
        Text
    end
    methods
        function obj = KinematicsFrame(time, index, frames, varargin)
            parser = inputParser;
            addRequired(parser, 'time', @(x) isnumeric(x) && isscalar(x) && isfinite(x));
            addRequired(parser, 'index', @(x) isnumeric(x) && isscalar(x) && x >= 1 && x == fix(x));
            addRequired(parser, 'frames', @(x) isstruct(x) && isscalar(x));
            addParameter(parser, 'Vectors', struct(), @(x) isstruct(x) && isscalar(x));
            addParameter(parser, 'Scalars', struct(), @(x) isstruct(x) && isscalar(x));
            addParameter(parser, 'Text', struct(), @(x) isstruct(x) && isscalar(x));
            parse(parser, time, index, frames, varargin{:});
            lmz.viz.KinematicsFrame.validateNumericMap(frames, [2 3], 'frame');
            lmz.viz.KinematicsFrame.validateNumericMap(parser.Results.Vectors, 2, 'vector');
            scalarNames = fieldnames(parser.Results.Scalars);
            for k = 1:numel(scalarNames)
                item = parser.Results.Scalars.(scalarNames{k});
                if ~isnumeric(item) || ~isscalar(item) || ~isfinite(item)
                    error('lmz:Scene:Scalar', 'Kinematics scalars must be finite.');
                end
            end
            textNames = fieldnames(parser.Results.Text);
            for k = 1:numel(textNames)
                if ~ischar(parser.Results.Text.(textNames{k}))
                    error('lmz:Scene:FrameText', 'Kinematics text must be character data.');
                end
            end
            obj.Time = time;
            obj.Index = index;
            obj.Frames = frames;
            obj.Vectors = parser.Results.Vectors;
            obj.Scalars = parser.Results.Scalars;
            obj.Text = parser.Results.Text;
        end

        function value = position(obj, name)
            if ~isfield(obj.Frames, name)
                error('lmz:Scene:FrameMissing', 'Missing kinematics frame %s.', name);
            end
            item = obj.Frames.(name);
            value = reshape(item(1:2), 1, 2);
        end

        function value = angle(obj, name)
            item = obj.Frames.(name);
            if numel(item) >= 3
                value = item(3);
            else
                value = 0;
            end
        end

        function value = vector(obj, name)
            if ~isfield(obj.Vectors, name)
                error('lmz:Scene:VectorMissing', ...
                    'Missing kinematics vector %s.', name);
            end
            value = reshape(obj.Vectors.(name), 1, 2);
        end
    end

    methods (Static, Access = private)
        function validateNumericMap(value, lengths, description)
            names = fieldnames(value);
            for index = 1:numel(names)
                item = value.(names{index});
                if ~isnumeric(item) || ~isreal(item) || ...
                        ~any(numel(item) == lengths) || any(~isfinite(item(:)))
                    error('lmz:Scene:FrameValue', ...
                        'Kinematics %s %s is invalid.', description, names{index});
                end
            end
        end
    end
end
