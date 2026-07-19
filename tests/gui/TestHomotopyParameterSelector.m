classdef TestHomotopyParameterSelector < matlab.unittest.TestCase
    methods (Test)
        function controllerExposesOnlyExactlyActiveParameters(testCase)
            controller=lmz.gui.AppController();
            controller.selectModel('slip_quadruped');
            names=controller.homotopyParameterNames();
            testCase.verifyTrue(ismember('k_leg',names));
            testCase.verifyFalse(ismember('phi_neutral',names));

            solution=controller.workingSolution();
            schema=lmz.schema.VariableSchema([ ...
                lmz.schema.VariableSpec('transport_active','DefaultValue',1, ...
                    'Activity','active'); ...
                lmz.schema.VariableSpec('reported_derived','DefaultValue',2, ...
                    'Activity','derived'); ...
                lmz.schema.VariableSpec('compatibility_inactive','DefaultValue',3, ...
                    'Activity','inactive')]);
            value=solution.toStruct();
            value.DecisionSchema=solution.DecisionSchema;
            value.ParameterSchema=schema;
            value.ParameterValues=schema.defaults();
            value.ResidualBlocks=solution.ResidualBlocks;
            controller.State.WorkingSolution=lmz.data.Solution(value);
            testCase.verifyEqual(controller.homotopyParameterNames(), ...
                {'transport_active'});
        end

        function transportRejectsDerivedAndInactiveParameters(testCase)
            schema=lmz.schema.VariableSchema( ...
                lmz.schema.VariableSpec('reported_derived','DefaultValue',1, ...
                'Activity','derived'));
            problem=struct('getParameterSchema',@()schema);
            service=lmz.services.ContinuationService();
            derivedCall=@()service.parameterHomotopy(problem,[], ...
                'reported_derived',1,struct(),lmz.api.RunContext.synchronous(811));
            testCase.verifyError(derivedCall,'lmz:Continuation:DerivedParameter');

            registry=lmz.registry.ModelRegistry.discover();
            quadruped=registry.createModel('slip_quadruped').createProblem( ...
                'periodic_apex',struct());
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
            branch=lmz.services.BranchService().loadRoadMapBranch( ...
                quadruped,catalog.defaultBranchPath());
            seed=branch.point(catalog.recommendedSeedIndex(catalog.defaultBranchPath()));
            inactiveCall=@()service.parameterHomotopy(quadruped,seed, ...
                'phi_neutral',0,struct(),lmz.api.RunContext.synchronous(812));
            testCase.verifyError(inactiveCall,'lmz:Continuation:InactiveParameter');
        end
    end
end
