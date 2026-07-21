classdef TestApexOracleNonRegression < matlab.unittest.TestCase
    methods (Test)
        function configurableApexPresetIsBitwiseSourceCompatible(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            modelIds={'slip_quadruped','slip_biped'};
            for index=1:numel(modelIds)
                model=registry.createModel(modelIds{index});
                oracle=model.createProblem('periodic_apex',struct());
                configurable=model.createProblem('periodic_orbit',struct());
                u=oracle.getDecisionSchema().defaults();
                p=oracle.getParameterSchema().defaults();
                context=lmz.api.RunContext.synchronous(1160+index);
                expected=oracle.evaluate(u,p,context,true);
                actual=configurable.evaluate(u,p,context,true);
                testCase.verifyTrue(configurable.ApexEquivalent);
                testCase.verifyEmpty(configurable.SectionCodec);
                testCase.verifyEqual(actual.Residual,expected.Residual);
                testCase.verifyEqual(actual.ScaledResidual, ...
                    expected.ScaledResidual);
                testCase.verifyEqual(actual.PhysicalValidity, ...
                    expected.PhysicalValidity);
                testCase.verifyEqual(actual.Simulation.Time, ...
                    expected.Simulation.Time);
                testCase.verifyEqual(actual.Simulation.States, ...
                    expected.Simulation.States);
                testCase.verifyEqual(actual.Simulation.EventRecords, ...
                    expected.Simulation.EventRecords);
            end
        end
    end
end
