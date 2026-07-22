classdef SolveCallbacks
    %SOLVECALLBACKS Runtime-only lifecycle callbacks for nonlinear solves.
    properties (SetAccess=private)
        EventFcn = []
        SeedSelectedFcn = []
        SeedEvaluatedFcn = []
        ProjectionStartedFcn = []
        ProjectionCompletedFcn = []
        SolveStartedFcn = []
        IterationFcn = []
        StepAcceptedFcn = []
        SolveCompletedFcn = []
        SolveFailedFcn = []
        ControlledStopFcn = []
    end

    methods
        function obj=SolveCallbacks(value)
            if nargin==0||isempty(value),return,end
            if isa(value,'function_handle')
                obj.EventFcn=value;return
            end
            if isa(value,'lmz.solvers.SolveCallbacks')
                obj=value;return
            end
            if ~isstruct(value)||~isscalar(value)
                error('lmz:Solver:SolveCallbacks', ...
                    'Solve callbacks must be a function handle or scalar struct.');
            end
            names=fieldnames(value);allowed=properties(obj);
            if ~all(ismember(names,allowed))
                error('lmz:Solver:SolveCallbackField', ...
                    'Solve callback configuration contains an unknown field.');
            end
            for index=1:numel(names)
                callback=value.(names{index});
                if ~isempty(callback)&&~isa(callback,'function_handle')
                    error('lmz:Solver:SolveCallbackType', ...
                        '%s must be a function handle.',names{index});
                end
                obj.(names{index})=callback;
            end
        end

        function stop=notify(obj,eventName,snapshot)
            eventName=lmz.solvers.SolveCallbacks.validateEvent(eventName);
            if ~isa(snapshot,'lmz.data.SolveIterationSnapshot')
                error('lmz:Solver:SolveCallbackSnapshot', ...
                    'Solve callbacks require a SolveIterationSnapshot.');
            end
            propertyName=[eventPropertyPrefix(eventName) 'Fcn'];
            callbacks={obj.EventFcn,obj.(propertyName)};
            stop=false;
            for index=1:numel(callbacks)
                callback=callbacks{index};
                if isempty(callback),continue,end
                value=invoke(callback,eventName,snapshot);
                if ~isempty(value)
                    if ~(islogical(value)&&isscalar(value))
                        error('lmz:Solver:SolveCallbackReturn', ...
                            'A solve callback stop request must be logical scalar.');
                    end
                    stop=stop||value;
                end
            end
        end

        function value=toStruct(obj)
            names=properties(obj);value=struct();
            for index=1:numel(names)
                value.(names{index}(1:end-3))=~isempty(obj.(names{index}));
            end
        end
    end

    methods (Static)
        function values=eventNames()
            values={'seed_selected','seed_evaluated', ...
                'projection_started','projection_completed', ...
                'solve_started','iteration','step_accepted', ...
                'solve_completed','solve_failed','controlled_stop'};
        end

        function value=validateEvent(value)
            if isstring(value)&&isscalar(value),value=char(value);end
            if ~ischar(value)|| ...
                    ~any(strcmp(value,lmz.solvers.SolveCallbacks.eventNames()))
                error('lmz:Solver:SolveCallbackEvent', ...
                    'Unknown solve lifecycle event.');
            end
        end
    end
end

function value=eventPropertyPrefix(eventName)
parts=strsplit(eventName,'_');
for index=1:numel(parts)
    parts{index}=[upper(parts{index}(1)) parts{index}(2:end)];
end
value=strjoin(parts,'');
end

function value=invoke(callback,eventName,snapshot)
value=[];
try
    if nargout(callback)==0
        callback(eventName,snapshot);
    else
        value=callback(eventName,snapshot);
    end
catch exception
    if strcmp(exception.identifier,'MATLAB:TooManyOutputs')|| ...
            strcmp(exception.identifier,'MATLAB:maxlhs')
        callback(eventName,snapshot);value=[];
    else
        rethrow(exception)
    end
end
end
