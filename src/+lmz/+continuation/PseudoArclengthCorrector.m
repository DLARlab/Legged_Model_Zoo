classdef PseudoArclengthCorrector
    methods
        function [corrected,exitFlag,output,residualNorm]=correct(~,problem,prediction,tangent,parameters,options,context)
            scale=problem.scale(prediction); matlabOptions=optimoptions('fsolve','Algorithm','levenberg-marquardt','Display','off', ...
                'FunctionTolerance',options.CorrectorTolerance,'StepTolerance',options.CorrectorTolerance,'MaxIterations',options.MaxCorrectorIterations);
            [q,~,exitFlag,output]=fsolve(@augmented,prediction./scale,matlabOptions); corrected=problem.canonicalize(q.*scale); residualNorm=norm(problem.residual(corrected,parameters,context));
            function value=augmented(qValue)
                context.check(); candidate=problem.canonicalize(qValue.*scale); delta=problem.difference(candidate,prediction); arc=(tangent./scale)'*(delta./scale); value=[problem.residual(candidate,parameters,context);arc];
            end
        end
    end
end
