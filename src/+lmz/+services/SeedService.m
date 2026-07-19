classdef SeedService
    methods
        function [solution,diagnostics]=project(~,problem,solution,options,context)
            [u,diagnostics]=problem.projectSeed(solution.DecisionValues,solution.ParameterValues,options,context); solution=solution.withDecisionValues(u);
        end
        function solution=perturb(~,problem,solution,magnitude,mode,seed)
            stream=RandStream('mt19937ar','Seed',seed); noise=randn(stream,size(solution.DecisionValues));
            switch mode
                case 'absolute',delta=magnitude*noise;
                case 'relative',delta=magnitude*max(abs(solution.DecisionValues),eps).*noise;
                case 'schema-scaled',delta=magnitude*problem.scale(solution.DecisionValues).*noise;
                otherwise,error('lmz:Seed:NoiseMode','Unknown noise mode.');
            end
            solution=solution.withDecisionValues(problem.retract(solution.DecisionValues,delta));
        end
        function pair=makeSecondSeed(~,problem,first,radius,options,context) %#ok<INUSD>
            jacobian=problem.optionalJacobian(first.DecisionValues,first.ParameterValues,context);
            if isempty(jacobian),jacobian=finiteJacobian(problem,first.DecisionValues,first.ParameterValues,context);end
            [~,~,v]=svd(jacobian,'econ'); direction=v(:,end); if direction(find(abs(direction)>1e-12,1))<0,direction=-direction;end
            metric=lmz.schema.DiagonalMetric(problem.scale(first.DecisionValues)); direction=direction/metric.norm(direction); prediction=problem.retract(first.DecisionValues,radius*direction);
            correctOptions=lmz.continuation.ContinuationOptions(struct('CorrectorTolerance',1e-10,'MaxCorrectorIterations',200));
            [u,exitFlag,output,residualNorm]=lmz.continuation.PseudoArclengthCorrector().correct(problem,prediction,direction,first.ParameterValues,correctOptions,context);
            evaluation=problem.evaluate(u,first.ParameterValues,context,false); second=problem.makeSolution(u,first.ParameterValues,evaluation); achieved=metric.norm(problem.difference(second.DecisionValues,first.DecisionValues));
            pair=lmz.data.SolutionPair(first,second,radius,achieved,struct('ExitFlag',exitFlag,'Output',output,'ResidualNorm',residualNorm,'DistanceError',achieved-radius));
        end
        function pair=adjacentBranchPair(~,problem,branch,index,direction,options,context)
            if nargin<6||isempty(options),options=struct();end
            if nargin<7,context=lmz.api.RunContext.synchronous(0);end
            context.check(); n=branch.pointCount();
            if index<1||index>n||index~=fix(index)||n<2
                error('lmz:Seed:BranchIndex','Adjacent seed index is invalid.');
            end
            if ~(isscalar(direction)&&isfinite(direction)&&direction~=0)
                error('lmz:Seed:Direction','Adjacent seed direction must be nonzero.');
            end
            neighbor=index+sign(direction); inwardAdjusted=false;
            if neighbor<1||neighbor>n,neighbor=index-sign(direction);inwardAdjusted=true;end
            if neighbor<1||neighbor>n||neighbor==index
                error('lmz:Seed:NoNeighbor','No distinct inward neighbor is available.');
            end
            pair=lmz.services.SeedService().branchPair(problem,branch,index,neighbor,options,context);
            diagnostics=pair.Diagnostics;
            diagnostics.InwardAdjusted=inwardAdjusted;
            pair=lmz.data.SolutionPair(pair.First,pair.Second,pair.RequestedRadius, ...
                pair.AchievedRadius,diagnostics);
        end
        function pair=branchPair(~,problem,branch,firstIndex,secondIndex,options,context)
            if nargin<6||isempty(options),options=struct();end
            if nargin<7,context=lmz.api.RunContext.synchronous(0);end
            context.check();n=branch.pointCount();
            indices=[firstIndex secondIndex];
            if any(indices<1)||any(indices>n)||any(indices~=fix(indices))
                error('lmz:Seed:BranchIndex','Seed indices are invalid.');
            end
            if firstIndex==secondIndex
                error('lmz:Seed:DuplicateSeeds','Seed indices must be distinct.');
            end
            first=branch.point(firstIndex);second=branch.point(secondIndex);
            if ~strcmp(first.ModelId,problem.getDescriptor().modelId)|| ...
                    ~strcmp(first.ProblemId,problem.Id)
                error('lmz:Seed:ProblemMismatch','Branch is incompatible with the problem.');
            end
            parameterTolerance=option(options,'ParameterTolerance',1e-10);
            if any(abs(first.ParameterValues-second.ParameterValues)> ...
                    parameterTolerance.*max(1,abs(first.ParameterValues)))
                error('lmz:Seed:ParameterMismatch','Adjacent seeds have incompatible parameters.');
            end
            delta=problem.difference(second.DecisionValues,first.DecisionValues);
            metric=lmz.schema.DiagonalMetric(problem.scale(first.DecisionValues));
            distance=metric.norm(delta);
            if ~isfinite(distance)||distance<=option(options,'MinimumSeparation',1e-10)
                error('lmz:Seed:DuplicateSeeds','Adjacent points are not chart-distinct.');
            end
            firstEvaluation=problem.evaluate(first.DecisionValues,first.ParameterValues,context,false);
            secondEvaluation=problem.evaluate(second.DecisionValues,second.ParameterValues,context,false);
            tolerance=option(options,'ResidualTolerance',1e-6);
            if max(firstEvaluation.ScaledResidualNorm,secondEvaluation.ScaledResidualNorm)>tolerance
                error('lmz:Seed:ResidualTooLarge','Adjacent seed residual exceeds tolerance.');
            end
            requireSameGait=option(options,'RequireSameGait',true);
            firstGait=gaitAbbreviation(first.Classification);
            secondGait=gaitAbbreviation(second.Classification);
            if requireSameGait&&~isempty(firstGait)&&~isempty(secondGait)&&~strcmp(firstGait,secondGait)
                error('lmz:Seed:GaitMismatch','Adjacent seeds cross the configured gait policy.');
            end
            diagnostics=struct('SourceBranchId',branch.Id,'SourceIndices',indices, ...
                'InwardAdjusted',false,'ResidualNorms', ...
                [firstEvaluation.ScaledResidualNorm secondEvaluation.ScaledResidualNorm], ...
                'Gaits',{{firstGait,secondGait}}, ...
                'ChartDistance',distance,'ParameterTolerance',parameterTolerance);
            pair=lmz.data.SolutionPair(first,second,distance,distance,diagnostics);
        end
    end
end

function value=option(options,name,fallback)
if isfield(options,name),value=options.(name);else,value=fallback;end
end

function value=gaitAbbreviation(classification)
value='';if isstruct(classification)&&isfield(classification,'Abbreviation'),value=classification.Abbreviation;end
end

function jacobian=finiteJacobian(problem,u,p,context)
base=problem.residual(u,p,context);jacobian=zeros(numel(base),numel(u));
for index=1:numel(u),step=sqrt(eps)*max(1,abs(u(index)));candidate=u;candidate(index)=candidate(index)+step;jacobian(:,index)=(problem.residual(candidate,p,context)-base)/step;end
end
