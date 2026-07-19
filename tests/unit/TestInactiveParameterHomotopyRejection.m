classdef TestInactiveParameterHomotopyRejection < matlab.unittest.TestCase
    methods (Test)
        function inactiveQuadrupedParameterIsRejected(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_quadruped').createProblem( ...
                'periodic_apex',struct());
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
            branch=lmz.services.BranchService().loadRoadMapBranch( ...
                problem,catalog.defaultBranchPath());
            seed=branch.point(catalog.recommendedSeedIndex(catalog.defaultBranchPath()));
            storedSpec=branch.ParameterSchema.Specs( ...
                branch.ParameterSchema.indexOf('phi_neutral'));
            testCase.verifyEqual(storedSpec.Activity,'inactive');
            spec=problem.getParameterSchema().Specs( ...
                problem.getParameterSchema().indexOf('phi_neutral'));
            testCase.verifyEqual(spec.Activity,'inactive');
            testCase.verifyNotEmpty(spec.Note);
            call=@()lmz.services.ContinuationService().parameterHomotopy( ...
                problem,seed,'phi_neutral',0,struct(), ...
                lmz.api.RunContext.synchronous(710));
            testCase.verifyError(call,'lmz:Continuation:InactiveParameter');
        end
        function oldStoredSpecsDefaultToActive(testCase)
            value=lmz.schema.VariableSpec('x').toStruct();
            value=rmfield(value,'Activity');
            restored=lmz.schema.VariableSpec.fromStruct(value);
            testCase.verifyEqual(restored.Activity,'active');
        end
    end
end
