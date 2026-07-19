classdef ContinuationOptions
    properties
        InitialStep=0.05
        MinimumStep=1e-4
        MaximumStep=0.2
        MaximumPoints=20
        CorrectorTolerance=1e-9
        MaxCorrectorIterations=100
        BothDirections=true
        DuplicateTolerance=1e-6
        LoopClosureTolerance=5e-4
        StagnationWindow=4
        MaxBacktracks=8
        GrowthFactor=1.2
        ShrinkFactor=0.5
        CurvatureThreshold=0.35
        RequireFeasible=true
        CheckpointPath=''
        PredictionFcn=[]
        AcceptedFcn=[]
        RejectedFcn=[]
        AcceptanceFcn=[]
        HistoryDecisionValues=[]
    end
    methods
        function obj=ContinuationOptions(value)
            if nargin,names=fieldnames(value);for index=1:numel(names),if isprop(obj,names{index}),obj.(names{index})=value.(names{index});end,end,end
        end
        function value=toStruct(obj)
            names=properties(obj);value=struct();
            for index=1:numel(names)
                item=obj.(names{index});if isa(item,'function_handle'),item=func2str(item);end
                value.(names{index})=item;
            end
        end
    end
end
