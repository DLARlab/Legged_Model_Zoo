classdef FeasibilityAnalysisService
    %FEASIBILITYANALYSISSERVICE Reproducible local rank/residual evidence.
    methods
        function report=analyze(~,problem,decision,parameters,options,context)
            if nargin<5,options=struct();end
            if nargin<6,context=lmz.api.RunContext.synchronous(0);end
            if ~isa(problem,'lmz.api.NonlinearEquationProblem')
                error('lmz:Services:FeasibilityProblem', ...
                    'Feasibility analysis requires a nonlinear problem.');
            end
            if nargin<4||isempty(parameters)
                parameters=problem.getParameterSchema().defaults();
            end
            diagnostics=lmz.solvers.RankAwareNonlinearSolver().analyze( ...
                problem,decision,parameters,options,context);
            evaluation=problem.evaluate(decision,parameters,context,false);
            tolerance=fieldOr(options,'ResidualTolerance',1e-7);
            report=lmz.shooting.FeasibilityReport.fromSolve( ...
                evaluation,diagnostics,0,tolerance);
            value=report.toStruct();
            if ~strcmp(report.Classification, ...
                    'physical_validation_failure')
                value.Classification='best_known_residual';
            end
            value.Success=false;
            value.SolverTerminationAcceptable=false;
            value.TerminationReason='analysis-only-no-existence-certificate';
            value.Qualifications={ ...
                'Local numerical evidence; not a proof of global infeasibility.'};
            report=lmz.shooting.FeasibilityReport(value);
        end

        function result=multistart(~,problem,seeds,parameters,options,context)
            if ~isa(problem,'lmz.api.NonlinearEquationProblem')
                error('lmz:Services:FeasibilityProblem', ...
                    'Feasibility multistart requires a nonlinear problem.');
            end
            if nargin<4||isempty(parameters)
                parameters=problem.getParameterSchema().defaults();
            end
            if nargin<5||isempty(options),options=struct();end
            if nargin<6||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            if ~iscell(seeds),error('lmz:Services:FeasibilitySeeds', ...
                    'Multistart seeds must be a cell array.');end
            problem.getParameterSchema().validateVector(parameters);
            descriptor=problem.getDescriptor();
            configuration=descriptor.configuration;
            try
                configurationHash=lmz.io.ArtifactStore.dataHash(configuration);
                parametersHash=lmz.io.ArtifactStore.dataHash(parameters(:));
                optionsHash=lmz.io.ArtifactStore.dataHash(options);
                decisionSchemaHash=lmz.io.ArtifactStore.dataHash( ...
                    problem.getDecisionSchema().toStruct());
                parameterSchemaHash=lmz.io.ArtifactStore.dataHash( ...
                    problem.getParameterSchema().toStruct());
            catch
                error('lmz:Services:FeasibilityExecutableData', ...
                    ['Multistart configuration, parameters, and options ' ...
                    'must contain inert plain data.']);
            end
            attempts=cell(numel(seeds),1);best=[];bestScore=Inf;
            for index=1:numel(seeds)
                context.check();
                solverSeed=seeds{index};
                [seed,decisionSeed]=plainSeed(solverSeed);
                try
                    seedHash=lmz.io.ArtifactStore.dataHash(seed);
                catch
                    error('lmz:Services:FeasibilityExecutableData', ...
                        'Every multistart seed must contain inert plain data.');
                end
                base=struct('Index',index,'Seed',seed(:), ...
                    'SeedHash',seedHash,'SeedDerivation','caller-provided', ...
                    'RandomSeed',context.RandomSeed);
                try
                    problem.getDecisionSchema().validateVector(decisionSeed);
                    [solved,diagnostics]=lmz.solvers. ...
                        RankAwareNonlinearSolver().solve(problem,solverSeed, ...
                        parameters,options,context);
                    report=lmz.shooting.FeasibilityReport.fromSolve( ...
                        solved.Evaluation,diagnostics,solved.ExitFlag, ...
                        fieldOr(options,'ResidualTolerance',1e-7));
                    score=solved.Evaluation.ScaledResidualNorm;
                    base.Succeeded=report.Success;
                    base.ExitFlag=solved.ExitFlag;base.Score=score;
                    base.FinalDecision=solved.Solution.DecisionValues(:);
                    base.TerminationReason=report.TerminationReason;
                    base.Report=report.toStruct();attempts{index}=base;
                    if score<bestScore,bestScore=score;best=solved;end
                catch exception
                    base.Succeeded=false;base.ExitFlag=NaN;base.Score=Inf;
                    base.FinalDecision=[];base.TerminationReason='exception';
                    base.Identifier=exception.identifier;
                    base.Message=exception.message;attempts{index}=base;
                end
            end
            result=struct('BestSolveResult',best,'BestResidual',bestScore, ...
                'Attempts',{attempts},'AttemptCount',numel(attempts), ...
                'Parameters',parameters(:),'Options',options, ...
                'RandomSeed',context.RandomSeed, ...
                'ProblemIdentity',struct('ModelId',descriptor.modelId, ...
                'ModelVersion',descriptor.modelVersion, ...
                'ProblemId',problem.Id,'ProblemVersion',problem.Version), ...
                'ProblemConfiguration',configuration, ...
                'ProblemConfigurationHash',configurationHash, ...
                'DecisionSchemaHash',decisionSchemaHash, ...
                'ParameterSchemaHash',parameterSchemaHash, ...
                'ParametersHash',parametersHash,'OptionsHash',optionsHash, ...
                'GlobalInfeasibilityProven',false);
        end

        function artifact=toArtifact(obj,problem,decision,parameters, ...
                options,context)
            %TOARTIFACT Persist a hash-bound, replayable analysis-only run.
            if nargin<5||isempty(options),options=struct();end
            if nargin<6||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            if ~isa(problem,'lmz.shooting.MultipleShootingProblem')
                error('lmz:Services:FeasibilityShootingProblem', ...
                    ['Horizon-feasibility artifacts require a registered ' ...
                    'multiple-shooting problem.']);
            end
            if nargin<4||isempty(parameters)
                parameters=problem.getParameterSchema().defaults();
            end
            started=tic;
            report=obj.analyze(problem,decision,parameters,options,context);
            evaluation=problem.evaluate(decision,parameters,context,false);
            shooting=problem.evaluateShooting( ...
                decision,parameters,context,true);
            rank=report.Provenance.RankDiagnostics;
            output=rank;
            output.SolverSelected='analysis-only';
            output.message=report.TerminationReason;
            exitFlag=double(report.Success);
            solution=problem.makeSolution(decision,parameters,evaluation);
            provenance=struct('workflow','horizon-feasibility-analysis', ...
                'elapsedTime',toc(started),'evaluations',NaN, ...
                'GlobalInfeasibilityProven',false);
            solveResult=lmz.data.SolveResult(solution,evaluation, ...
                exitFlag,output,options,decision(:), ...
                context.RandomSeed,provenance);
            result=lmz.shooting.ShootingResult(solveResult, ...
                problem.Horizon,report,'SegmentResults', ...
                shooting.SegmentResults,'Diagnostics',struct( ...
                'Rank',rank,'ProblemContract',problem.contract()));
            artifact=result.toArtifact();
            artifact.artifactType='horizon-feasibility-run';
            artifact.horizonFeasibility=struct( ...
                'Decision',decision(:),'Parameters',parameters(:), ...
                'Options',options,'Report',report.toStruct(), ...
                'AnalysisOnly',true,'GlobalInfeasibilityProven',false);
        end
    end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
function [stored,decision]=plainSeed(source)
if isa(source,'lmz.data.Solution')
    stored=source.toStruct();decision=source.DecisionValues(:);
else
    stored=source;decision=source;
    if isnumeric(stored),stored=stored(:);end
end
end
