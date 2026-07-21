classdef TestNStrideOptimizationDecisionSchema < matlab.unittest.TestCase
    %TESTNSTRIDEOPTIMIZATIONDECISIONSCHEMA Verify complete-plan schema sizing.
    methods (Test)
        function oneTwoAndThreeStrideLengthsAreExact(testCase)
            model=lmzmodels.slip_quad_load.Model();
            one=model.createProblem('n_stride_fit', ...
                struct('NumberOfStrides',1));
            two=model.createProblem('n_stride_fit',struct());
            threeDecision=[two.SourceDecision;two.SourceDecision(end-12:end)];
            missingPolicy=@()model.createProblem('n_stride_fit',struct( ...
                'InitialDecision',threeDecision,'NumberOfStrides',3));
            testCase.verifyError(missingPolicy, ...
                'lmz:MultiStride:ReferenceExtensionRequired');
            three=model.createProblem('n_stride_fit',struct( ...
                'InitialDecision',threeDecision,'NumberOfStrides',3, ...
                'ReferenceExtensionPolicy','repeat_final_reference'));
            testCase.verifyEqual(one.getDecisionSchema().count(),44);
            testCase.verifyEqual(two.getDecisionSchema().count(),57);
            testCase.verifyEqual(three.getDecisionSchema().count(),70);
            testCase.verifyEqual(numel(three.ActiveOptimizationIndices),8);
            testCase.verifyFalse(three.SourceEquivalent);
            testCase.verifyEqual(three.getDescriptor().maturity,'experimental');
        end

        function extendedObjectiveLabelsSyntheticReferences(testCase)
            model=lmzmodels.slip_quad_load.Model();
            two=model.createProblem('n_stride_fit',struct());
            decision=[two.SourceDecision;two.SourceDecision(end-12:end)];
            problem=model.createProblem('n_stride_fit',struct( ...
                'InitialDecision',decision,'ReferenceExtensionPolicy', ...
                'repeat_final_reference'));
            [value,~,diagnostics]=problem.evaluateObjective( ...
                problem.getDecisionSchema().defaults(), ...
                problem.getParameterSchema().defaults(), ...
                lmz.api.RunContext.synchronous(0));
            testCase.verifyTrue(isfinite(value));
            testCase.verifyEqual(diagnostics.ReferenceExtensionPolicy, ...
                'repeat_final_reference');
            testCase.verifyFalse(diagnostics.RepeatedReferenceIsMeasuredData);
            testCase.verifyFalse(diagnostics.SourceEquivalent);
            testCase.verifyTrue(diagnostics.StridePlanComplete);
            testCase.verifyFalse(diagnostics.HiddenTimingSolve);
        end

        function incompletePlanIsRejectedBeforeOptimization(testCase)
            model=lmzmodels.slip_quad_load.Model();
            two=model.createProblem('n_stride_fit',struct());
            incomplete=two.StridePlan.withRequestedStrideCount(3);
            action=@()model.createProblem('n_stride_fit',struct( ...
                'StridePlan',incomplete,'NumberOfStrides',3, ...
                'ReferenceExtensionPolicy','repeat_final_reference'));
            testCase.verifyError(action, ...
                'lmz:MultiStride:OptimizationPlanIncomplete');
        end


        function fixedSeedHasExplicitFeasibleContactConstraints(testCase)
            problem=lmzmodels.slip_quad_load.Model().createProblem( ...
                'n_stride_fit',struct('InitialPerturbation',0));
            parameters=problem.getParameterSchema().defaults();
            [inequality,equality]=problem.nonlinearConstraints( ...
                problem.sourceSeed(),parameters, ...
                lmz.api.RunContext.synchronous(0));
            testCase.verifyEmpty(inequality);
            testCase.verifyEqual(numel(equality),18);
            testCase.verifyLessThan(norm(equality),2e-11);
            [lower,upper]=problem.bounds();
            roles={problem.getDecisionSchema().Specs.Role};
            schedule=find(strcmp(roles,'schedule'));
            testCase.verifyEqual(lower(schedule),upper(schedule), ...
                'AbsTol',0);
        end
    end
end
