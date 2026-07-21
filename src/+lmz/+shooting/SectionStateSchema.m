classdef SectionStateSchema
    %SECTIONSTATESCHEMA Named projection between full and section state.
    properties (SetAccess=private)
        PhysicalSchema
        CoordinateNames
        CoordinateIndices
    end

    methods
        function obj=SectionStateSchema(physicalSchema,coordinateNames)
            if ~isa(physicalSchema,'lmz.schema.VariableSchema')
                error('lmz:Shooting:PhysicalStateSchema', ...
                    'SectionStateSchema requires a VariableSchema.');
            end
            if ischar(coordinateNames),coordinateNames={coordinateNames};end
            if ~iscell(coordinateNames)||isempty(coordinateNames)|| ...
                    ~all(cellfun(@ischar,coordinateNames))
                error('lmz:Shooting:CoordinateNames', ...
                    'Section coordinate names must be a nonempty cell array.');
            end
            indices=zeros(numel(coordinateNames),1);
            for index=1:numel(coordinateNames)
                indices(index)=physicalSchema.indexOf(coordinateNames{index});
            end
            if numel(unique(indices))~=numel(indices)
                error('lmz:Shooting:DuplicateCoordinate', ...
                    'Section coordinate names must be unique.');
            end
            obj.PhysicalSchema=physicalSchema;
            obj.CoordinateNames=reshape(coordinateNames,[],1);
            obj.CoordinateIndices=indices;
        end

        function value=count(obj),value=numel(obj.CoordinateIndices);end

        function value=extract(obj,state)
            obj.PhysicalSchema.validateVector(state);
            value=state(obj.CoordinateIndices);
        end

        function value=embed(obj,baseState,coordinates)
            obj.PhysicalSchema.validateVector(baseState);
            if ~isnumeric(coordinates)||numel(coordinates)~=obj.count()|| ...
                    any(~isfinite(coordinates(:)))
                error('lmz:Shooting:SectionCoordinates', ...
                    'Section coordinates have the wrong size or are nonfinite.');
            end
            value=baseState(:);value(obj.CoordinateIndices)=coordinates(:);
            obj.PhysicalSchema.validateVector(value);
        end

        function value=scales(obj)
            specs=obj.PhysicalSchema.Specs(obj.CoordinateIndices);
            value=arrayfun(@(item)item.Scale,specs(:));
        end

        function value=coordinateSchema(obj)
            value=lmz.schema.VariableSchema( ...
                obj.PhysicalSchema.Specs(obj.CoordinateIndices), ...
                obj.PhysicalSchema.Version);
        end

        function value=toStruct(obj)
            value=struct('PhysicalSchema',obj.PhysicalSchema.toStruct(), ...
                'CoordinateNames',{obj.CoordinateNames});
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            if ~isstruct(value)||~isfield(value,'PhysicalSchema')|| ...
                    ~isfield(value,'CoordinateNames')
                error('lmz:Shooting:SectionStateSchemaStruct', ...
                    'Stored section-state schema is incomplete.');
            end
            obj=lmz.shooting.SectionStateSchema( ...
                lmz.schema.VariableSchema.fromStruct(value.PhysicalSchema), ...
                value.CoordinateNames);
        end
    end
end
