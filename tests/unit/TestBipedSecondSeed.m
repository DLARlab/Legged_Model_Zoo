classdef TestBipedSecondSeed < matlab.unittest.TestCase
    methods (Test)
        function generatesScientificSecondSeed(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();branch=catalog.loadBranch([],problem,true);
            first=branch.point(catalog.Manifest.defaultSeedIndex);
            pair=lmz.services.SeedService().makeSecondSeed(problem,first,0.002,struct(), ...
                lmz.api.RunContext.synchronous(74));
            testCase.verifyGreaterThan(pair.Diagnostics.ExitFlag,0);
            testCase.verifyLessThan(pair.Diagnostics.ResidualNorm,1e-7);
            testCase.verifyEqual(pair.AchievedRadius,0.002,'AbsTol',5e-4);
        end
    end
end
