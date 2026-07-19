classdef TrajectoryFitProblem < lmz.api.OptimizationProblem
    methods
        function obj=TrajectoryFitProblem(model,configuration)
            decision=lmz.schema.VariableSchema([ ...
                lmz.schema.VariableSpec('speed','DefaultValue',0.6,'LowerBound',0.1,'UpperBound',3,'Scale',1); ...
                lmz.schema.VariableSpec('stride_period','DefaultValue',1.1,'LowerBound',0.2,'UpperBound',2,'Scale',0.5)]);
            parameters=lmz.schema.VariableSchema([lmz.schema.VariableSpec('target_speed','DefaultValue',1.1);lmz.schema.VariableSpec('target_period','DefaultValue',0.75)]);
            obj@lmz.api.OptimizationProblem(model,'trajectory_fit','optimization',decision,parameters,[1.1;0.75],configuration);
        end
        function [value,terms,diagnostics]=evaluateObjective(~,u,p,context)
            context.check(); terms=struct('trajectory_speed',(u(1)-p(1))^2,'stride_duration',(u(2)-p(2))^2); value=terms.trajectory_speed+terms.stride_duration; diagnostics=struct('legacyEquivalent',false);
        end
        function value=objectiveTerms(~), value={'trajectory_speed','stride_duration'}; end
    end
end
