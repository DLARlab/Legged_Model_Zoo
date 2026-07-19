classdef ContinuationOptions
    properties, InitialStep=0.05; MinimumStep=1e-5; MaximumStep=0.25; GrowthFactor=1.25; ShrinkFactor=0.5; MaxPoints=100; MaxRetries=6; FunctionTolerance=1e-8; CorrectorMaxIterations=100; Direction=1; ParameterIndex=[]; LoopTolerance=1e-4; ProgressCallback=[]; CancellationCallback=[]; end
end
