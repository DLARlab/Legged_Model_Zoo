classdef TestNStrideTimingSequence < matlab.unittest.TestCase
    %TESTNSTRIDETIMINGSEQUENCE Verify fixed-data timing sequence residuals.
    methods (Test)
        function stateAndPhysicsRemainFixed(testCase)
            configuration=struct('NumberOfStrides',2, ...
                'ExpectedLocalDimension',0);
            problem=lmz.multistride.ContactTimingSequenceProblem( ...
                lmzmodels.tutorial_hopper.Model(),timingSchema(), ...
                @TestNStrideTimingSequence.evaluateSequence,[1;0;1;0], ...
                [9.81;2],configuration);
            state=problem.FixedInitialState;
            parameters=problem.FixedPhysicalParameters;
            evaluation=problem.evaluate([.2;.4;.6;.8],[], ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyEqual(problem.FixedInitialState,state, ...
                'AbsTol',0);
            testCase.verifyEqual(problem.FixedPhysicalParameters,parameters, ...
                'AbsTol',0);
            testCase.verifyEqual(evaluation.Residual,[.2;.4;.6;.8]);
            testCase.verifyFalse( ...
                evaluation.Diagnostics.StatePeriodicityImposed);
            testCase.verifyFalse(evaluation.Diagnostics.HiddenTimingSolve);
        end

        function nestedSolverDeclarationIsRejected(testCase)
            configuration=struct('NumberOfStrides',2);
            problem=lmz.multistride.ContactTimingSequenceProblem( ...
                lmzmodels.tutorial_hopper.Model(),timingSchema(), ...
                @TestNStrideTimingSequence.hiddenSolve,[1;0;1;0], ...
                [9.81;2],configuration);
            action=@()problem.evaluate([.2;.4;.6;.8],[], ...
                lmz.api.RunContext.synchronous(0),false);
            testCase.verifyError(action,'lmz:MultiStride:HiddenTimingSolve');
        end
    end

    methods (Static)
        function value=evaluateSequence(u,state,parameters,~,~,contract)
            assert(isequal(state,[1;0;1;0]));
            assert(isequal(parameters,[9.81;2]));
            assert(~contract.StatePeriodicityImposed);
            value=struct();
            value.ContactResiduals={u(1);u(3)};
            value.SectionResiduals={u(2);u(4)};
        end

        function value=hiddenSolve(u,varargin) %#ok<INUSD>
            value=struct();
            value.ContactResiduals={u(1);u(3)};
            value.SectionResiduals={u(2);u(4)};
            value.Diagnostics=struct('HiddenTimingSolve',true);
        end
    end
end

function value=timingSchema()
specs=lmz.schema.VariableSpec.empty(0,1);
for index=1:4
    specs(index,1)=lmz.schema.VariableSpec(sprintf('timing_%d',index), ...
        'DefaultValue',.2*index,'Role','schedule', ...
        'EnergyEffect','invariant'); %#ok<AGROW>
end
value=lmz.schema.VariableSchema(specs);
end
