classdef TestNStridePeriodicProblem < matlab.unittest.TestCase
    %TESTNSTRIDEPERIODICPROBLEM Verify final-return-only residual contracts.
    methods (Test)
        function finalClosureIsAppliedOnlyAfterLastStride(testCase)
            schema=twoVariableSchema();
            configuration=struct('NumberOfStrides',2, ...
                'TimingMode','explicit_variables');
            problem=lmz.multistride.NStridePeriodicProblem( ...
                lmzmodels.tutorial_hopper.Model(),schema,emptySchema(),[], ...
                @TestNStridePeriodicProblem.periodicEvaluation,configuration);
            evaluation=problem.evaluate([2;3],[], ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyEqual(evaluation.Residual,[2;3;-1]);
            names=arrayfun(@(value)value.Name,evaluation.ResidualBlocks, ...
                'UniformOutput',false);
            testCase.verifyEqual(names,{'stride_1_contact_constraints'; ...
                'stride_2_contact_constraints';'final_section_closure'});
            testCase.verifyFalse( ...
                evaluation.Diagnostics.IntermediatePeriodicityImposed);
            testCase.verifyTrue( ...
                evaluation.Diagnostics.FinalReturnClosureOnly);
            testCase.verifyFalse(evaluation.Diagnostics.HiddenTimingSolve);
        end

        function fixedTimingRequiresCompletionEvidence(testCase)
            schema=twoVariableSchema();
            configuration=struct('NumberOfStrides',2);
            constructor=@()lmz.multistride.NStridePeriodicProblem( ...
                lmzmodels.tutorial_hopper.Model(),schema,emptySchema(),[], ...
                @TestNStridePeriodicProblem.periodicEvaluation,configuration);
            testCase.verifyError(constructor,'lmz:MultiStride:TimingEvidence');
        end

        function nestedTimingSolveDeclarationIsRejected(testCase)
            configuration=struct('NumberOfStrides',2, ...
                'TimingMode','explicit_variables');
            problem=lmz.multistride.NStridePeriodicProblem( ...
                lmzmodels.tutorial_hopper.Model(),twoVariableSchema(), ...
                emptySchema(),[], ...
                @TestNStridePeriodicProblem.hiddenSolveEvaluation, ...
                configuration);
            action=@()problem.evaluate([2;3],[], ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyError(action,'lmz:MultiStride:HiddenTimingSolve');
        end

        function transitionUsesOnlyFinalTargetConstraint(testCase)
            configuration=struct('NumberOfStrides',2, ...
                'TimingMode','explicit_variables');
            problem=lmz.multistride.NStrideTransitionProblem( ...
                lmzmodels.tutorial_hopper.Model(),twoVariableSchema(), ...
                emptySchema(),[], ...
                @TestNStridePeriodicProblem.transitionEvaluation, ...
                configuration);
            evaluation=problem.evaluate([2;3],[], ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyEqual(evaluation.Residual,[2;3;5]);
            testCase.verifyFalse( ...
                evaluation.Diagnostics.IntermediatePeriodicityImposed);
        end
    end

    methods (Static)
        function value=periodicEvaluation(u,~,~,~,contract)
            assert(contract.FinalReturnClosureOnly);
            value=struct();
            value.ContactResiduals={u(1);u(2)};
            value.FinalClosureResidual=u(1)-u(2);
        end

        function value=hiddenSolveEvaluation(u,varargin) %#ok<INUSD>
            value=struct('ContactResiduals',{{u(1);u(2)}}, ...
                'FinalClosureResidual',u(1)-u(2), ...
                'Diagnostics',struct('HiddenTimingSolve',true));
        end

        function value=transitionEvaluation(u,varargin) %#ok<INUSD>
            value=struct();
            value.ContactResiduals={u(1);u(2)};
            value.FinalTargetResidual=sum(u);
        end
    end
end

function value=twoVariableSchema()
value=lmz.schema.VariableSchema([ ...
    lmz.schema.VariableSpec('first','DefaultValue',2); ...
    lmz.schema.VariableSpec('second','DefaultValue',3)]);
end

function value=emptySchema()
value=lmz.schema.VariableSchema(lmz.schema.VariableSpec.empty(0,1));
end
