classdef Selection
    properties (SetAccess=private), DatasetId; PointIndex; SolutionId; Source; end
    methods
        function obj=Selection(datasetId,pointIndex,solutionId,source)
            obj.DatasetId=datasetId; obj.PointIndex=pointIndex; obj.SolutionId=solutionId; obj.Source=source;
        end
    end
end
