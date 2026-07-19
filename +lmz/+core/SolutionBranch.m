classdef SolutionBranch < handle
    properties, Id char=''; ModelId char=''; ProblemId char=''; Points struct=struct([]); Attempts struct=struct([]); Metadata struct=struct(); Provenance struct=struct(); end
    methods
        function addPoint(obj,p),if isempty(obj.Points),obj.Points=p;else,obj.Points(end+1)=p;end,end
        function s=toStruct(obj),s=struct('schema_version','1.0','id',obj.Id,'model_id',obj.ModelId,'problem_id',obj.ProblemId,'points',obj.Points,'attempts',obj.Attempts,'metadata',obj.Metadata,'provenance',obj.Provenance);end
    end
end
