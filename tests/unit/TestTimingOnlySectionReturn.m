classdef TestTimingOnlySectionReturn < matlab.unittest.TestCase
    methods (Test)
        function tutorialReturnsToApex(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'section_return_timing',struct());
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.getDecisionSchema().defaults(),struct(), ...
                lmz.api.RunContext.synchronous(903));
            testCase.verifyLessThan(norm([result.ContactResiduals; ...
                result.SectionResidual]),1e-10);
            testCase.verifyEqual(result.SectionCrossing.SectionId,'apex');
        end

        function tutorialReturnsBetweenDescendingHeightSections(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            model=registry.createModel('tutorial_hopper');
            configuration=struct('StartSectionId','height_descending', ...
                'StopSectionId','height_descending');
            problem=model.createProblem('section_return_timing',configuration);
            fixedState=problem.FixedInitialState;
            fixedParameters=problem.FixedPhysicalParameters;
            result=lmz.services.ContactTimingService().solve(problem, ...
                problem.getDecisionSchema().defaults(),struct(), ...
                lmz.api.RunContext.synchronous(904));
            testCase.verifyLessThan(norm([result.ContactResiduals; ...
                result.SectionResidual]),1e-9);
            testCase.verifyEqual(result.SectionCrossing.SectionId, ...
                'height_descending');
            testCase.verifyEqual(result.SectionCrossing.CrossingDirection,-1);
            testCase.verifyTrue(result.SectionCrossing.Accepted);
            testCase.verifyEqual(result.FixedInitialState,fixedState);
            testCase.verifyEqual(result.FixedPhysicalParameters,fixedParameters);
            testCase.verifyEqual(result.FixedInitialState(3),0.1, ...
                'AbsTol',10*eps);
            testCase.verifyLessThan(result.FixedInitialState(4),0);
        end


        function unsupportedSectionsAreRejectedBeforeSolve(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            cases={ ...
                'tutorial_hopper','ground_impact_pre'; ...
                'slip_quadruped','back_left_touchdown'; ...
                'slip_biped','left_touchdown'; ...
                'slip_quad_load','back_left_touchdown'};
            for index=1:size(cases,1)
                model=registry.createModel(cases{index,1});
                configuration=struct('StartSectionId','apex', ...
                    'StopSectionId',cases{index,2});
                testCase.verifyError(@()model.createProblem( ...
                    'section_return_timing',configuration), ...
                    'lmz:Timing:UnsupportedSection',cases{index,1});
            end
        end
    end
end
