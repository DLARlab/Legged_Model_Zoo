classdef TestQuadLoadFixedControlFeasibilityReport < matlab.unittest.TestCase
    methods (Test)
        function bestKnownCaseAIsQualifiedWithoutInfeasibilityClaim(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            record=evidence.caseRecord('case_a_fixed_controls_best_known');
            replay=evidence.replay(record.id, ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyEqual(record.jacobianRankEstimate,69);
            testCase.verifyEqual(replay.ScaledResidualNorm, ...
                record.scaledResidualNorm,'AbsTol',1e-12);
            testCase.verifyEqual(replay.BlockNames,record.blockNames);
            testCase.verifyEqual(replay.BlockScaledNorms, ...
                record.blockScaledNorms(:),'AbsTol',1e-12);
            testCase.verifyTrue(replay.StoredBlockNamesMatch);
            testCase.verifyTrue(replay.StoredBlockNormsMatch);
            testCase.verifyFalse(replay.RootFound);
            testCase.verifyFalse(replay.PhysicalValidity);
            testCase.verifyEqual(replay.Classification, ...
                'physical_validation_failure');
            testCase.verifyTrue(replay.StoredClassificationMatch);
            testCase.verifyFalse(record.globalInfeasibilityClaimed);
            testCase.verifyLessThan(record.minimumQuadrupedYBySegment(3),0);
            testCase.verifyFalse(record.simulationPublished);
            attempts=evidence.attempts(record.id);
            testCase.verifyNumElements(attempts,2);
            testCase.verifyEqual(cellfun(@(item)item.scaledResidualNorm, ...
                attempts),record.multistartScaledResidualNorms(:), ...
                'AbsTol',0);
            testCase.verifyTrue(record.formalAttemptsComplete);
            testCase.verifyEqual(attempts{1}.seedDerivation, ...
                'exact vector retained in deterministicReplaySeed');
            testCase.verifyEqual(attempts{1}.solver.name,'lsqnonlin');
            testCase.verifyEqual(attempts{1}.solver. ...
                maxFunctionEvaluations,800);
            testCase.verifyEqual(attempts{1}.exitFlag,4);
            testCase.verifyEqual(attempts{1}.terminationReason, ...
                'solver_terminated_acceptable');
            historical=num2cell(record.historicalExploratoryAttempts);
            historical=historical(:);
            testCase.verifyNumElements(historical,2);
            testCase.verifyTrue(all(cellfun(@(item)~item.gating, ...
                historical)));
            testCase.verifyTrue(all(cellfun(@(item)strcmp( ...
                item.provenanceStatus,'incomplete'),historical)));
            testCase.verifyEqual(historical{1}.seedDerivation, ...
                'unknown_not_retained');
            testCase.verifyEqual(record.nullity,0);
            testCase.verifyNumElements(record.singularValues,69);
            testCase.verifyGreaterThan(record.conditionEstimate,1e10);
        end

        function energyNeutralMultistartAttemptsAreExplicit(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            record=evidence.caseRecord( ...
                'case_b_energy_neutral_controls_best_known');
            replay=evidence.replay(record.id, ...
                lmz.api.RunContext.synchronous(0),false);
            attempts=evidence.attempts(record.id);
            testCase.verifyNumElements(attempts,2);
            testCase.verifyEqual(cellfun(@(item)item.scaledResidualNorm, ...
                attempts),record.multistartScaledResidualNorms(:), ...
                'AbsTol',0);
            testCase.verifyTrue(record.formalAttemptsComplete);
            testCase.verifyEqual(attempts{1}.seedDerivation, ...
                'exact case decision vector');
            testCase.verifyEqual(attempts{1}.solver. ...
                maxFunctionEvaluations,800);
            historical=num2cell(record.historicalExploratoryAttempts);
            historical=historical(:);
            testCase.verifyTrue(all(cellfun(@(item)~item.gating, ...
                historical)));
            testCase.verifyEqual(replay.BlockNames,record.blockNames);
            testCase.verifyEqual(replay.BlockScaledNorms, ...
                record.blockScaledNorms(:),'AbsTol',1e-12);
            testCase.verifyTrue(replay.StoredBlockNamesMatch);
            testCase.verifyTrue(replay.StoredBlockNormsMatch);
            testCase.verifyEqual(replay.Classification, ...
                'physical_validation_failure');
            testCase.verifyTrue(replay.StoredClassificationMatch);
        end

        function rectangularFeasibleAnalysisIsNotAnIsolatedRoot(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            sourceRecord=evidence.caseRecord( ...
                'n2_transition_feasibility_root');
            [source,sourceDecision]=evidence.problemFor(sourceRecord.id);
            configuration=evidence.configuration(sourceRecord);
            mask=false(2,4);mask(2,1)=true;
            configuration.FreeControlMask=mask;
            configuration.ExpectedLocalDimension=1;
            problem=lmzmodels.slip_quad_load. ...
                QuadLoadMultipleShootingProblem([],configuration);
            [decision,~]=lmz.shooting.HorizonContinuation(). ...
                embedDecision(source.ShootingSchema,sourceDecision, ...
                problem.ShootingSchema);
            report=problem.analyze(decision, ...
                lmz.api.RunContext.synchronous(0),struct( ...
                'ComputeJacobian',false,'SolverExitFlag',1));

            testCase.verifyEqual(report.ResidualCount,46);
            testCase.verifyEqual(report.UnknownCount,47);
            testCase.verifyEqual(report.Classification, ...
                'least_squares_feasible');
            testCase.verifyTrue(report.LeastSquaresFeasible);
            testCase.verifyTrue(report.Success);
            testCase.verifyFalse(report.RootFound);
            testCase.verifyFalse(report.AnalysisOnly);
            testCase.verifyTrue(report.SolverTerminationAcceptable);
            testCase.verifyNotEmpty(report.ClassificationQualification);
        end

        function unacceptableTerminationCannotClaimStoredRoot(testCase)
            evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
            [problem,decision]=evidence.problemFor( ...
                'n2_transition_feasibility_root');
            report=problem.analyze(decision, ...
                lmz.api.RunContext.synchronous(0),struct( ...
                'ComputeJacobian',false,'SolverExitFlag',0, ...
                'TerminationReason','iteration_or_evaluation_limit'));

            testCase.verifyEqual(report.Classification, ...
                'numerical_failure');
            testCase.verifyFalse(report.RootFound);
            testCase.verifyFalse(report.Success);
            testCase.verifyFalse(report.AnalysisOnly);
            testCase.verifyFalse(report.SolverTerminationAcceptable);

            analysis=problem.analyze(decision, ...
                lmz.api.RunContext.synchronous(0),struct( ...
                'ComputeJacobian',false));
            testCase.verifyEqual(analysis.Classification, ...
                'best_known_residual');
            testCase.verifyFalse(analysis.RootFound);
            testCase.verifyFalse(analysis.Success);
            testCase.verifyTrue(analysis.AnalysisOnly);
            testCase.verifyFalse(analysis.SolverTerminationAcceptable);
        end
    end
end
