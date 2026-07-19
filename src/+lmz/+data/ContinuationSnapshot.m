classdef ContinuationSnapshot
    properties (SetAccess=private), Index; Solution; StepSize; Tangent; Accepted; Diagnostics; end
    methods
        function obj=ContinuationSnapshot(index,solution,stepSize,tangent,accepted,diagnostics)
            obj.Index=index;obj.Solution=solution;obj.StepSize=stepSize;obj.Tangent=tangent;obj.Accepted=accepted;obj.Diagnostics=diagnostics;
        end
    end
end
