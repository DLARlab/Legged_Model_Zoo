classdef RootSolver
    methods
        function [solution,report]=solve(~,problem,initial,options)
            if nargin<4||isempty(options),options=lmz.solvers.SolverOptions();end;if isa(initial,'lmz.core.Solution'),z0=initial.Decision;else,z0=initial;end
            validation=problem.validateDecision(z0);validation.throwIfInvalid();schema=problem.decisionSchema();scale=schema.scales();count=0;t=tic;warnings={};tool='fminsearch';
            fun=@residual; if exist('fsolve','file')==2,tool='fsolve';op=optimoptions('fsolve','Display',options.Display,'FunctionTolerance',options.FunctionTolerance,'StepTolerance',options.StepTolerance,'MaxIterations',options.MaxIterations,'MaxFunctionEvaluations',options.MaxFunctionEvaluations);[u,~,exitflag,out]=fsolve(fun,z0(:)./scale,op);iterations=out.iterations;else,op=optimset('Display',options.Display,'TolFun',options.FunctionTolerance^2,'TolX',options.StepTolerance,'MaxIter',options.MaxIterations,'MaxFunEvals',options.MaxFunctionEvaluations);[u,~,exitflag,out]=fminsearch(@(q)sum(fun(q).^2),z0(:)./scale,op);iterations=out.iterations;warnings{end+1}='Optimization Toolbox unavailable; used fminsearch least-squares fallback.';end
            z=problem.canonicalize(u(:).*scale);ev=problem.evaluate(z,struct());rn=norm(ev.scaledEquality(),inf);converged=exitflag>0&&rn<=options.FunctionTolerance&&ev.IsValid&&ev.IsPhysicallyValid;meta=problem.metadata();id=strrep(tempname,'/','-');solution=lmz.core.Solution(struct('Id',id,'ModelId',meta.model_id,'ProblemId',meta.id,'Decision',z,'Decoded',schema.decode(z),'Evaluation',ev,'Provenance',lmz.io.Provenance.capture()));report=struct('converged',converged,'exit_flag',exitflag,'tool',tool,'iterations',iterations,'function_evaluations',count,'scaled_residual_norm',rn,'valid',ev.IsValid,'physically_valid',ev.IsPhysicallyValid,'warnings',{warnings},'elapsed_seconds',toc(t));
            function r=residual(u),count=count+1;zq=problem.canonicalize(u(:).*scale);eq=problem.evaluate(zq,struct());r=eq.scaledEquality();if isempty(r),r=eq.EqualityResidual(:);end;end
        end
    end
end
