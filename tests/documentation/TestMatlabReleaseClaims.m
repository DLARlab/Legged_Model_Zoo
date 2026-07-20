classdef TestMatlabReleaseClaims < matlab.unittest.TestCase
    methods (Test)
        function documentationSeparatesTargetFromRuntimeEvidence(testCase)
            root = lmz.util.ProjectPaths.root();
            path = fullfile(root, 'docs', 'MATLAB_RELEASE_MATRIX.md');
            testCase.verifyEqual(exist(path, 'file'), 2);
            text = fileread(path);
            required = {'R2025b Update 5', 'R2021a', 'R2019b', ...
                'Designed for MATLAB R2019b compatibility', ...
                'runtime-verified on R2025b', ...
                'remote CI not yet run', ...
                '/Applications/MATLAB_R2025b.app'};
            for index = 1:numel(required)
                testCase.verifyNotEmpty(strfind(text, required{index})); %#ok<STREMP>
            end
        end
    end
end
