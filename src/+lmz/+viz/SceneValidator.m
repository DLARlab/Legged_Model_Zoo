classdef SceneValidator
    %SCENEVALIDATOR Validate declarative 2-D scenes without evaluating text.
    properties (Constant, Access = private)
        MaximumPrimitives = 512
        MaximumFrames = 256
        MaximumTextLength = 2048
    end
    methods (Static)
        function value = validate(value)
            if ~isstruct(value) || ~isscalar(value)
                error('lmz:Scene:Type', 'Scene JSON must contain one object.');
            end
            required = {'schemaVersion','frames','primitives'};
            for index = 1:numel(required)
                if ~isfield(value, required{index})
                    error('lmz:Scene:MissingField', ...
                        'Scene is missing %s.', required{index});
                end
            end
            if ~strcmp(value.schemaVersion, '1.0.0')
                error('lmz:Scene:SchemaVersion', ...
                    'Unsupported scene schema version: %s', value.schemaVersion);
            end
            frames = lmz.viz.SceneValidator.textList(value.frames, 'frames');
            if isempty(frames) || numel(frames) > ...
                    lmz.viz.SceneValidator.MaximumFrames || ...
                    numel(unique(frames)) ~= numel(frames)
                error('lmz:Scene:Frames', ...
                    'Scene frames must be a bounded unique list.');
            end
            for index = 1:numel(frames)
                lmz.viz.SceneValidator.identifier(frames{index}, 'frame');
            end
            primitives = lmz.viz.SceneValidator.primitiveCells(value.primitives);
            if numel(primitives) > lmz.viz.SceneValidator.MaximumPrimitives
                error('lmz:Scene:PrimitiveLimit', ...
                    'Scene exceeds the primitive-count limit.');
            end
            for index = 1:numel(primitives)
                primitives{index} = lmz.viz.SceneValidator.primitive( ...
                    primitives{index}, frames, index);
            end
            value.frames = frames;
            value.primitives = primitives;
        end
    end

    methods (Static, Access = private)
        function primitive = primitive(primitive, frames, index)
            if ~isstruct(primitive) || ~isscalar(primitive) || ...
                    ~isfield(primitive, 'type') || ~ischar(primitive.type)
                error('lmz:Scene:Primitive', ...
                    'Primitive %d must be an object with a text type.', index);
            end
            aliases = struct('point_mass','marker','body','polygon', ...
                'point','marker','line','line','link','line');
            if isfield(aliases, primitive.type)
                primitive.type = aliases.(primitive.type);
            end
            allowed = {'ground','polygon','marker','line','spring','rope', ...
                'force_vector','trail','text'};
            if ~any(strcmp(primitive.type, allowed))
                error('lmz:Scene:PrimitiveType', ...
                    'Unsupported scene primitive: %s', primitive.type);
            end
            common = {'type','frame','from','to','vector','vertices','color', ...
                'lineWidth','marker','markerSize','text','offset','scale', ...
                'y','xRange','style'};
            names = fieldnames(primitive);
            if ~all(ismember(names, common))
                error('lmz:Scene:PrimitiveField', ...
                    'Primitive %d contains an unknown field.', index);
            end
            referenceFields = {'frame','from','to'};
            for fieldIndex = 1:numel(referenceFields)
                name = referenceFields{fieldIndex};
                if isfield(primitive, name)
                    lmz.viz.SceneValidator.identifier(primitive.(name), name);
                    if ~any(strcmp(primitive.(name), frames))
                        error('lmz:Scene:UnknownFrame', ...
                            'Primitive %d references unknown frame %s.', ...
                            index, primitive.(name));
                    end
                end
            end
            if isfield(primitive, 'vector')
                lmz.viz.SceneValidator.identifier(primitive.vector, 'vector');
            end
            switch primitive.type
                case {'polygon','marker','trail','text'}
                    lmz.viz.SceneValidator.require(primitive, 'frame', index);
                case {'line','spring','rope'}
                    lmz.viz.SceneValidator.require(primitive, 'from', index);
                    lmz.viz.SceneValidator.require(primitive, 'to', index);
                case 'force_vector'
                    lmz.viz.SceneValidator.require(primitive, 'frame', index);
                    lmz.viz.SceneValidator.require(primitive, 'vector', index);
            end
            if isfield(primitive, 'vertices') && ...
                    (~isnumeric(primitive.vertices) || ...
                    size(primitive.vertices, 2) ~= 2 || ...
                    any(~isfinite(primitive.vertices(:))) || ...
                    size(primitive.vertices, 1) > 256)
                error('lmz:Scene:Vertices', ...
                    'Polygon vertices must be a bounded finite N-by-2 array.');
            end
            numericFields = {'color','lineWidth','markerSize','offset', ...
                'scale','y','xRange'};
            for fieldIndex = 1:numel(numericFields)
                name = numericFields{fieldIndex};
                if isfield(primitive, name) && ...
                        (~isnumeric(primitive.(name)) || ...
                        ~isreal(primitive.(name)) || ...
                        any(~isfinite(primitive.(name)(:))))
                    error('lmz:Scene:NumericStyle', ...
                        'Primitive numeric field %s is invalid.', name);
                end
            end
            lmz.viz.SceneValidator.validateNumericStyles(primitive);
            if isfield(primitive, 'text') && ...
                    (~ischar(primitive.text) || numel(primitive.text) > ...
                    lmz.viz.SceneValidator.MaximumTextLength)
                error('lmz:Scene:Text', 'Scene text is invalid or too long.');
            end
        end

        function cells = primitiveCells(value)
            if isempty(value)
                cells = {};
            elseif iscell(value)
                cells = value(:).';
            elseif isstruct(value)
                cells = num2cell(value(:).');
            else
                error('lmz:Scene:Primitives', ...
                    'Scene primitives must be an object array.');
            end
        end

        function values = textList(value, description)
            if ischar(value)
                values = {value};
            elseif iscell(value) && all(cellfun(@ischar, value))
                values = value(:).';
            else
                error('lmz:Scene:TextList', ...
                    '%s must be a text list.', description);
            end
        end

        function identifier(value, description)
            if ~ischar(value) || isempty(regexp(value, ...
                    '^[A-Za-z][A-Za-z0-9_]*$', 'once'))
                error('lmz:Scene:Binding', ...
                    '%s must be a simple identifier, never an expression.', ...
                    description);
            end
        end

        function require(value, field, index)
            if ~isfield(value, field)
                error('lmz:Scene:PrimitiveField', ...
                    'Primitive %d requires field %s.', index, field);
            end
        end

        function validateNumericStyles(primitive)
            if isfield(primitive, 'color') && ...
                    (numel(primitive.color) ~= 3 || ...
                    any(primitive.color(:) < 0) || ...
                    any(primitive.color(:) > 1))
                error('lmz:Scene:NumericStyle', ...
                    'Primitive color must be an RGB triplet in [0,1].');
            end
            positiveScalars = {'lineWidth','markerSize'};
            for index = 1:numel(positiveScalars)
                name = positiveScalars{index};
                if isfield(primitive, name) && ...
                        (~isscalar(primitive.(name)) || primitive.(name) <= 0)
                    error('lmz:Scene:NumericStyle', ...
                        'Primitive field %s must be a positive scalar.', name);
                end
            end
            scalarFields = {'scale','y'};
            for index = 1:numel(scalarFields)
                name = scalarFields{index};
                if isfield(primitive, name) && ~isscalar(primitive.(name))
                    error('lmz:Scene:NumericStyle', ...
                        'Primitive field %s must be scalar.', name);
                end
            end
            if isfield(primitive, 'offset') && numel(primitive.offset) ~= 2
                error('lmz:Scene:NumericStyle', ...
                    'Primitive text offset must contain two values.');
            end
            if isfield(primitive, 'xRange') && ...
                    (numel(primitive.xRange) ~= 2 || ...
                    primitive.xRange(2) <= primitive.xRange(1))
                error('lmz:Scene:NumericStyle', ...
                    'Primitive xRange must contain two increasing values.');
            end
        end
    end
end
