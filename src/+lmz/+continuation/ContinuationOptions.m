classdef ContinuationOptions
    properties, InitialStep=0.05; MinimumStep=1e-4; MaximumStep=0.2; MaximumPoints=20; CorrectorTolerance=1e-9; MaxCorrectorIterations=100; BothDirections=true; DuplicateTolerance=1e-6; CheckpointPath=''; end
    methods
        function obj=ContinuationOptions(value),if nargin,names=fieldnames(value);for index=1:numel(names),if isprop(obj,names{index}),obj.(names{index})=value.(names{index});end,end,end,end
        function value=toStruct(obj),names=properties(obj);value=struct();for index=1:numel(names),value.(names{index})=obj.(names{index});end,end
    end
end
