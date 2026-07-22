classdef RankAwareNonlinearSolver
    %RANKAWARENONLINEARSOLVER Explicit rectangular nonlinear solver router.
    methods
        function [result,diagnostics]=solve(obj,problem,seed,parameters, ...
                options,context)
            if nargin<5||isempty(options),options=struct();end
            if nargin<6||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            if ~isa(problem,'lmz.api.NonlinearEquationProblem')
                error('lmz:Solver:ProblemType', ...
                    ['RankAwareNonlinearSolver requires a ' ...
                    'NonlinearEquationProblem.']);
            end
            rawOptions=optionStruct(options);
            if isa(seed,'lmz.data.Solution')
                seedVector=seed.DecisionValues;
                if nargin<4||isempty(parameters)
                    parameters=seed.ParameterValues;
                end
            else
                seedVector=seed(:);
            end
            if nargin<4||isempty(parameters)
                parameters=problem.getParameterSchema().defaults();
            end
            problem.getDecisionSchema().validateVector(seedVector);
            initial=problem.evaluate(seedVector,parameters,context,false);
            m=numel(initial.ScaledResidual);n=numel(seedVector);
            requested=fieldOr(rawOptions,'Solver','auto');
            [selected,reason]=selectSolver( ...
                requested,m,n,hasFiniteBounds(problem));
            solverOptions=removeFields(rawOptions,{ ...
                'Solver','RankTolerance','FiniteDifferenceStep', ...
                'ResidualTolerance','FixedRowTolerance'});
            [solverOptions,algorithmRequested,algorithmSelected]= ...
                resolveAlgorithm(selected,solverOptions,problem);
            validateAlgorithmSelection(selected,solverOptions);
            if n==0
                evaluation=problem.evaluate(seedVector,parameters,context,true);
                solution=problem.makeSolution(seedVector,parameters,evaluation);
                output=struct('algorithm','fixed-decision-validation', ...
                    'iterations',0,'funcCount',2,'message', ...
                    'No free decision variables; validation only.', ...
                    'ResidualHistory',evaluation.ScaledResidualNorm);
                sourceSeed=seedVector;
                if isa(seed,'lmz.data.Solution'),sourceSeed=seed.toStruct();end
                result=lmz.data.SolveResult(solution,evaluation,1,output, ...
                    solverOptions,sourceSeed,context.RandomSeed,struct( ...
                    'solver','fixed-decision-validation', ...
                    'matlabVersion',version,'evaluations',2, ...
                    'elapsedTime',0,'problemMetadata',problem.getDescriptor()));
                selected='fixed-decision-validation';
                reason='zero_unknown_dimension';
                algorithmSelected='none';
            else
                switch selected
                    case 'fsolve'
                        result=lmz.solvers.FsolveSolver().solve(problem, ...
                            seed,parameters,solverOptions,context);
                    case 'lsqnonlin'
                        result=lmz.solvers.LsqnonlinSolver().solve(problem, ...
                            seed,parameters,solverOptions,context);
                    case 'fmincon_feasibility'
                        result=solveFmincon(problem,seed,parameters, ...
                            solverOptions,context);
                    otherwise
                        error('lmz:Solver:InternalSelection', ...
                            'Unsupported validated solver selection.');
                end
            end
            diagnostics=obj.analyze(problem, ...
                result.Solution.DecisionValues,parameters,rawOptions,context);
            diagnostics.SolverRequested=requested;
            diagnostics.SolverSelected=selected;
            diagnostics.SelectionReason=reason;
            diagnostics.AlgorithmRequested=algorithmRequested;
            diagnostics.AlgorithmSelected=algorithmSelected;
            diagnostics.ExitFlag=result.ExitFlag;
            diagnostics.TerminationReason=terminationReason( ...
                result.ExitFlag,result.Output);
            output=result.Output;
            output.RankDiagnostics=diagnostics;
            output.SolverRequested=requested;
            output.SolverSelected=selected;
            provenance=result.Provenance;
            provenance.rankDiagnostics=diagnostics;
            result=lmz.data.SolveResult(result.Solution,result.Evaluation, ...
                result.ExitFlag,output,result.Options,result.SourceSeed, ...
                result.RandomSeed,provenance,result.Progress);
        end

        function diagnostics=analyze(~,problem,decision,parameters, ...
                options,context)
            if nargin<5||isempty(options),options=struct();end
            if nargin<6||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            values=optionStruct(options);
            if nargin<4||isempty(parameters)
                parameters=problem.getParameterSchema().defaults();
            end
            decision=decision(:);
            evaluation=problem.evaluate(decision,parameters,context,false);
            scale=problem.scale(decision);q=decision./scale;
            jacobian=problem.optionalJacobian( ...
                decision,parameters,context);
            source='analytic';
            if isempty(jacobian)
                jacobian=finiteJacobian(problem,q,scale,parameters, ...
                    values,context,evaluation.ScaledResidual);
                source='finite_difference';
            else
                if ~isnumeric(jacobian)||~ismatrix(jacobian)|| ...
                        size(jacobian,1)~=numel(evaluation.ScaledResidual)|| ...
                        size(jacobian,2)~=numel(decision)|| ...
                        any(~isfinite(jacobian(:)))
                    error('lmz:Solver:JacobianShape', ...
                        'Optional Jacobian has an invalid shape or value.');
                end
                jacobian=jacobian.*repmat(scale(:).', ...
                    size(jacobian,1),1);
            end
            singularValues=svd(jacobian,'econ');
            defaultTolerance=max(size(jacobian))*sqrt(eps)* ...
                max([singularValues(:);1]);
            tolerance=fieldOr(values,'RankTolerance',defaultTolerance);
            if ~isnumeric(tolerance)||~isscalar(tolerance)|| ...
                    ~isfinite(tolerance)||tolerance<0
                error('lmz:Solver:RankTolerance', ...
                    'RankTolerance must be finite and nonnegative.');
            end
            rankValue=sum(singularValues>tolerance);
            n=numel(decision);m=numel(evaluation.ScaledResidual);
            if rankValue==0
                effectiveCondition=Inf;
            else
                effectiveCondition=singularValues(1)/ ...
                    singularValues(rankValue);
            end
            fullColumnCondition=effectiveCondition;
            if rankValue<n,fullColumnCondition=Inf;end
            residual=evaluation.ScaledResidual(:);
            if isempty(residual)||isempty(jacobian)
                firstOrder=0;
            else
                firstOrder=norm(jacobian.'*residual,Inf);
            end
            diagnostics=struct('M',m,'N',n,'Rank',rankValue, ...
                'Nullity',n-rankValue,'SingularValues',singularValues(:), ...
                'RankTolerance',tolerance, ...
                'ConditionEstimate',effectiveCondition, ...
                'FullColumnConditionEstimate',fullColumnCondition, ...
                'ScaledResidualNorm',evaluation.ScaledResidualNorm, ...
                'UnscaledResidualBlocks',{residualBlocks(evaluation)}, ...
                'ActiveBounds',{activeBounds(problem,decision)}, ...
                'FirstOrderOptimality',firstOrder, ...
                'Jacobian',jacobian,'JacobianSource',source);
        end
    end
end

function [selected,reason]=selectSolver(requested,m,n,bounded)
allowed={'auto','fsolve','lsqnonlin','fmincon_feasibility'};
if isstring(requested)&&isscalar(requested),requested=char(requested);end
if ~ischar(requested)||~any(strcmp(requested,allowed))
    error('lmz:Solver:UnknownSolver', ...
        'Solver must be one of: %s.',strjoin(allowed,', '));
end
if m<n
    error('lmz:Timing:GaugeRequired', ...
        ['The nonlinear system has %d residual rows and %d unknowns. ' ...
        'Add independent gauges/fixed variables or use an explicit ' ...
        'one-dimensional family formulation.'],m,n);
end
if strcmp(requested,'auto')
    if m==n&&bounded
        selected='lsqnonlin';reason='bounded_square_system';
    elseif m==n
        selected='fsolve';reason='validated_square_system';
    else
        selected='lsqnonlin';reason='validated_overdetermined_system';
    end
    return
end
selected=requested;reason='explicit_user_selection';
if strcmp(selected,'fsolve')&&m~=n
    error('lmz:Solver:DimensionModeMismatch', ...
        'fsolve requires a square system; received %d rows and %d unknowns.',m,n);
end
if strcmp(selected,'fsolve')&&bounded
    error('lmz:Solver:BoundedFsolveUnsupported', ...
        ['fsolve does not enforce decision-schema bounds. Use auto, ' ...
        'lsqnonlin, or constrained feasibility for this problem.']);
end
end

function validateAlgorithmSelection(solver,options)
if isfield(options,'Algorithm')
    algorithm=options.Algorithm;
else
    algorithm='';
end

switch solver
    case 'fsolve'
        if isempty(algorithm),return,end
        allowed={'levenberg-marquardt','trust-region', ...
            'trust-region-dogleg'};
    case 'lsqnonlin'
        if isempty(algorithm),return,end
        allowed={'levenberg-marquardt','trust-region-reflective'};
    case 'fmincon_feasibility'
        if isempty(algorithm),return,end
        allowed={'interior-point','sqp','sqp-legacy','active-set'};
    otherwise
        return
end
if ~ischar(algorithm)||~any(strcmp(algorithm,allowed))
    error('lmz:Solver:Algorithm', ...
        '%s Algorithm must be one of: %s.',solver,strjoin(allowed,', '));
end
end

function [options,requested,selected]=resolveAlgorithm(solver,options,problem)
requested=fieldOr(options,'Algorithm','default');
if ~strcmp(requested,'default')
    selected=requested;return
end
switch solver
    case 'fsolve'
        selected='levenberg-marquardt';
    case 'lsqnonlin'
        if hasFiniteBounds(problem)
            selected='trust-region-reflective';
        else
            selected='levenberg-marquardt';
        end
    case 'fmincon_feasibility'
        selected='interior-point';
    otherwise
        selected='none';return
end
options.Algorithm=selected;
end

function value=hasFiniteBounds(problem)
schema=problem.getDecisionSchema();value=false;
for index=1:schema.count()
    spec=schema.Specs(index);
    if isfinite(spec.LowerBound)||isfinite(spec.UpperBound)
        value=true;return
    end
end
end

function result=solveFmincon(problem,seed,parameters,options,context)
started=tic;
if exist('fmincon','file')~=2
    error('lmz:Solver:ToolboxUnavailable', ...
        'Optimization Toolbox fmincon is unavailable.');
end
if isa(seed,'lmz.data.Solution')
    u0=seed.DecisionValues;sourceSeed=seed.toStruct();
else
    u0=seed(:);sourceSeed=u0;
end
solverOptions=lmz.solvers.SolverOptions(options);
algorithm=fieldOr(options,'Algorithm','interior-point');
scale=problem.scale(u0);q0=u0./scale;
[lower,upper]=scaledBounds(problem,scale);
optionValues=struct('Display',solverOptions.Display, ...
    'Algorithm',algorithm,'StepTolerance',solverOptions.StepTolerance, ...
    'OptimalityTolerance',solverOptions.OptimalityTolerance, ...
    'MaxIterations',solverOptions.MaxIterations, ...
    'MaxFunctionEvaluations',solverOptions.MaxFunctionEvaluations);
matlabOptions=lmz.compat.Optimization.fmincon(optionValues);
evaluations=0;residualHistory=zeros(0,1);
[q,objective,exitFlag,output]=fmincon(@merit,q0,[],[],[],[], ...
    lower,upper,[],matlabOptions);
u=problem.canonicalize(q.*scale);
evaluation=problem.evaluate(u,parameters,context,true);
solution=problem.makeSolution(u,parameters,evaluation);
output.ResidualMerit=objective;
output.ResidualHistory=residualHistory;
result=lmz.data.SolveResult(solution,evaluation,exitFlag,output,options, ...
    sourceSeed,context.RandomSeed,struct('solver','fmincon_feasibility', ...
    'matlabVersion',version,'evaluations',evaluations, ...
    'elapsedTime',toc(started),'problemMetadata',problem.getDescriptor()));
    function value=merit(qValue)
        context.check();evaluations=evaluations+1;
        candidate=problem.canonicalize(qValue.*scale);
        residual=problem.residual(candidate,parameters,context);
        value=.5*(residual.'*residual);
        residualHistory(end+1,1)=norm(residual);
    end
end

function jacobian=finiteJacobian(problem,q,scale,parameters,options, ...
        context,base)
m=numel(base);n=numel(q);jacobian=zeros(m,n);
relative=fieldOr(options,'FiniteDifferenceStep',sqrt(eps));
if ~isnumeric(relative)||~isscalar(relative)||~isfinite(relative)||relative<=0
    error('lmz:Solver:FiniteDifferenceStep', ...
        'FiniteDifferenceStep must be finite and positive.');
end
for index=1:n
    context.check();step=relative*max(1,abs(q(index)));
    candidate=q;candidate(index)=candidate(index)+step;
    decision=problem.canonicalize(candidate.*scale);
    value=problem.residual(decision,parameters,context);
    if numel(value)~=m
        error('lmz:Solver:ResidualDimensionChanged', ...
            'Residual dimension changed during Jacobian evaluation.');
    end
    jacobian(:,index)=(value(:)-base(:))/step;
end
end

function values=residualBlocks(evaluation)
values=cell(numel(evaluation.ResidualBlocks),1);
for index=1:numel(values)
    values{index}=evaluation.ResidualBlocks(index).toStruct();
end
end

function values=activeBounds(problem,decision)
schema=problem.getDecisionSchema();template=struct('Index',0,'Name','', ...
    'Side','','Value',0,'Bound',0);values=repmat(template,0,1);
for index=1:schema.count()
    spec=schema.Specs(index);tolerance=sqrt(eps)*max(1,abs(decision(index)));
    if isfinite(spec.LowerBound)&& ...
            abs(decision(index)-spec.LowerBound)<=tolerance
        item=template;item.Index=index;item.Name=spec.Name;item.Side='lower';
        item.Value=decision(index);item.Bound=spec.LowerBound;
        values(end+1,1)=item; %#ok<AGROW>
    end
    if isfinite(spec.UpperBound)&& ...
            abs(decision(index)-spec.UpperBound)<=tolerance
        item=template;item.Index=index;item.Name=spec.Name;item.Side='upper';
        item.Value=decision(index);item.Bound=spec.UpperBound;
        values(end+1,1)=item; %#ok<AGROW>
    end
end
end

function [lower,upper]=scaledBounds(problem,scale)
schema=problem.getDecisionSchema();count=schema.count();
lower=zeros(count,1);upper=zeros(count,1);
for index=1:count
    lower(index)=schema.Specs(index).LowerBound/scale(index);
    upper(index)=schema.Specs(index).UpperBound/scale(index);
end
end

function reason=terminationReason(exitFlag,output)
if exitFlag>0
    reason='solver_accepted';
elseif exitFlag==0
    reason='iteration_or_evaluation_limit';
else
    reason='solver_failure';
end
if isstruct(output)&&isfield(output,'algorithm')&& ...
        strcmp(output.algorithm,'fixed-decision-validation')
    reason='fixed_decision_validation';
end
end

function value=optionStruct(options)
if isa(options,'lmz.solvers.SolverOptions')
    value=options.toStruct();
elseif isstruct(options)&&isscalar(options)
    value=options;
else
    error('lmz:Solver:Options', ...
        'Rank-aware solver options must be a scalar struct or SolverOptions.');
end
end

function value=removeFields(value,names)
for index=1:numel(names)
    if isfield(value,names{index}),value=rmfield(value,names{index});end
end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name); ...
else,value=fallback;end
end
