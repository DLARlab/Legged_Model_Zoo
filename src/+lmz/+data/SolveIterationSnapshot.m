classdef SolveIterationSnapshot
    %SOLVEITERATIONSNAPSHOT Immutable, serializable nonlinear-solve state.
    properties (SetAccess=private)
        Stage = ''
        Iteration = NaN
        FunctionCount = NaN
        DecisionValues = zeros(0,1)
        ScaledResidual = NaN
        StepNorm = NaN
        FirstOrderOptimality = NaN
        Accepted = false
        Message = ''
        Timestamp = ''
    end

    methods
        function obj=SolveIterationSnapshot(value)
            if nargin==0,return,end
            if isa(value,'lmz.data.SolveIterationSnapshot'),obj=value;return,end
            if ~isstruct(value)||~isscalar(value)
                error('lmz:Data:SolveIterationSnapshot', ...
                    'A solve iteration snapshot must be a scalar struct.');
            end
            names=fieldnames(value);allowed=properties(obj);
            if ~all(ismember(names,allowed))
                error('lmz:Data:SolveIterationSnapshotField', ...
                    'Solve iteration snapshot contains an unknown field.');
            end
            for index=1:numel(names),obj.(names{index})=value.(names{index});end
            obj=validate(obj);
        end

        function value=toStruct(obj)
            names=properties(obj);value=struct();
            for index=1:numel(names),value.(names{index})=obj.(names{index});end
        end
    end
end

function obj=validate(obj)
if isstring(obj.Stage)&&isscalar(obj.Stage),obj.Stage=char(obj.Stage);end
if isstring(obj.Message)&&isscalar(obj.Message),obj.Message=char(obj.Message);end
if isstring(obj.Timestamp)&&isscalar(obj.Timestamp),obj.Timestamp=char(obj.Timestamp);end
if ~ischar(obj.Stage)||~ischar(obj.Message)||~ischar(obj.Timestamp)
    error('lmz:Data:SolveIterationSnapshotText', ...
        'Snapshot stage, message, and timestamp must be text.');
end
numericScalars={'Iteration','FunctionCount','ScaledResidual', ...
    'StepNorm','FirstOrderOptimality'};
for index=1:numel(numericScalars)
    item=obj.(numericScalars{index});
    if ~isnumeric(item)||~isreal(item)||~isscalar(item)|| ...
            ~(isfinite(item)||isnan(item))
        error('lmz:Data:SolveIterationSnapshotNumeric', ...
            '%s must be a finite scalar or NaN.',numericScalars{index});
    end
end
if ~isnumeric(obj.DecisionValues)||~isreal(obj.DecisionValues)|| ...
        any(~isfinite(obj.DecisionValues(:)))
    error('lmz:Data:SolveIterationSnapshotDecision', ...
        'Snapshot decision values must be finite real numeric values.');
end
obj.DecisionValues=obj.DecisionValues(:);
if ~(islogical(obj.Accepted)&&isscalar(obj.Accepted))
    error('lmz:Data:SolveIterationSnapshotAccepted', ...
        'Snapshot Accepted must be logical scalar.');
end
if isempty(obj.Timestamp),obj.Timestamp=lmz.compat.Timestamp.current();end
end
