classdef TestHorizonContinuationDimensionEmbedding < matlab.unittest.TestCase
    methods (Test)
        function nameBoundEmbeddingAddsOnlyNewInterface(testCase)
            [~,~,oldSchema,oldSeed]= ...
                lmztest.makeAnalyticShootingProblem(1, ...
                'NodeValues',[1;1.5]);
            [~,~,newSchema]=lmztest.makeAnalyticShootingProblem(2, ...
                'NodeValues',[1;1.5;2]);
            [embedded,record]=lmz.shooting.HorizonContinuation(). ...
                embedDecision(oldSchema,oldSeed,newSchema);
            testCase.verifyEqual(embedded,[1;1.5;2]);
            testCase.verifyEqual(record.OldDimension,2);
            testCase.verifyEqual(record.NewDimension,3);
            testCase.verifyEqual(record.AddedNames,{'node_3_x'});
        end
    end
end
