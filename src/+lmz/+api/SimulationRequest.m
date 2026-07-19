classdef SimulationRequest
    %SIMULATIONREQUEST Explicit input to a model simulation.
    properties (SetAccess=private)
        ModelId
        ProblemId
        Solution
        Options
    end
    methods
        function obj = SimulationRequest(modelId, problemId, solution, options)
            if nargin < 3, solution = struct(); end
            if nargin < 4, options = struct(); end
            obj.ModelId = modelId;
            obj.ProblemId = problemId;
            obj.Solution = solution;
            obj.Options = options;
        end
    end
end
