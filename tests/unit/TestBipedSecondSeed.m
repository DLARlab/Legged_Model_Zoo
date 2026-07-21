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
            testCase.verifyEqual(pair.Diagnostics.LocalDimension,1);
            testCase.verifyEqual(size(first.DecisionValues,1)- ...
                pair.Diagnostics.JacobianRank,1);
        end

        function rejectsUnexpectedLocalDimension(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('slip_biped').createProblem( ...
                'periodic_apex',struct());
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
            branch=catalog.loadBranch([],problem,true);
            first=branch.point(catalog.Manifest.defaultSeedIndex);
            options=struct('ExpectedLocalDimension',2);
            testCase.verifyError(@()lmz.services.SeedService().makeSecondSeed( ...
                problem,first,0.002,options, ...
                lmz.api.RunContext.synchronous(74)), ...
                'lmz:Seed:LocalDimension');
        end
    end
end
