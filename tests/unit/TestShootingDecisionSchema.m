classdef TestShootingDecisionSchema < matlab.unittest.TestCase
    methods (Test)
        function namedBindingsDecodeNodes(testCase)
            [~,horizon,schema,seed]= ...
                lmztest.makeAnalyticShootingProblem(2);
            testCase.verifyEqual(schema.names(), ...
                {'node_1_x';'node_2_x';'node_3_x'});
            edited=seed;edited(2)=3.25;
            decoded=schema.decode(edited,horizon);
            testCase.verifyEqual(decoded.Nodes{2}.SectionCoordinates,3.25);
            testCase.verifyEqual(decoded.Nodes{1}.SectionCoordinates,2);
            restored=lmz.shooting.ShootingDecisionSchema.fromStruct( ...
                schema.toStruct());
            testCase.verifyEqual(restored.names(),schema.names());
        end
    end
end
