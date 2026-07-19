classdef SolutionBranch
    %SOLUTIONBRANCH Schema-matrix branch; parameters are stored per point.
    properties (SetAccess=private)
        Id; ModelId; ProblemId; DecisionSchema; ParameterSchema
        DecisionValues; ParameterValues; PointMetadata; Observables
        Classifications; Arclength; Tangents; Lineage; Diagnostics; Provenance
    end
    methods
        function obj=SolutionBranch(value)
            names=properties(obj); for index=1:numel(names), obj.(names{index})=value.(names{index}); end
            obj.validate();
        end
        function value=pointCount(obj), value=size(obj.DecisionValues,2); end
        function solution=point(obj,index)
            if index<1||index>obj.pointCount(), error('lmz:Branch:PointIndex','Point index is out of range.'); end
            metadata=obj.PointMetadata(index); if iscell(metadata), metadata=metadata{1}; end
            value=struct('Id',metadata.Id,'ModelId',obj.ModelId,'ModelVersion',metadata.ModelVersion, ...
                'ProblemId',obj.ProblemId,'ProblemVersion',metadata.ProblemVersion, ...
                'DecisionSchema',obj.DecisionSchema,'ParameterSchema',obj.ParameterSchema, ...
                'DecisionValues',obj.DecisionValues(:,index),'ParameterValues',obj.ParameterValues(:,index), ...
                'Observables',struct(),'ResidualBlocks',lmz.data.ResidualBlock.empty(0,1), ...
                'Diagnostics',struct(),'Classification',struct(),'Feasibility',struct('Valid',true), ...
                'Lineage',obj.Lineage,'Provenance',obj.Provenance,'CreatedAt',metadata.CreatedAt);
            solution=lmz.data.Solution(value);
        end
        function obj=append(obj,solution,metadata)
            if nargin<3, metadata=struct(); end
            obj.assertCompatible(solution); obj.DecisionValues(:,end+1)=solution.DecisionValues; obj.ParameterValues(:,end+1)=solution.ParameterValues;
            metadata=lmz.data.SolutionBranch.completeMetadata(metadata,solution); obj.PointMetadata(end+1)=metadata;
            if isempty(obj.Arclength), obj.Arclength=0; else, d=lmz.schema.DiagonalMetric(obj.scale()).norm(solution.DecisionValues-obj.DecisionValues(:,end-1)); obj.Arclength(end+1)=obj.Arclength(end)+d; end
            obj.validate();
        end
        function obj=replacePoint(obj,index,solution)
            obj.assertCompatible(solution); obj.DecisionValues(:,index)=solution.DecisionValues; obj.ParameterValues(:,index)=solution.ParameterValues; obj.PointMetadata(index)=lmz.data.SolutionBranch.completeMetadata(struct(),solution); obj.validate();
        end
        function value=subset(obj,indices)
            data=obj.raw(); data.DecisionValues=data.DecisionValues(:,indices); data.ParameterValues=data.ParameterValues(:,indices); data.PointMetadata=data.PointMetadata(indices); data.Arclength=data.Arclength(indices); if ~isempty(data.Tangents),data.Tangents=data.Tangents(:,indices);end; value=lmz.data.SolutionBranch(data);
        end
        function value=reverse(obj), value=obj.subset(obj.pointCount():-1:1); end
        function value=decision(obj,name), value=obj.DecisionValues(obj.DecisionSchema.indexOf(name),:); end
        function value=parameter(obj,name), value=obj.ParameterValues(obj.ParameterSchema.indexOf(name),:); end
        function value=observable(obj,name), value=obj.Observables.(name); end
        function index=nearestPoint(obj,coordinates,target)
            matrix=zeros(numel(coordinates),obj.pointCount()); for k=1:numel(coordinates), matrix(k,:)=obj.decision(coordinates{k}); end
            [~,index]=min(sum((matrix-target(:)).^2,1));
        end
        function validate(obj)
            n=obj.pointCount(); if size(obj.DecisionValues,1)~=obj.DecisionSchema.count()||size(obj.ParameterValues,1)~=obj.ParameterSchema.count()||size(obj.ParameterValues,2)~=n, error('lmz:Branch:DimensionMismatch','Branch matrices do not match schemas/points.'); end
            if any(~isfinite(obj.DecisionValues(:)))||any(~isfinite(obj.ParameterValues(:)))||numel(obj.PointMetadata)~=n, error('lmz:Branch:InvalidValues','Branch values or metadata are invalid.'); end
        end
        function value=toStruct(obj), value=obj.raw(); value.DecisionSchema=obj.DecisionSchema.toStruct(); value.ParameterSchema=obj.ParameterSchema.toStruct(); end
        function artifact=toArtifact(obj)
            first=obj.point(1).toArtifact(); artifact=first; artifact.artifactType='branch'; artifact.decisionValues=obj.DecisionValues; artifact.parameterValues=obj.ParameterValues; artifact.branch=obj.toStruct();
        end
    end
    methods (Static)
        function obj=fromSolutions(solutions)
            first=solutions(1); n=numel(solutions); decision=zeros(first.DecisionSchema.count(),n); parameters=zeros(first.ParameterSchema.count(),n); metadata=repmat(struct('Id','','ModelVersion','','ProblemVersion','','CreatedAt',''),1,n);
            for index=1:n, decision(:,index)=solutions(index).DecisionValues; parameters(:,index)=solutions(index).ParameterValues; metadata(index)=lmz.data.SolutionBranch.completeMetadata(struct(),solutions(index)); end
            data=struct('Id',lmz.util.Ids.new('branch'),'ModelId',first.ModelId,'ProblemId',first.ProblemId, ...
                'DecisionSchema',first.DecisionSchema,'ParameterSchema',first.ParameterSchema,'DecisionValues',decision,'ParameterValues',parameters, ...
                'PointMetadata',metadata,'Observables',struct(),'Classifications',{{}},'Arclength',zeros(1,n),'Tangents',[], ...
                'Lineage',struct(),'Diagnostics',struct(),'Provenance',struct('source','native'));
            metric=lmz.schema.DiagonalMetric(arrayfun(@(s)s.Scale,first.DecisionSchema.Specs(:))); for index=2:n,data.Arclength(index)=data.Arclength(index-1)+metric.norm(decision(:,index)-decision(:,index-1));end
            obj=lmz.data.SolutionBranch(data);
        end
        function obj=fromStruct(value)
            value.DecisionSchema=lmz.schema.VariableSchema.fromStruct(value.DecisionSchema); value.ParameterSchema=lmz.schema.VariableSchema.fromStruct(value.ParameterSchema); obj=lmz.data.SolutionBranch(value);
        end
        function obj=fromArtifact(artifact), obj=lmz.data.SolutionBranch.fromStruct(artifact.branch); end
    end
    methods (Access=private)
        function assertCompatible(obj,solution)
            if ~strcmp(solution.ModelId,obj.ModelId)||~strcmp(solution.ProblemId,obj.ProblemId)||~isequal(solution.DecisionSchema.names(),obj.DecisionSchema.names()), error('lmz:Branch:IncompatibleSolution','Solution is incompatible with branch.'); end
        end
        function value=scale(obj), value=arrayfun(@(s)s.Scale,obj.DecisionSchema.Specs(:)); end
        function value=raw(obj), value=struct(); names=properties(obj); for index=1:numel(names),value.(names{index})=obj.(names{index});end, end
    end
    methods (Static,Access=private)
        function metadata=completeMetadata(metadata,solution)
            metadata.Id=solution.Id; metadata.ModelVersion=solution.ModelVersion; metadata.ProblemVersion=solution.ProblemVersion; metadata.CreatedAt=solution.CreatedAt;
        end
    end
end
