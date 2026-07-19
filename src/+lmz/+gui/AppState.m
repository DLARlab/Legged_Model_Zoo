classdef AppState < handle
    %APPSTATE Mutable presentation state, independent of UI widgets.
    properties
        ModelId = ''
        ProblemId = ''
        ExampleId = 'default_stride'
        Simulation = []
        Datasets = {}
        ActiveDatasetId = ''
        Selection = []
        WorkingSolution = []
        SolveResult = []
        SeedPair = []
        ContinuationResult = []
        OptimizationResult = []
        CurrentRun = []
        StatusMessages = {}
        Status = 'Ready'
    end
end
