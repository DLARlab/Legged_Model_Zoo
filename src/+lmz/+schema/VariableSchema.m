classdef VariableSchema
    %VARIABLESCHEMA Ordered collection of uniquely named variable specs.
    properties (SetAccess=private)
        Specs
        Version
    end

    methods
        function obj = VariableSchema(specs, version)
            if nargin < 1
                specs = lmz.schema.VariableSpec.empty(0, 1);
            end
            if nargin < 2
                version = '1.0.0';
            end
            if ~all(arrayfun(@(value) isa(value, ...
                    'lmz.schema.VariableSpec'), specs))
                error('lmz:Schema:InvalidSpecs', ...
                    'Specs must contain VariableSpec values.');
            end
            if isempty(regexp(version, '^\d+\.\d+\.\d+$', 'once'))
                error('lmz:Schema:InvalidVersion', ...
                    'Schema version must be semantic.');
            end
            names = arrayfun(@(value) value.Name, specs, ...
                'UniformOutput', false);
            if numel(unique(names)) ~= numel(names)
                error('lmz:Schema:DuplicateVariable', ...
                    'Variable names must be unique.');
            end

            obj.Specs = specs(:);
            obj.Version = version;
            for index = 1:numel(obj.Specs)
                spec = obj.Specs(index);
                if strcmp(spec.Topology, 'cyclic_time') && ...
                        ~any(strcmp(spec.PeriodSource, names))
                    error('lmz:Schema:UnresolvedPeriod', ...
                        'Period source %s is absent.', spec.PeriodSource);
                end
            end
        end

        function value = count(obj)
            value = numel(obj.Specs);
        end

        function value = names(obj)
            value = arrayfun(@(spec) spec.Name, obj.Specs, ...
                'UniformOutput', false);
        end

        function index = indexOf(obj, name)
            index = find(strcmp(name, obj.names()), 1);
            if isempty(index)
                error('lmz:Schema:UnknownVariable', ...
                    'Unknown variable: %s', name);
            end
        end

        function schema = selectGroup(obj, group)
            selected = arrayfun(@(spec) strcmp(spec.Group, group), obj.Specs);
            schema = lmz.schema.VariableSchema(obj.Specs(selected), obj.Version);
        end

        function value = defaults(obj)
            value = arrayfun(@(spec) spec.DefaultValue, obj.Specs(:));
        end

        function values = unpack(obj, vector)
            obj.validateVector(vector);
            values = struct();
            for index = 1:obj.count()
                values.(obj.Specs(index).Name) = vector(index);
            end
        end

        function vector = pack(obj, values)
            vector = zeros(obj.count(), 1);
            for index = 1:obj.count()
                name = obj.Specs(index).Name;
                if ~isfield(values, name)
                    error('lmz:Schema:MissingPackedValue', ...
                        'Missing value for %s.', name);
                end
                vector(index) = values.(name);
            end
            obj.validateVector(vector);
        end

        function validateVector(obj, vector)
            if ~isnumeric(vector) || numel(vector) ~= obj.count() || ...
                    any(~isfinite(vector(:)))
                error('lmz:Schema:InvalidVector', ...
                    'Vector has the wrong size or contains nonfinite values.');
            end
            vector = vector(:);
            for index = 1:obj.count()
                spec = obj.Specs(index);
                if vector(index) < spec.LowerBound || ...
                        vector(index) > spec.UpperBound
                    error('lmz:Schema:OutOfBounds', ...
                        '%s is outside its bounds.', spec.Name);
                end
            end
            obj.resolvePeriods(vector);
        end

        function periods = resolvePeriods(obj, vector)
            if ~isnumeric(vector) || numel(vector) ~= obj.count()
                error('lmz:Schema:InvalidVector', ...
                    'Cannot resolve periods from a vector of the wrong size.');
            end
            vector = vector(:);
            periods = nan(obj.count(), 1);
            for index = 1:obj.count()
                spec = obj.Specs(index);
                if strcmp(spec.Topology, 'angle')
                    if isfinite(spec.LowerBound) && isfinite(spec.UpperBound)
                        periods(index) = spec.UpperBound - spec.LowerBound;
                    else
                        periods(index) = 2 * pi;
                    end
                elseif strcmp(spec.Topology, 'cyclic_time')
                    periodIndex = obj.indexOf(spec.PeriodSource);
                    periods(index) = vector(periodIndex);
                    if ~isfinite(periods(index)) || periods(index) <= 0
                        error('lmz:Schema:InvalidPeriod', ...
                            'Period for %s must be positive and finite.', ...
                            spec.Name);
                    end
                end
            end
        end

        function value = metadataTable(obj)
            value = struct2table(cell2mat(arrayfun( ...
                @(spec) spec.toStruct(), obj.Specs, 'UniformOutput', false)));
        end

        function value = toStruct(obj)
            variables = cell(obj.count(), 1);
            for index = 1:obj.count()
                variables{index} = obj.Specs(index).toStruct();
            end
            value = struct('version', obj.Version, ...
                'orderedNames', {obj.names()}, 'variables', {variables});
        end
    end

    methods (Static)
        function obj = fromStruct(value)
            specs = lmz.schema.VariableSpec.empty(0, 1);
            for index = 1:numel(value.variables)
                specs(index, 1) = lmz.schema.VariableSpec.fromStruct( ...
                    value.variables{index}); %#ok<AGROW>
            end
            obj = lmz.schema.VariableSchema(specs, value.version);
            if ~isequal(obj.names(), value.orderedNames)
                error('lmz:Schema:OrderMismatch', ...
                    'Stored orderedNames do not match variable order.');
            end
        end
    end
end
