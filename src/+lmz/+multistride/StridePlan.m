classdef StridePlan
    %STRIDEPLAN Authoritative, appendable plan for a requested stride count.
    properties (SetAccess=private)
        ModelId
        ProblemId
        RequestedStrideCount
        CompletedStrideCount
        InitialState
        DefaultPhysicalParameters
        StrideSpecs
        CompletionPolicy
        EnergyPolicy
        FailurePolicy
        Provenance
    end

    methods
        function obj=StridePlan(varargin)
            parser=inputParser;
            addParameter(parser,'ModelId','',@isTextScalar);
            addParameter(parser,'ProblemId','',@isTextScalar);
            addParameter(parser,'RequestedStrideCount',1,@isPositiveInteger);
            addParameter(parser,'CompletedStrideCount',[],@isOptionalCount);
            addParameter(parser,'InitialState',zeros(0,1),@isFiniteVector);
            addParameter(parser,'DefaultPhysicalParameters',struct(),@isDataValue);
            addParameter(parser,'StrideSpecs', ...
                lmz.multistride.StrideSpec.empty(0,1),@isStrideCollection);
            addParameter(parser,'CompletionPolicy','error_if_missing');
            addParameter(parser,'EnergyPolicy', ...
                lmz.multistride.EnergyConsistencyPolicy());
            addParameter(parser,'FailurePolicy','return_partial',@isFailurePolicy);
            addParameter(parser,'Provenance',struct(),@isstruct);
            parse(parser,varargin{:});values=parser.Results;
            specs=normalizeSpecs(values.StrideSpecs);
            completed=values.CompletedStrideCount;
            if isempty(completed),completed=numel(specs);end
            obj.ModelId=char(values.ModelId);obj.ProblemId=char(values.ProblemId);
            obj.RequestedStrideCount=values.RequestedStrideCount;
            obj.CompletedStrideCount=completed;
            obj.InitialState=values.InitialState(:);
            obj.DefaultPhysicalParameters=values.DefaultPhysicalParameters;
            obj.StrideSpecs=specs;
            obj.CompletionPolicy=lmz.multistride.MissingStridePolicy.from( ...
                values.CompletionPolicy);
            obj.EnergyPolicy=lmz.multistride.EnergyConsistencyPolicy.from( ...
                values.EnergyPolicy);
            obj.FailurePolicy=char(values.FailurePolicy);
            obj.Provenance=values.Provenance;
            lmz.multistride.StridePlanValidator.validate(obj);
        end

        function value=append(obj,spec)
            if ~isa(spec,'lmz.multistride.StrideSpec')||~isscalar(spec)
                error('lmz:MultiStride:AppendSpec','Append requires one StrideSpec.');
            end
            expected=obj.CompletedStrideCount+1;
            if spec.Index~=expected
                error('lmz:MultiStride:StrideIndex', ...
                    'Appended stride index must be %d.',expected);
            end
            value=obj;value.StrideSpecs(end+1,1)=spec;
            value.CompletedStrideCount=expected;
            value.RequestedStrideCount=max(value.RequestedStrideCount,expected);
            lmz.multistride.StridePlanValidator.validate(value);
        end

        function value=truncate(obj,count)
            if ~isPositiveInteger(count)||count>obj.CompletedStrideCount
                error('lmz:MultiStride:TruncateCount', ...
                    'Truncation count must select completed strides.');
            end
            value=obj;value.StrideSpecs=value.StrideSpecs(1:count);
            value.CompletedStrideCount=count;value.RequestedStrideCount=count;
            provenance=value.Provenance;
            provenance.Truncation=struct('OriginalRequested',obj.RequestedStrideCount, ...
                'OriginalCompleted',obj.CompletedStrideCount,'Retained',count);
            value.Provenance=provenance;
            lmz.multistride.StridePlanValidator.validate(value);
        end

        function value=withRequestedStrideCount(obj,count)
            if ~isPositiveInteger(count)||count<obj.CompletedStrideCount
                error('lmz:MultiStride:RequestedStrideCount', ...
                    'Requested count cannot be below completed count; truncate explicitly.');
            end
            value=obj;value.RequestedStrideCount=count;
            lmz.multistride.StridePlanValidator.validate(value);
        end

        function value=withPolicies(obj,completionPolicy,energyPolicy,failurePolicy)
            if nargin<4,failurePolicy=obj.FailurePolicy;end
            value=obj;
            value.CompletionPolicy=lmz.multistride.MissingStridePolicy.from( ...
                completionPolicy);
            value.EnergyPolicy=lmz.multistride.EnergyConsistencyPolicy.from(energyPolicy);
            if ~isFailurePolicy(failurePolicy)
                error('lmz:MultiStride:FailurePolicy','Failure policy is invalid.');
            end
            value.FailurePolicy=char(failurePolicy);
        end

        function value=clone(obj)
            value=lmz.multistride.StridePlan.fromStruct(obj.toStruct());
        end

        function value=toStruct(obj)
            specs=cell(obj.CompletedStrideCount,1);
            for index=1:obj.CompletedStrideCount
                specs{index}=obj.StrideSpecs(index).toStruct();
            end
            value=struct('ModelId',obj.ModelId,'ProblemId',obj.ProblemId, ...
                'RequestedStrideCount',obj.RequestedStrideCount, ...
                'CompletedStrideCount',obj.CompletedStrideCount, ...
                'InitialState',obj.InitialState, ...
                'DefaultPhysicalParameters',obj.DefaultPhysicalParameters, ...
                'StrideSpecs',{specs}, ...
                'CompletionPolicy',obj.CompletionPolicy.toStruct(), ...
                'EnergyPolicy',obj.EnergyPolicy.toStruct(), ...
                'FailurePolicy',obj.FailurePolicy,'Provenance',obj.Provenance);
        end

        function value=toArtifact(obj)
            value=lmz.io.ArtifactStore.workflowBase(obj.ModelId,obj.ProblemId);
            value.artifactType='stride-plan';
            value.stridePlan=obj.toStruct();
            value.diagnostics=struct( ...
                'RequestedStrideCount',obj.RequestedStrideCount, ...
                'CompletedStrideCount',obj.CompletedStrideCount, ...
                'Partial',obj.CompletedStrideCount<obj.RequestedStrideCount, ...
                'CompletionPolicy',obj.CompletionPolicy.Id, ...
                'EnergyPolicy',obj.EnergyPolicy.Id, ...
                'FailurePolicy',obj.FailurePolicy);
            value.lineage=obj.Provenance;
            ids=cell(1,2*obj.CompletedStrideCount);
            for index=1:obj.CompletedStrideCount
                ids{2*index-1}=obj.StrideSpecs(index).StartSectionId;
                ids{2*index}=obj.StrideSpecs(index).StopSectionId;
            end
            value.poincareMetadata=lmz.io.ArtifactStore.sectionMetadata( ...
                obj.ModelId,ids);
            relative=value.poincareMetadata.CatalogRelativePath;
            if ~isempty(relative)
                value.sourceDataHashes.PoincareCatalog=struct( ...
                    'relativePath',relative,'sha256', ...
                    value.poincareMetadata.CatalogHash);
            end
        end

        function value=toLegacy(obj,codec)
            if isempty(codec)||~ismethod(codec,'encode')
                error('lmz:MultiStride:LegacyCodec', ...
                    'A trusted codec object with encode is required.');
            end
            value=codec.encode(obj);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            if ~isstruct(value)||~isfield(value,'StrideSpecs')
                error('lmz:MultiStride:StridePlanStruct','Stored stride plan is invalid.');
            end
            specs=normalizeSpecs(value.StrideSpecs);
            obj=lmz.multistride.StridePlan('ModelId',value.ModelId, ...
                'ProblemId',value.ProblemId, ...
                'RequestedStrideCount',value.RequestedStrideCount, ...
                'CompletedStrideCount',value.CompletedStrideCount, ...
                'InitialState',value.InitialState, ...
                'DefaultPhysicalParameters',value.DefaultPhysicalParameters, ...
                'StrideSpecs',specs,'CompletionPolicy',value.CompletionPolicy, ...
                'EnergyPolicy',value.EnergyPolicy, ...
                'FailurePolicy',value.FailurePolicy,'Provenance',value.Provenance);
        end

        function obj=fromArtifact(artifact)
            lmz.io.ArtifactStore.validate(artifact);
            if ~strcmp(artifact.artifactType,'stride-plan')
                error('lmz:MultiStride:ArtifactType', ...
                    'Artifact is not a stride plan.');
            end
            obj=lmz.multistride.StridePlan.fromStruct(artifact.stridePlan);
        end
    end
end

function specs=normalizeSpecs(source)
if isempty(source),specs=lmz.multistride.StrideSpec.empty(0,1);return,end
if isa(source,'lmz.multistride.StrideSpec'),specs=source(:);return,end
if isstruct(source),source=num2cell(source);end
if ~iscell(source),error('lmz:MultiStride:StrideSpecs','Stride specs are invalid.');end
specs=lmz.multistride.StrideSpec.empty(0,1);
for index=1:numel(source)
    item=source{index};
    if isa(item,'lmz.multistride.StrideSpec'),specs(index,1)=item; ...
    else,specs(index,1)=lmz.multistride.StrideSpec.fromStruct(item);end
end
end
function value=isTextScalar(source)
value=ischar(source)||(isstring(source)&&isscalar(source));
end
function value=isPositiveInteger(source)
value=isnumeric(source)&&isscalar(source)&&isreal(source)&&isfinite(source)&& ...
    source>=1&&source==fix(source);
end
function value=isOptionalCount(source)
value=isempty(source)||(isnumeric(source)&&isscalar(source)&&isreal(source)&& ...
    isfinite(source)&&source>=0&&source==fix(source));
end
function value=isFiniteVector(source)
value=isnumeric(source)&&isreal(source)&&(isempty(source)||isvector(source))&& ...
    all(isfinite(source(:)));
end
function value=isDataValue(source)
value=isnumeric(source)||islogical(source)||isstruct(source)||isempty(source);
end
function value=isStrideCollection(source)
value=isempty(source)||isa(source,'lmz.multistride.StrideSpec')|| ...
    iscell(source)||isstruct(source);
end
function value=isFailurePolicy(source)
value=isTextScalar(source)&&any(strcmp(char(source),{'return_partial','error'}));
end
