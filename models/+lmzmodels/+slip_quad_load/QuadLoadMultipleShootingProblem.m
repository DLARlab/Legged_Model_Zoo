classdef QuadLoadMultipleShootingProblem < lmz.shooting.MultipleShootingProblem
    %QUADLOADMULTIPLESHOOTINGPROBLEM Explicit load contacts and interfaces.
    properties (SetAccess=private)
        Codec
        InitializerDiagnostics
    end

    methods
        function obj=QuadLoadMultipleShootingProblem(model,configuration)
            if nargin<1||isempty(model),model=lmzmodels.slip_quad_load.Model();end
            if nargin<2,configuration=struct();end
            if ~isa(model,'lmzmodels.slip_quad_load.Model')|| ...
                    ~isstruct(configuration)||~isscalar(configuration)
                error('lmz:QuadLoad:MultipleShootingConfiguration', ...
                    'A load model and scalar configuration are required.');
            end
            context=fieldOr(configuration,'InitializationContext', ...
                lmz.api.RunContext.synchronous(fieldOr(configuration, ...
                'RandomSeed',0)));
            if isfield(configuration,'Horizon')&& ...
                    isa(configuration.Horizon,'lmz.shooting.ShootingHorizon')
                horizon=configuration.Horizon;
                initialization=fieldOr(configuration, ...
                    'InitializerDiagnostics', ...
                    struct('Method','supplied_horizon'));
            else
                [horizon,initialization]=lmzmodels.slip_quad_load. ...
                    QuadLoadHorizonInitializer().create(configuration,context);
            end
            codec=lmzmodels.slip_quad_load.QuadLoadShootingCodec( ...
                horizon,configuration);
            empty=lmzmodels.slip_quad_load.QuadLoadShootingUtilities. ...
                emptySchema();
            configuration=removeFields(configuration, ...
                {'Horizon','ShootingDecisionSchema','InitializationContext', ...
                'PreviousDecision'});
            configuration.Formulation=horizon.Formulation;
            configuration.ProblemId=fieldOr(configuration,'ProblemId', ...
                'multiple_shooting_horizon');
            configuration.ExpectedLocalDimension=fieldOr(configuration, ...
                'ExpectedLocalDimension',0);
            configuration.RequireAcceptedCrossing=fieldOr(configuration, ...
                'RequireAcceptedCrossing',true);
            configuration.SourceDataHashes=mergeSourceHashes( ...
                fieldOr(configuration,'SourceDataHashes',struct()), ...
                fieldOr(initialization,'SourceDataHashes',struct()));
            configuration.InitializerDiagnostics=initialization;
            adapter=lmzmodels.slip_quad_load. ...
                QuadLoadMultipleShootingEvaluator();
            obj@lmz.shooting.MultipleShootingProblem(model, ...
                configuration.ProblemId,codec.ShootingSchema,empty,[], ...
                horizon,adapter,configuration);
            obj.Codec=codec;obj.InitializerDiagnostics=initialization;
        end

        function report=analyze(obj,decision,context,options)
            if nargin<2||isempty(decision),decision=obj.Codec.decisionDefaults();end
            if nargin<3||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if nargin<4,options=struct();end
            evaluation=obj.evaluate(decision,[],context,false);
            computeJacobian=fieldOr(options,'ComputeJacobian',true);
            jacobian=[];singularValues=[];rankEstimate=NaN;nullity=NaN;
            conditionEstimate=NaN;firstOrder=NaN;
            if computeJacobian
                jacobian=finiteDifferenceJacobian(obj,decision,context,options);
                singularValues=svd(jacobian,'econ');
                threshold=rankThreshold(jacobian,singularValues,options);
                rankEstimate=sum(singularValues>threshold);
                nullity=numel(decision)-rankEstimate;
                if isempty(singularValues)||singularValues(end)<=0
                    conditionEstimate=Inf;
                else
                    conditionEstimate=singularValues(1)/singularValues(end);
                end
                firstOrder=norm(jacobian.'*evaluation.ScaledResidual,Inf);
            end
            [activeLower,activeUpper]=activeBounds(obj,decision,options);
            hasSolverExit=isfield(options,'SolverExitFlag');
            solverExit=[];
            if hasSolverExit
                solverExit=options.SolverExitFlag;
                if ~isnumeric(solverExit)||~isscalar(solverExit)|| ...
                        ~isfinite(solverExit)
                    error('lmz:QuadLoad:SolverExitFlag', ...
                        'SolverExitFlag must be a finite numeric scalar.');
                end
            end
            classification=classify(evaluation,numel(decision),solverExit);
            analysisOnly=~hasSolverExit;
            if analysisOnly
                qualification=[ ...
                    'analysis_only_residual_and_physical_validation; ' ...
                    'solver_termination_not_asserted'];
                terminationAcceptable=false;
            else
                qualification='solver_termination_included';
                terminationAcceptable=solverExit>0;
            end
            blocks=cell(numel(evaluation.ResidualBlocks),1);
            for index=1:numel(blocks)
                item=evaluation.ResidualBlocks(index);
                blocks{index}=struct('Name',item.Name,'Values',item.Values, ...
                    'Scale',item.Scale,'ScaledNorm',norm(item.scaled()));
            end
            report=struct('Classification',classification, ...
                'RootFound',strcmp(classification,'root_found'), ...
                'LeastSquaresFeasible',strcmp(classification, ...
                'least_squares_feasible'), ...
                'Success',any(strcmp(classification, ...
                {'root_found','least_squares_feasible'})), ...
                'AnalysisOnly',analysisOnly, ...
                'SolverTerminationAcceptable',terminationAcceptable, ...
                'ClassificationQualification',qualification, ...
                'GlobalInfeasibilityClaimed',false, ...
                'UnknownCount',numel(decision), ...
                'ResidualCount',numel(evaluation.ScaledResidual), ...
                'JacobianRankEstimate',rankEstimate,'Nullity',nullity, ...
                'SingularValues',singularValues, ...
                'ConditionEstimate',conditionEstimate, ...
                'ScaledResidualNorm',evaluation.ScaledResidualNorm, ...
                'MaximumScaledResidual',max(abs(evaluation.ScaledResidual)), ...
                'ResidualBlocks',{blocks}, ...
                'ActiveLowerBounds',{activeLower}, ...
                'ActiveUpperBounds',{activeUpper}, ...
                'FirstOrderOptimality',firstOrder, ...
                'PhysicalValidity',evaluation.PhysicalValidity, ...
                'Feasibility',evaluation.Feasibility, ...
                'Decision',decision(:),'Jacobian',jacobian, ...
                'TerminationReason',fieldOr(options,'TerminationReason', ...
                'evaluation_only'),'InitializerDiagnostics', ...
                obj.InitializerDiagnostics);
        end

        function [result,report]=solveFeasibility(obj,options,context)
            if nargin<2,options=struct();end
            if nargin<3,context=lmz.api.RunContext.synchronous(0);end
            seed=fieldOr(options,'InitialDecision',obj.Codec.decisionDefaults());
            solverOptions=fieldOr(options,'SolverOptions',struct( ...
                'Algorithm','trust-region-reflective', ...
                'MaxIterations',100,'MaxFunctionEvaluations',2000, ...
                'FunctionTolerance',1e-10,'StepTolerance',1e-10, ...
                'OptimalityTolerance',1e-10,'Display','off'));
            result=lmz.solvers.LsqnonlinSolver().solve( ...
                obj,seed,[],solverOptions,context);
            analysisOptions=struct('ComputeJacobian',true, ...
                'TerminationReason',terminationReason(result), ...
                'SolverExitFlag',result.ExitFlag);
            report=obj.analyze(result.Solution.DecisionValues, ...
                context,analysisOptions);
            report.SolverExitFlag=result.ExitFlag;
            report.SolverOutput=result.Output;
        end

        function value=energyHyperplane(obj,strideIndex,decision)
            if nargin<3||isempty(decision),decision=obj.Codec.decisionDefaults();end
            decoded=obj.Codec.decode(decision);
            if strideIndex<2||strideIndex>obj.Horizon.segmentCount()
                error('lmz:QuadLoad:EnergyHyperplaneStride', ...
                    'Energy hyperplanes exist at transitions after stride one.');
            end
            state=decoded.Nodes{strideIndex}.FullState;
            previous=abs(decoded.Controls{strideIndex-1}(:));
            specification=obj.Horizon.Segments{strideIndex}. ...
                EnergyWorkSpecification;
            weights=.5*state([7 9 11 13]).^2;
            target=weights.'*previous+specification.DeclaredWork;
            value=struct('StrideIndex',strideIndex,'Weights',weights, ...
                'PreviousEffectivePostSwing',previous, ...
                'Target',target,'Equation', ...
                'weights''*effectivePostSwing = target', ...
                'DeclaredWork',specification.DeclaredWork, ...
                'Mode',specification.Mode);
        end
    end
end

function value=finiteDifferenceJacobian(problem,decision,context,options)
decision=decision(:);base=problem.residual(decision,[],context);
value=zeros(numel(base),numel(decision));
relative=fieldOr(options,'FiniteDifferenceStep',sqrt(eps));
for index=1:numel(decision)
    step=relative*max(1,abs(decision(index)));
    plus=decision;minus=decision;plus(index)=plus(index)+step;
    minus(index)=minus(index)-step;
    spec=problem.getDecisionSchema().Specs(index);
    canPlus=plus(index)<=spec.UpperBound;
    canMinus=minus(index)>=spec.LowerBound;
    if canPlus&&canMinus
        value(:,index)=(problem.residual(plus,[],context)- ...
            problem.residual(minus,[],context))/(2*step);
    elseif canPlus
        value(:,index)=(problem.residual(plus,[],context)-base)/step;
    elseif canMinus
        value(:,index)=(base-problem.residual(minus,[],context))/step;
    else
        value(:,index)=0;
    end
end
end

function value=rankThreshold(jacobian,singularValues,options)
if isfield(options,'RankTolerance'),value=options.RankTolerance;return,end
if isempty(singularValues),value=0;else
    value=max(size(jacobian))*eps(max(singularValues));
end
end

function [lowerActive,upperActive]=activeBounds(problem,decision,options)
tolerance=fieldOr(options,'BoundTolerance',1e-8);
specs=problem.getDecisionSchema().Specs;lowerActive={};upperActive={};
for index=1:numel(specs)
    scale=max(1,abs(decision(index)));
    if isfinite(specs(index).LowerBound)&& ...
            abs(decision(index)-specs(index).LowerBound)<=tolerance*scale
        lowerActive{end+1,1}=specs(index).Name; %#ok<AGROW>
    end
    if isfinite(specs(index).UpperBound)&& ...
            abs(decision(index)-specs(index).UpperBound)<=tolerance*scale
        upperActive{end+1,1}=specs(index).Name; %#ok<AGROW>
    end
end
end

function value=classify(evaluation,decisionCount,solverExit)
if ~evaluation.PhysicalValidity
    value='physical_validation_failure';
elseif ~all(isfinite(evaluation.ScaledResidual))
    value='numerical_failure';
elseif isempty(solverExit)
    value='best_known_residual';
elseif solverExit<=0
    value='numerical_failure';
elseif evaluation.Feasibility.Valid&& ...
        numel(evaluation.ScaledResidual)==decisionCount
    value='root_found';
elseif evaluation.Feasibility.Valid
    value='least_squares_feasible';
else
    value='best_known_residual';
end
end

function value=terminationReason(result)
if result.ExitFlag>0
    value='solver_terminated_acceptable';
elseif result.ExitFlag==0
    value='iteration_or_evaluation_limit';
else
    value='solver_failure';
end
end

function value=removeFields(value,names)
for index=1:numel(names)
    if isfield(value,names{index}),value=rmfield(value,names{index});end
end
end

function value=mergeSourceHashes(first,second)
if ~isstruct(first)||~isscalar(first)|| ...
        ~isstruct(second)||~isscalar(second)
    error('lmz:QuadLoad:SourceDataHashes', ...
        'Source-data hashes must be scalar structs.');
end
value=first;names=fieldnames(second);
for index=1:numel(names)
    name=names{index};
    if isfield(value,name)&&~isequal(value.(name),second.(name))
        error('lmz:QuadLoad:SourceDataHashConflict', ...
            'Source-data hash metadata conflicts for %s.',name);
    end
    value.(name)=second.(name);
end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
