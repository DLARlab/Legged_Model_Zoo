classdef TestTutorialMultipleShootingPeriodicConvergence < matlab.unittest.TestCase
    methods (Test)
        function convergesTwoAndFiveSegmentPeriodicHorizons(testCase)
            model=lmzmodels.tutorial_hopper.Model();
            context=lmz.api.RunContext.synchronous(2011);
            for count=[2 5]
                problem=model.createProblem('multiple_shooting', ...
                    struct('HorizonLength',count));
                result=lmz.services.MultipleShootingService().solve( ...
                    problem,problem.getDecisionSchema().defaults(), ...
                    struct('ResidualTolerance',1e-9),context);
                testCase.verifyTrue(result.FeasibilityReport.Success);
                testCase.verifyEqual( ...
                    result.FeasibilityReport.Classification,'root_found');
                testCase.verifyLessThan( ...
                    result.FeasibilityReport.MaximumScaledResidual,1e-9);
                testCase.verifyEqual(result.Horizon.segmentCount(),count);
                testCase.verifyTrue(all(cellfun(@(item) ...
                    item.Crossing.Accepted,result.SegmentResults)));
            end
        end

        function tutorialEnergyModesAreExplicit(testCase)
            model=lmzmodels.tutorial_hopper.Model();
            context=lmz.api.RunContext.synchronous(2012);
            bounded=model.createProblem('multiple_shooting',struct( ...
                'HorizonLength',2,'EnergyWorkMode','bounded_work'));
            prescribed=model.createProblem('multiple_shooting',struct( ...
                'HorizonLength',2,'EnergyWorkMode','prescribed_work'));
            boundedResult=bounded.evaluateShooting( ...
                bounded.getDecisionSchema().defaults(), ...
                bounded.getParameterSchema().defaults(),context,false);
            prescribedResult=prescribed.evaluateShooting( ...
                prescribed.getDecisionSchema().defaults(), ...
                prescribed.getParameterSchema().defaults(),context,false);
            boundedEnergy= ...
                boundedResult.SegmentResults{1}.Diagnostics.Energy;
            prescribedEnergy= ...
                prescribedResult.SegmentResults{1}.Diagnostics.Energy;
            testCase.verifyEqual(boundedEnergy.Mode,'bounded_work');
            testCase.verifyEqual(prescribedEnergy.Mode,'prescribed_work');
            testCase.verifyEqual(boundedEnergy.Residual,0,'AbsTol',1e-12);
            testCase.verifyEqual(prescribedEnergy.Residual,0,'AbsTol',1e-12);
            testCase.verifyTrue(boundedResult.Feasibility.EnergyValid);
            testCase.verifyTrue(prescribedResult.Feasibility.EnergyValid);
        end
    end
end
