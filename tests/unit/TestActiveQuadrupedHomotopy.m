classdef TestActiveQuadrupedHomotopy < matlab.unittest.TestCase
    methods (Test)
        function nearbyLegStiffnessTargetIsTransported(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_quadruped').createProblem( ...
                'periodic_apex',struct());
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
            branch=lmz.services.BranchService().loadRoadMapBranch( ...
                problem,catalog.defaultBranchPath());
            seedIndex=catalog.recommendedSeedIndex(catalog.defaultBranchPath());
            seed=branch.point(seedIndex);schema=problem.getParameterSchema();
            parameterIndex=schema.indexOf('k_leg');
            testCase.verifyEqual(schema.Specs(parameterIndex).Activity,'active');
            targets=[seed.ParameterValues(parameterIndex), ...
                seed.ParameterValues(parameterIndex)+0.001];
            changedParameters=seed.ParameterValues;
            changedParameters(parameterIndex)=targets(2);
            context=lmz.api.RunContext.synchronous(740);
            original=problem.residual(seed.DecisionValues,seed.ParameterValues,context);
            changed=problem.residual(seed.DecisionValues,changedParameters,context);
            testCase.verifyGreaterThan(norm(changed-original),1e-10);
            result=lmz.services.ContinuationService().parameterHomotopy( ...
                problem,seed,'k_leg',targets,struct(),context);
            testCase.verifyEqual(result.Completed,2);
            testCase.verifyEqual(result.Solutions(2).parameter('k_leg'), ...
                targets(2),'AbsTol',1e-12);
            testCase.verifyLessThan(norm(problem.residual( ...
                result.Solutions(2).DecisionValues, ...
                result.Solutions(2).ParameterValues,context)),1e-7);
        end
    end
end
