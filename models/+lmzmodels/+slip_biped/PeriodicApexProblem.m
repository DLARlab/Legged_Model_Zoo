classdef PeriodicApexProblem < lmz.api.NonlinearEquationProblem
    %PERIODICAPEXPROBLEM Native stride-closure manifold demonstration.
    methods
        function obj=PeriodicApexProblem(model,configuration)
            decision=lmz.schema.VariableSchema([ ...
                lmz.schema.VariableSpec('speed','Unit','m/s','DefaultValue',1,'LowerBound',0.1,'UpperBound',3,'Scale',1); ...
                lmz.schema.VariableSpec('stride_period','Unit','s','DefaultValue',0.8,'LowerBound',0.2,'UpperBound',2,'Scale',0.5)]);
            parameters=lmz.schema.VariableSchema(lmz.schema.VariableSpec('stride_length','Unit','m','DefaultValue',0.8,'LowerBound',0.1,'UpperBound',3));
            obj@lmz.api.NonlinearEquationProblem(model,'periodic_apex','nonlinear_equation',decision,parameters,0.8,configuration);
        end
        function evaluation=evaluate(obj,u,p,context,includeSimulation)
            context.check(); obj.DecisionSchema.validateVector(u); obj.ParameterSchema.validateVector(p);
            closure=u(1)*u(2)-p(1);
            blocks=[lmz.data.ResidualBlock('stride_closure',closure,1); ...
                lmz.data.ResidualBlock('compatibility_redundant',2*closure,2)];
            simulation=[];
            if includeSimulation, request=obj.toSimulationRequest(u,p,struct()); simulation=obj.Model.simulate(request,context); end
            evaluation=lmz.data.ProblemEvaluation(blocks,'Simulation',simulation, ...
                'Diagnostics',struct('formulation','native-stride-closure-v1','legacyEquivalent',false));
        end
        function value=optionalJacobian(~,u,p,varargin) %#ok<INUSD>
            value=[u(2),u(1);2*u(2),2*u(1)];
        end
    end
end
