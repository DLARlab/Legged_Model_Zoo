classdef SeedService
    methods
        function [solution,diagnostics]=project(~,problem,solution,options,context) %#ok<INUSD>
            [u,diagnostics]=problem.projectSeed(solution.DecisionValues,solution.ParameterValues,context); solution=solution.withDecisionValues(u);
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
    end
end

function jacobian=finiteJacobian(problem,u,p,context)
base=problem.residual(u,p,context);jacobian=zeros(numel(base),numel(u));
for index=1:numel(u),step=sqrt(eps)*max(1,abs(u(index)));candidate=u;candidate(index)=candidate(index)+step;jacobian(:,index)=(problem.residual(candidate,p,context)-base)/step;end
end
