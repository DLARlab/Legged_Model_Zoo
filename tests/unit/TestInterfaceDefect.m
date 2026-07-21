classdef TestInterfaceDefect < matlab.unittest.TestCase
    methods (Test)
        function explicitScaledMismatchIsNamed(testCase)
            defect=lmz.shooting.InterfaceDefect(3,[2;4],[1;1], ...
                {'speed','height'},[0.5;3]);
            testCase.verifyEqual(defect.Values,[1;3]);
            testCase.verifyEqual(defect.norm(),sqrt(5),'AbsTol',1e-14);
            block=defect.toResidualBlock();
            testCase.verifyEqual(block.Name,'interface_3_defect');
            testCase.verifyEqual(block.scaled(),[2;1]);
        end
    end
end
