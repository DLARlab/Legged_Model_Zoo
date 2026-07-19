classdef TestBipedResidualEquivalence < matlab.unittest.TestCase
    methods (Test)
        function allRepresentativeResidualsMatchSource(testCase)
            data=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
                'slip_biped','source_equivalence.mat'),'baseline');baseline=data.baseline;
            problem=lmzmodels.slip_biped.Model().createProblem('periodic_apex',struct());
            context=lmz.api.RunContext.synchronous(70);
            for index=1:numel(baseline.Entries)
                expected=baseline.Entries(index);raw=problem.Evaluator.evaluate( ...
                    expected.Decision,expected.Offsets,context,problem.FixedConfiguration);
                testCase.verifyEqual(raw.Residual,expected.Residual, ...
                    'AbsTol',baseline.Tolerances.ResidualAbsolute);
                testCase.verifyEqual(raw.Residual(12),0);
            end
        end
    end
end
