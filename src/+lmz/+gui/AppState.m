classdef AppState < handle
    %APPSTATE Mutable presentation state, independent of UI widgets.
    properties
        ModelId = ''
        ProblemId = ''
        ExampleId = 'default_stride'
        RoadMapCatalog = []
        Simulation = []
        CandidateSimulation = []
        Datasets = {}
        ActiveDatasetId = ''
        HoverSelection = []
        LockedSelection = []
        Selection = [] % Round 4 compatibility alias for LockedSelection.
        WorkingSolution = []
        WorkingEvaluation = []
        SolvedSolution = []
        SolveResult = []
        SeedPair = []
        ContinuationPreview = []
        ContinuationResult = []
        OptimizationResult = []
        AxisVariables = {'dx','dphi','y'}
        OscillatorIndex = 1
        CurrentRun = []
        RecordingState = struct()
        StatusMessages = {}
        Status = 'Ready'
    end
end
