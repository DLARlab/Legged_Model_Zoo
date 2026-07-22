classdef WorkflowResult
    %WORKFLOWRESULT Aggregate result of a registered workflow session.
    properties (SetAccess=private)
        WorkflowId
        ModelId
        ProblemId
        DatasetId
        SeedIndex
        SolveResult
        SeedPair
        ContinuationResult
        HomotopyResult
        FamilyScanResult
        Steps
        Diagnostics
    end
    methods
        function obj=WorkflowResult(value)
            if ~isstruct(value)||~isscalar(value)
                error('lmz:Workflow:Result','Workflow result must be an object.');
            end
            names={'WorkflowId','ModelId','ProblemId','DatasetId','SeedIndex', ...
                'SolveResult','SeedPair','ContinuationResult', ...
                'HomotopyResult','FamilyScanResult','Steps','Diagnostics'};
            defaults={'','','','',NaN,[],[],[],[],[], ...
                lmz.workflow.WorkflowStep.empty(0,1),struct()};
            for index=1:numel(names)
                obj.(names{index})=fieldOr(value,names{index},defaults{index});
            end
        end
        function value=toStruct(obj)
            steps=cell(numel(obj.Steps),1);
            for index=1:numel(steps),steps{index}=obj.Steps(index).toStruct();end
            value=struct('WorkflowId',obj.WorkflowId,'ModelId',obj.ModelId, ...
                'ProblemId',obj.ProblemId,'DatasetId',obj.DatasetId, ...
                'SeedIndex',obj.SeedIndex,'Steps',{steps}, ...
                'Diagnostics',obj.Diagnostics);
            if isa(obj.SolveResult,'lmz.data.SolveResult')
                value.SolveResult=obj.SolveResult.toArtifact();
            else
                value.SolveResult=[];
            end
            if isa(obj.SeedPair,'lmz.data.SolutionPair')
                value.SeedPair=struct('First',obj.SeedPair.First.toStruct(), ...
                    'Second',obj.SeedPair.Second.toStruct(), ...
                    'RequestedRadius',obj.SeedPair.RequestedRadius, ...
                    'AchievedRadius',obj.SeedPair.AchievedRadius, ...
                    'Diagnostics',obj.SeedPair.Diagnostics);
            else
                value.SeedPair=[];
            end
            if isa(obj.ContinuationResult,'lmz.data.ContinuationResult')
                value.ContinuationResult=obj.ContinuationResult.toArtifact();
            else
                value.ContinuationResult=[];
            end
            value.HomotopyResult=homotopyStruct(obj.HomotopyResult);
            value.FamilyScanResult=familyScanStruct(obj.FamilyScanResult);
        end
    end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=homotopyStruct(source)
value=source;
if isempty(source)||~isstruct(source)||~isscalar(source),return,end
if isfield(source,'Solutions')&&isa(source.Solutions,'lmz.data.Solution')
    solutions=cell(numel(source.Solutions),1);
    for index=1:numel(solutions)
        solutions{index}=source.Solutions(index).toStruct();
    end
    value.Solutions=solutions;
end
if isfield(source,'Branch')&&isa(source.Branch,'lmz.data.SolutionBranch')
    value.Branch=source.Branch.toArtifact();
end
end
function value=familyScanStruct(source)
value=source;
if isempty(source)||~isstruct(source)||~isscalar(source)|| ...
        ~isfield(source,'Branches')||~iscell(source.Branches)
    return
end
branches=source.Branches;
for index=1:numel(branches)
    if isa(branches{index},'lmz.data.SolutionBranch')
        branches{index}=branches{index}.toArtifact();
    end
end
value.Branches=branches;
end
