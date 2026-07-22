classdef TestContinuationCallbackPayloads < matlab.unittest.TestCase
    methods (Test)
        function predictionAndAcceptedCallbacksCarryGenericDiagnostics(testCase)
            [problem,pair,context]=makeAnalyticContinuationCase(735);
            predictionState=[];acceptedState=[];
            lmz.services.ContinuationService().run(problem,pair,struct( ...
                'MaximumPoints',3,'BothDirections',false, ...
                'InitialStep',0.05,'MaximumStep',0.05, ...
                'PredictionFcn',@recordPrediction, ...
                'AcceptedFcn',@recordAccepted),context);

            testCase.verifyTrue(isstruct(predictionState));
            testCase.verifyTrue(isstruct(acceptedState));
            verifyCoordinateContract(testCase,predictionState,{'x','y'});
            verifyCoordinateContract(testCase,acceptedState,{'x','y'});
            testCase.verifyEqual(predictionState.ActiveDecision, ...
                pair.Second.DecisionValues,'AbsTol',0);
            testCase.verifyEqual(predictionState.Prediction, ...
                predictionState.DecisionValues,'AbsTol',0);
            testCase.verifyEmpty(predictionState.CorrectedDecision);
            testCase.verifyEqual(predictionState.Gait, ...
                pair.Second.Classification);
            testCase.verifyEqual(predictionState.Feasibility, ...
                pair.Second.Feasibility);
            testCase.verifyEqual(acceptedState.CorrectedDecision, ...
                acceptedState.Solution.DecisionValues,'AbsTol',0);
            testCase.verifyEqual(acceptedState.Gait, ...
                acceptedState.Solution.Classification);
            testCase.verifyEqual(acceptedState.Feasibility, ...
                acceptedState.Solution.Feasibility);

            function recordPrediction(state)
                predictionState=state;
            end
            function recordAccepted(state)
                acceptedState=state;
            end
        end

        function rejectedCallbackCarriesEvaluatedCandidateDiagnostics(testCase)
            [problem,pair,context]=makeAnalyticContinuationCase(736);
            rejectedState=[];
            lmz.services.ContinuationService().run(problem,pair,struct( ...
                'MaximumPoints',3,'BothDirections',false, ...
                'InitialStep',0.05,'MaximumStep',0.05, ...
                'MaxBacktracks',1,'AcceptanceFcn',@(~,~)false, ...
                'RejectedFcn',@recordRejected),context);

            testCase.verifyTrue(isstruct(rejectedState));
            verifyCoordinateContract(testCase,rejectedState,{'x','y'});
            testCase.verifyEqual(rejectedState.ActiveDecision, ...
                pair.Second.DecisionValues,'AbsTol',0);
            testCase.verifyEqual( ...
                rejectedState.CoordinateDiagnostics.Predicted, ...
                rejectedState.Prediction,'AbsTol',0);
            testCase.verifyEqual( ...
                rejectedState.CoordinateDiagnostics.Corrected, ...
                rejectedState.CorrectedDecision,'AbsTol',0);
            testCase.verifyEqual(rejectedState.Reason,'acceptance-policy');
            testCase.verifyTrue(rejectedState.Feasibility.Valid);
            testCase.verifyTrue(isstruct(rejectedState.Gait));

            function recordRejected(state)
                rejectedState=state;
            end
        end
    end
end

function verifyCoordinateContract(testCase,state,names)
required={'ActiveDecision','Prediction','CorrectedDecision', ...
    'CoordinateDiagnostics','Gait','Feasibility'};
for index=1:numel(required)
    testCase.verifyTrue(isfield(state,required{index}), ...
        sprintf('Missing callback field %s.',required{index}));
end
coordinates=state.CoordinateDiagnostics;
testCase.verifyEqual(coordinates.Names,names(:));
testCase.verifyEqual(coordinates.Active,state.ActiveDecision,'AbsTol',0);
testCase.verifyEqual(coordinates.Predicted,state.Prediction,'AbsTol',0);
testCase.verifyEqual(coordinates.Corrected,state.CorrectedDecision,'AbsTol',0);
end
