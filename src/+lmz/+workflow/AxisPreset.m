classdef AxisPreset
    %AXISPRESET Declarative branch-coordinate and camera defaults.
    properties (SetAccess = private)
        Id
        Label
        X
        Y
        Z
        Dimension
        Azimuth
        Elevation
        XLimits
        YLimits
        ZLimits
    end
    methods
        function obj = AxisPreset(value)
            if nargin < 1, value = struct(); end
            if ~isstruct(value) || ~isscalar(value)
                error('lmz:Workflow:AxisPreset', ...
                    'An axis preset must be a scalar object.');
            end
            obj.Id = fieldOr(value, 'id', 'default');
            obj.Label = fieldOr(value, 'label', 'Default');
            obj.X = fieldOr(value, 'x', '');
            obj.Y = fieldOr(value, 'y', '');
            obj.Z = fieldOr(value, 'z', '');
            obj.Dimension = fieldOr(value, 'dimension', '2-D');
            obj.Azimuth = fieldOr(value, 'azimuth', 0);
            obj.Elevation = fieldOr(value, 'elevation', 90);
            obj.XLimits = limitsOr(value, 'xLimits');
            obj.YLimits = limitsOr(value, 'yLimits');
            obj.ZLimits = limitsOr(value, 'zLimits');
            validateId(obj.Id);
            textValues = {obj.Label,obj.X,obj.Y,obj.Z,obj.Dimension};
            if ~all(cellfun(@ischar, textValues)) || isempty(obj.Label)
                error('lmz:Workflow:AxisPreset', ...
                    'Axis-preset labels and coordinates must be text.');
            end
            if ~all(isfinite([obj.Azimuth obj.Elevation]))
                error('lmz:Workflow:AxisPreset', ...
                    'Axis-preset camera values must be finite.');
            end
        end

        function value = coordinateNames(obj)
            value = {obj.X,obj.Y};
            if ~isempty(obj.Z), value{end + 1} = obj.Z; end
        end

        function value = toStruct(obj)
            value = struct('id',obj.Id,'label',obj.Label,'x',obj.X, ...
                'y',obj.Y,'z',obj.Z,'dimension',obj.Dimension, ...
                'azimuth',obj.Azimuth,'elevation',obj.Elevation, ...
                'xLimits',obj.XLimits,'yLimits',obj.YLimits, ...
                'zLimits',obj.ZLimits);
        end
    end
end

function value = limitsOr(source, name)
value = fieldOr(source, name, []);
if ~(isempty(value) || (isnumeric(value) && numel(value) == 2 && ...
        all(isfinite(value)) && value(1) < value(2)))
    error('lmz:Workflow:AxisLimits', ...
        'Axis limits must be empty or an increasing finite pair.');
end
value = reshape(value, 1, []);
end

function validateId(value)
if ~ischar(value) || isempty(regexp(value, '^[a-z][a-z0-9_]*$', 'once'))
    error('lmz:Workflow:AxisPresetId', ...
        'Axis-preset ID must be a lowercase identifier.');
end
end

function value = fieldOr(source, name, fallback)
if isfield(source, name), value = source.(name); else, value = fallback; end
end
