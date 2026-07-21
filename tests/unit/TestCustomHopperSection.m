classdef TestCustomHopperSection < matlab.unittest.TestCase
    methods (Test)
        function descendingHeightSectionRunsThroughPublicService(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            catalog=registry.getPoincareSectionRegistry('tutorial_hopper');
            descriptor=catalog.descriptor('height_descending');
            testCase.verifyEqual(descriptor.Kind,'state_plane');
            testCase.verifyEqual(descriptor.StateName,'y');
            testCase.verifyEqual(descriptor.Threshold,0.1);
            testCase.verifyEqual(descriptor.CrossingDirection,-1);

            model=registry.createModel('tutorial_hopper');
            problem=model.createProblem('periodic_hop',struct());
            context=lmz.api.RunContext.synchronous(931);
            u=problem.getDecisionSchema().defaults();
            p=problem.getParameterSchema().defaults();
            evaluation=problem.evaluate(u,p,context,true);
            source=problem.makeSolution(u,p,evaluation);
            returned=lmz.services.PoincareReturnService().simulate( ...
                model,source,struct('StartSectionId','apex', ...
                'StopSectionId','height_descending'),context);

            yIndex=returned.Simulation.StateSchema.indexOf('y');
            testCase.verifyEqual(returned.StopCrossing.SectionId, ...
                'height_descending');
            testCase.verifyEqual(returned.StopCrossing.State(yIndex),0.1, ...
                'AbsTol',2e-12);
            testCase.verifyEqual(returned.StopCrossing.CrossingDirection,-1);
            testCase.verifyFalse(returned.StopCrossing.Grazing);
        end
    end
end
