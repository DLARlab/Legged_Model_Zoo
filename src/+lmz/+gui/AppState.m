classdef AppState < handle
    %APPSTATE Mutable presentation state, independent of UI widgets.
    properties (SetObservable)
        ModelId = ''
        ProblemId = ''
        ProblemConfiguration = struct()
        SolveMode = 'Periodic orbit'
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
        ShootingResult = []
        TimingResult = []
        SectionTransferResult = []
        SeedPair = []
        ContinuationPreview = []
        ContinuationResult = []
        OptimizationResult = []
        RequestedStrideCount = 1
        StridePlan = []
        MultiStrideResult = []
        CompletionPolicy = 'error_if_missing'
        FailurePolicy = 'return_partial'
        EnergyNeutralOnly = true
        StrideParameterOverrides = struct()
        DeclaredWork = 0
        PlanValidation = struct()
        AxisVariables = {'dx','dphi','y'}
        OscillatorIndex = 1
        CurrentRun = []
        RecordingState = struct()
        StatusMessages = {}
        Status = 'Ready'
    end
end
