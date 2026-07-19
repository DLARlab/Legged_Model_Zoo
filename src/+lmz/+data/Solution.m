classdef Solution
    %SOLUTION Validated immutable-style numerical solution value.
    properties (SetAccess=private)
        Id; ModelId; ModelVersion; ProblemId; ProblemVersion
        DecisionSchema; ParameterSchema; DecisionValues; ParameterValues
        Observables; ResidualBlocks; Diagnostics; Classification; Feasibility
        Lineage; Provenance; CreatedAt
    end
    methods
        function obj=Solution(value)
            required=properties(obj);
            for index=1:numel(required)
                if ~isfield(value,required{index}), error('lmz:Solution:MissingField','Missing solution field %s.',required{index}); end
                obj.(required{index})=value.(required{index});
            end
            obj.validate();
        end
        function validate(obj)
            if ~isa(obj.DecisionSchema,'lmz.schema.VariableSchema')||~isa(obj.ParameterSchema,'lmz.schema.VariableSchema'), error('lmz:Solution:InvalidSchema','Solution schemas are invalid.'); end
            obj.DecisionSchema.validateVector(obj.DecisionValues);
            obj.ParameterSchema.validateVector(obj.ParameterValues);
            textFields={'Id','ModelId','ModelVersion','ProblemId','ProblemVersion','CreatedAt'};
            for index=1:numel(textFields), if ~ischar(obj.(textFields{index}))||isempty(obj.(textFields{index})), error('lmz:Solution:InvalidIdentity','Solution identity is invalid.'); end, end
        end
        function value=decision(obj,name), value=obj.DecisionValues(obj.DecisionSchema.indexOf(name)); end
        function value=parameter(obj,name), value=obj.ParameterValues(obj.ParameterSchema.indexOf(name)); end
        function value=withDecisionValues(obj,values)
            data=obj.toStruct(); data.DecisionSchema=obj.DecisionSchema; data.ParameterSchema=obj.ParameterSchema; data.ResidualBlocks=obj.ResidualBlocks; data.DecisionValues=values(:); data.Id=lmz.util.Ids.new('solution'); value=lmz.data.Solution(data);
        end
        function value=withParameterValues(obj,values)
            data=obj.toStruct(); data.DecisionSchema=obj.DecisionSchema; data.ParameterSchema=obj.ParameterSchema; data.ResidualBlocks=obj.ResidualBlocks; data.ParameterValues=values(:); data.Id=lmz.util.Ids.new('solution'); value=lmz.data.Solution(data);
        end
        function value=toStruct(obj)
            value=struct(); names=properties(obj);
            for index=1:numel(names), value.(names{index})=obj.(names{index}); end
            value.DecisionSchema=obj.DecisionSchema.toStruct(); value.ParameterSchema=obj.ParameterSchema.toStruct();
            blocks=cell(numel(obj.ResidualBlocks),1); for index=1:numel(blocks), blocks{index}=obj.ResidualBlocks(index).toStruct(); end
            value.ResidualBlocks=blocks;
        end
        function artifact=toArtifact(obj)
            artifact=struct('schemaVersion','1.0.0','artifactType','solution', ...
                'modelId',obj.ModelId,'modelVersion',obj.ModelVersion,'problemId',obj.ProblemId, ...
                'problemVersion',obj.ProblemVersion,'decisionSchema',obj.DecisionSchema.toStruct(), ...
                'parameterSchema',obj.ParameterSchema.toStruct(),'decisionValues',obj.DecisionValues, ...
                'parameterValues',obj.ParameterValues,'diagnostics',obj.Diagnostics,'lineage',obj.Lineage, ...
                'randomSeed',0,'sourceCommitSHAs',struct(),'createdAt',obj.CreatedAt, ...
                'matlabVersion',version,'codeVersion','round4','solution',obj.toStruct());
        end
    end
    methods (Static)
        function obj=fromStruct(value)
            if isstruct(value.DecisionSchema), value.DecisionSchema=lmz.schema.VariableSchema.fromStruct(value.DecisionSchema); end
            if isstruct(value.ParameterSchema), value.ParameterSchema=lmz.schema.VariableSchema.fromStruct(value.ParameterSchema); end
            if iscell(value.ResidualBlocks)
                blocks=lmz.data.ResidualBlock.empty(0,1);
                for index=1:numel(value.ResidualBlocks), s=value.ResidualBlocks{index}; blocks(index,1)=lmz.data.ResidualBlock(s.Name,s.Values,s.Scale); end
                value.ResidualBlocks=blocks;
            end
            obj=lmz.data.Solution(value);
        end
        function obj=fromArtifact(artifact), obj=lmz.data.Solution.fromStruct(artifact.solution); end
    end
end
