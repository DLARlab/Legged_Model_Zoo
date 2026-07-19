classdef TestArchitectureRules < matlab.unittest.TestCase
    methods (Test)
        function staticRules(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            report=static_architecture_check(root); testCase.verifyEmpty(report);
        end
    end
end
