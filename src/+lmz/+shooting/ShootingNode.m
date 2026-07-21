classdef ShootingNode
    %SHOOTINGNODE One section-interface state and its numerical mask.
    properties (SetAccess=private)
        SectionId
        SectionHash
        StateSide
        StateSchema
        FullState
        SectionCoordinates
        WorldTranslation
        FreeCoordinateMask
        Symmetry
        Lineage
    end

    methods
        function obj=ShootingNode(varargin)
            parser=inputParser;
            addParameter(parser,'SectionId','apex',@isIdentifier);
            addParameter(parser,'SectionHash','',@ischar);
            addParameter(parser,'StateSide','post',@isStateSide);
            addParameter(parser,'StateSchema',[], ...
                @(value)isa(value,'lmz.shooting.SectionStateSchema'));
            addParameter(parser,'FullState',[],@isFiniteVector);
            addParameter(parser,'SectionCoordinates',[],@isFiniteVector);
            addParameter(parser,'WorldTranslation',0,@isFiniteVector);
            addParameter(parser,'FreeCoordinateMask',[],@isLogicalVector);
            addParameter(parser,'Symmetry',struct(),@isSymmetry);
            addParameter(parser,'Lineage',struct(),@isstruct);
            parse(parser,varargin{:});value=parser.Results;
            if isempty(value.StateSchema)
                error('lmz:Shooting:NodeStateSchema', ...
                    'A shooting node requires a SectionStateSchema.');
            end
            full=value.FullState(:);
            value.StateSchema.PhysicalSchema.validateVector(full);
            coordinates=value.SectionCoordinates(:);
            if isempty(coordinates)
                coordinates=value.StateSchema.extract(full);
            elseif numel(coordinates)~=value.StateSchema.count()
                error('lmz:Shooting:NodeCoordinates', ...
                    'Node section-coordinate count is invalid.');
            end
            mask=value.FreeCoordinateMask(:);
            if isempty(mask),mask=true(value.StateSchema.count(),1);end
            if numel(mask)~=value.StateSchema.count()
                error('lmz:Shooting:NodeMask', ...
                    'Node coordinate mask has the wrong length.');
            end
            if ~isempty(value.SectionHash)&& ...
                    isempty(regexp(value.SectionHash,'^[0-9a-f]{64}$','once'))
                error('lmz:Shooting:SectionHash', ...
                    'SectionHash must be empty or a lowercase SHA-256 value.');
            end
            obj.SectionId=char(value.SectionId);
            obj.SectionHash=value.SectionHash;
            obj.StateSide=char(value.StateSide);
            obj.StateSchema=value.StateSchema;
            obj.FullState=full;
            obj.SectionCoordinates=coordinates;
            obj.WorldTranslation=value.WorldTranslation(:);
            obj.FreeCoordinateMask=logical(mask);
            obj.Symmetry=value.Symmetry;
            obj.Lineage=value.Lineage;
        end

        function value=withCoordinates(obj,coordinates)
            state=obj.StateSchema.embed(obj.FullState,coordinates);
            value=obj;value.FullState=state;
            value.SectionCoordinates=coordinates(:);
        end

        function value=toStruct(obj)
            symmetry=obj.Symmetry;
            if isobject(symmetry)&&ismethod(symmetry,'toStruct')
                symmetry=symmetry.toStruct();
            end
            value=struct('SectionId',obj.SectionId, ...
                'SectionHash',obj.SectionHash,'StateSide',obj.StateSide, ...
                'StateSchema',obj.StateSchema.toStruct(), ...
                'FullState',obj.FullState, ...
                'SectionCoordinates',obj.SectionCoordinates, ...
                'WorldTranslation',obj.WorldTranslation, ...
                'FreeCoordinateMask',obj.FreeCoordinateMask, ...
                'Symmetry',symmetry,'Lineage',obj.Lineage);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            required={'SectionId','SectionHash','StateSide','StateSchema', ...
                'FullState','SectionCoordinates','WorldTranslation', ...
                'FreeCoordinateMask','Symmetry','Lineage'};
            if ~isstruct(value)||~all(isfield(value,required))
                error('lmz:Shooting:NodeStruct', ...
                    'Stored shooting node is incomplete.');
            end
            obj=lmz.shooting.ShootingNode('SectionId',value.SectionId, ...
                'SectionHash',value.SectionHash,'StateSide',value.StateSide, ...
                'StateSchema',lmz.shooting.SectionStateSchema.fromStruct( ...
                value.StateSchema),'FullState',value.FullState, ...
                'SectionCoordinates',value.SectionCoordinates, ...
                'WorldTranslation',value.WorldTranslation, ...
                'FreeCoordinateMask',value.FreeCoordinateMask, ...
                'Symmetry',value.Symmetry,'Lineage',value.Lineage);
        end
    end
end

function value=isIdentifier(source)
value=(ischar(source)||(isstring(source)&&isscalar(source)))&& ...
    ~isempty(regexp(char(source),'^[A-Za-z][A-Za-z0-9_]*$','once'));
end
function value=isStateSide(source)
value=(ischar(source)||(isstring(source)&&isscalar(source)))&& ...
    any(strcmp(char(source),{'pre','post'}));
end
function value=isFiniteVector(source)
value=isnumeric(source)&&isreal(source)&&(isempty(source)||isvector(source))&& ...
    all(isfinite(source(:)));
end
function value=isLogicalVector(source)
value=isempty(source)||(islogical(source)&&isvector(source));
end
function value=isSymmetry(source)
value=isstruct(source)||isobject(source);
end
