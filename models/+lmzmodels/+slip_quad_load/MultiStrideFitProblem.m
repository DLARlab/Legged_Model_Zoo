classdef MultiStrideFitProblem < lmz.api.OptimizationProblem
    methods
        function obj=MultiStrideFitProblem(model,configuration)
            decision=lmz.schema.VariableSchema([ ...
                lmz.schema.VariableSpec('speed','DefaultValue',0.45,'LowerBound',0.1,'UpperBound',2,'Scale',0.5); ...
                lmz.schema.VariableSpec('stride_period','DefaultValue',1.3,'LowerBound',0.3,'UpperBound',2,'Scale',0.5); ...
                lmz.schema.VariableSpec('rope_length','DefaultValue',1.2,'LowerBound',0.2,'UpperBound',2,'Scale',0.5)]);
            parameters=lmz.schema.VariableSchema([lmz.schema.VariableSpec('target_speed','DefaultValue',0.8);lmz.schema.VariableSpec('target_period','DefaultValue',0.9);lmz.schema.VariableSpec('target_rope_length','DefaultValue',0.8)]);
            obj@lmz.api.OptimizationProblem(model,'multi_stride_fit','optimization',decision,parameters,[0.8;0.9;0.8],configuration);
        end
        function [value,terms,diagnostics]=evaluateObjective(~,u,p,context)
            context.check(); terms=struct('stride_duration',(u(2)-p(2))^2, ...
                'footfall_timing',(u(1)-p(1))^2,'loading_force',(u(3)-p(3))^2); value=terms.stride_duration+terms.footfall_timing+terms.loading_force; diagnostics=struct('legacyEquivalent',false,'R2',1-value/(1+value));
        end
        function value=objectiveTerms(~), value={'stride_duration','footfall_timing','loading_force'}; end
    end
end
