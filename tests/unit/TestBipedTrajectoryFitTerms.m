classdef TestBipedTrajectoryFitTerms < matlab.unittest.TestCase
    methods (Test)
        function sourceObjectiveTermsAndConstraintsMatch(testCase)
            dataRoot=fullfile(lmz.util.ProjectPaths.examples(),'data','slip_biped','trajectory_fit');
            manifest=jsondecode(fileread(fullfile(dataRoot,'fit_manifest.json')));
            if iscell(manifest.files)
                firstFile=manifest.files{1};secondFile=manifest.files{2};
            else
                firstFile=manifest.files(1);secondFile=manifest.files(2);
            end
            testCase.verifyEqual(lmz.util.FileHash.sha256(fullfile(dataRoot,firstFile.name)), ...
                firstFile.sha256);
            testCase.verifyEqual(lmz.util.FileHash.sha256(fullfile(dataRoot,secondFile.name)), ...
                secondFile.sha256);
            data=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
                'slip_biped','source_equivalence.mat'),'baseline');baseline=data.baseline;
            model=lmzmodels.slip_biped.Model();
            problem=model.createProblem('trajectory_fit',struct());
            context=lmz.api.RunContext.synchronous(77);u=problem.sourceSeed();p=problem.getParameterSchema().defaults();
            [objective,terms,diagnostics]=problem.evaluateObjective(u,p,context);
            [c,ceq]=problem.nonlinearConstraints(u,p,context);
            testCase.verifyEqual(objective,baseline.TrajectoryFit.Objective, ...
                'AbsTol',baseline.Tolerances.ObjectiveAbsolute);
            testCase.verifyEqual(terms.position_mismatch,baseline.TrajectoryFit.ObjectiveTerms.position, ...
                'AbsTol',baseline.Tolerances.ObjectiveAbsolute);
            testCase.verifyEqual(terms.event_timing_penalty,baseline.TrajectoryFit.ObjectiveTerms.eventTiming, ...
                'AbsTol',baseline.Tolerances.ObjectiveAbsolute);
            testCase.verifyEmpty(c);testCase.verifyEmpty(ceq);
            testCase.verifyEqual(diagnostics.TimingNormShape,[5 5]);
            constrained=model.createProblem('trajectory_fit',struct('EnforceConstraints',true));
            constrainedWeights=constrained.getParameterSchema().defaults();
            [constrainedObjective,constrainedTerms]=constrained.evaluateObjective( ...
                u,constrainedWeights,context);
            [c,ceq]=constrained.nonlinearConstraints(u,constrainedWeights,context);
            testCase.verifyEqual(constrainedObjective,baseline.TrajectoryFit.ConstrainedObjective, ...
                'AbsTol',baseline.Tolerances.ObjectiveAbsolute);
            testCase.verifyEqual(constrainedTerms.left_leg_angle_mismatch, ...
                baseline.TrajectoryFit.ConstrainedObjectiveTerms.leftAngle, ...
                'AbsTol',baseline.Tolerances.ObjectiveAbsolute);
            testCase.verifyEmpty(c);testCase.verifyEqual(ceq, ...
                baseline.TrajectoryFit.ConstraintResidual, ...
                'AbsTol',baseline.Tolerances.ResidualAbsolute);
        end
    end
end
