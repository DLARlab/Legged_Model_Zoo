classdef ContinuationSnapshot
    properties (SetAccess=private), Index; Solution; StepSize; Tangent; Accepted; Diagnostics; end
    methods
        function obj=ContinuationSnapshot(index,solution,stepSize,tangent,accepted,diagnostics)
            diagnostics=lmz.data.ContinuationSnapshot.normalizeDiagnostics(diagnostics);
            diagnostics.Step=stepSize;
            obj.Index=index;obj.Solution=solution;obj.StepSize=stepSize;obj.Tangent=tangent;obj.Accepted=accepted;obj.Diagnostics=diagnostics;
        end
        function value=toStruct(obj)
            solution=[];
            if isa(obj.Solution,'lmz.data.Solution')
                solution=obj.Solution.toStruct();
            end
            value=struct('Index',obj.Index,'Solution',solution, ...
                'StepSize',obj.StepSize,'Tangent',obj.Tangent, ...
                'Accepted',obj.Accepted,'Diagnostics',obj.Diagnostics);
        end
    end
    methods (Static, Access=private)
        function value=normalizeDiagnostics(value)
            if nargin<1||isempty(value),value=struct();end
            if isfield(value,'Prediction')&&~isfield(value,'Predictor')
                value.Predictor=value.Prediction;
            end
            if isfield(value,'Output')&&~isfield(value,'CorrectorOutput')
                value.CorrectorOutput=value.Output;
            end
            if isfield(value,'Backtrack')&&~isfield(value,'BacktrackingCount')
                value.BacktrackingCount=value.Backtrack;
            end
            defaults=struct('Predictor',[],'CorrectedDecision',[], ...
                'ResidualNorm',NaN,'Step',NaN,'Curvature',NaN, ...
                'CorrectorIterations',NaN,'BacktrackingCount',0, ...
                'Feasibility',struct('Status','not-evaluated'), ...
                'Gait',struct(),'TerminationCandidate','', ...
                'CheckpointPath','','ExitFlag',NaN, ...
                'CorrectorOutput',struct(),'Failure','', ...
                'Direction',0,'AchievedStep',NaN,'Seed',false);
            names=fieldnames(defaults);
            for index=1:numel(names)
                if ~isfield(value,names{index})
                    value.(names{index})=defaults.(names{index});
                end
            end
        end
    end
end
