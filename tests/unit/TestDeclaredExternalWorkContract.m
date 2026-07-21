classdef TestDeclaredExternalWorkContract < matlab.unittest.TestCase
    %TESTDECLAREDEXTERNALWORKCONTRACT Verify explicit work normalization.
    methods (Test)
        function genericPolicyAcceptsLegacyAndNamedForms(testCase)
            policy=lmz.multistride.EnergyConsistencyPolicy( ...
                'Id','declared_work');
            testCase.verifyEqual(policy.declaredExternalWork(2.5),2.5);
            testCase.verifyEqual(policy.declaredExternalWork( ...
                struct('DeclaredExternalWork',-1.25)),-1.25);
            testCase.verifyEqual(policy.declaredExternalWork( ...
                struct('DeclaredWork',.75)),.75);
            diagnostics=policy.assess(.75,struct('DeclaredWork',.75),true);
            testCase.verifyTrue(diagnostics.Accepted);
            testCase.verifyEqual(diagnostics.DeclaredWork,.75,'AbsTol',0);
        end

        function invalidOrUnknownWorkIsRejected(testCase)
            policy=lmz.multistride.EnergyConsistencyPolicy();
            testCase.verifyError(@()policy.declaredExternalWork(struct()), ...
                'lmz:MultiStride:DeclaredExternalWork');
            testCase.verifyError(@()policy.declaredExternalWork(Inf), ...
                'lmz:MultiStride:EnergyValue');
        end

        function quadLoadValidationRoutesThroughDeclaredContract(testCase)
            [plan,state]=sourcePlanAndState();
            before=plan.StrideSpecs(1);after=plan.StrideSpecs(2);
            policy=lmzmodels.slip_quad_load.QuadLoadEnergyPolicy( ...
                'Id','declared_work');
            [delta,~]=policy.parameterTransitionEnergy(state,before,after);
            diagnostics=policy.validateTransition(state,before,after, ...
                struct('DeclaredExternalWork',delta));
            testCase.verifyEqual(diagnostics.DeclaredWork,delta,'AbsTol',0);
            testCase.verifyEqual(diagnostics.Mismatch,0,'AbsTol',1e-12);
        end
    end
end

function [plan,state]=sourcePlanAndState()
catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
dataset=catalog.load(catalog.Manifest.defaultMultiStride);
plan=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan(dataset.XAccum);
state=plan.InitialState;
end
