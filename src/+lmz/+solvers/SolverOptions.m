classdef SolverOptions
    properties
        FunctionTolerance=1e-10; StepTolerance=1e-10; OptimalityTolerance=1e-10
        MaxIterations=200; MaxFunctionEvaluations=2000; Display='off'; Algorithm='levenberg-marquardt'
        OutputFcn=[]
        Callbacks=[]
        Progress=[]
    end
    methods
        function obj=SolverOptions(value)
            if nargin==0||isempty(value),return,end
            if isa(value,'lmz.solvers.SolverOptions'),obj=value;return,end
            if ~isstruct(value)||~isscalar(value)
                error('lmz:Solver:Options', ...
                    'Solver options must be a scalar struct or SolverOptions.');
            end
            names=fieldnames(value);
            for index=1:numel(names)
                if isprop(obj,names{index})
                    obj.(names{index})=value.(names{index});
                end
            end
            if ~isempty(obj.OutputFcn)&&~isa(obj.OutputFcn,'function_handle')&& ...
                    ~(iscell(obj.OutputFcn)&& ...
                    all(cellfun(@(item)isa(item,'function_handle'),obj.OutputFcn)))
                error('lmz:Solver:OutputFcn', ...
                    'OutputFcn must contain one or more function handles.');
            end
            if ~isempty(obj.Callbacks)&& ...
                    ~isa(obj.Callbacks,'lmz.solvers.SolveCallbacks')
                obj.Callbacks=lmz.solvers.SolveCallbacks(obj.Callbacks);
            end
            if ~isempty(obj.Progress)&&~isa(obj.Progress,'lmz.data.SolveProgress')
                error('lmz:Solver:SolveProgress', ...
                    'Progress must be an lmz.data.SolveProgress handle.');
            end
        end
        function value=toStruct(obj)
            names=properties(obj);value=struct();
            runtimeOnly={'OutputFcn','Callbacks','Progress'};
            for index=1:numel(names)
                name=names{index};
                if any(strcmp(name,runtimeOnly)),continue,end
                value.(name)=obj.(name);
            end
        end
    end
end
