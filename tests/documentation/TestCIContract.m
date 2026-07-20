classdef TestCIContract < matlab.unittest.TestCase
    methods (Test)
        function workflowsUseReviewedOfficialActionsAndStayNonPublishing(testCase)
            root = lmz.util.ProjectPaths.root();
            workflowRoot = fullfile(root, '.github', 'workflows');
            names = {'static.yml', 'matlab.yml', 'release-audit.yml'};
            for index = 1:numel(names)
                testCase.verifyEqual(exist(fullfile(workflowRoot, names{index}), ...
                    'file'), 2, sprintf('%s is missing.', names{index}));
            end
            static = fileread(fullfile(workflowRoot, 'static.yml'));
            matlab = fileread(fullfile(workflowRoot, 'matlab.yml'));
            audit = fileread(fullfile(workflowRoot, 'release-audit.yml'));
            testCase.verifyNotEmpty(strfind(static, ... %#ok<STREMP>
                'python3 tools/ci/static_checks.py --all'));
            testCase.verifyEmpty(strfind(static, 'setup-matlab'));
            official = {'matlab-actions/setup-matlab@v3', ...
                'matlab-actions/run-command@v3', ...
                'matlab-actions/run-tests@v3'};
            for index = 1:numel(official)
                testCase.verifyNotEmpty(strfind(matlab, official{index}), ... %#ok<STREMP>
                    sprintf('MATLAB workflow is missing %s.', official{index}));
            end
            testCase.verifyNotEmpty(strfind(matlab, 'release: R2021a'));
            testCase.verifyNotEmpty(strfind(matlab, 'release: latest'));
            testCase.verifyNotEmpty(strfind(matlab, 'macos-latest'));
            testCase.verifyNotEmpty(strfind(matlab, ... %#ok<STREMP>
                'actions/upload-artifact@v4'));
            testCase.verifyNotEmpty(strfind(matlab, ... %#ok<STREMP>
                'test-results/results.xml'));
            testCase.verifyNotEmpty(strfind(matlab, ... %#ok<STREMP>
                'code-coverage/coverage.xml'));
            testCase.verifyEmpty(strfind([static audit], ... %#ok<STREMP>
                'actions/upload-artifact'));
            testCase.verifyEmpty(strfind(matlab, 'release/out'));
            combined = [static matlab audit];
            prohibited = {'softprops/action-gh-release', ...
                'gh release create', 'npm publish', 'twine upload'};
            for index = 1:numel(prohibited)
                testCase.verifyEmpty(strfind(combined, prohibited{index}), ... %#ok<STREMP>
                    'Release workflows must not publish automatically.');
            end
            testCase.verifyNotEmpty(strfind(audit, ... %#ok<STREMP>
                'build_release(''scientific'',struct(''DryRun'',true))'));
            testCase.verifyNotEmpty(strfind(audit, ... %#ok<STREMP>
                'build_release(''core'',struct(''Mode'',''technical-validation''))'));
            testCase.verifyNotEmpty(strfind(audit, ... %#ok<STREMP>
                'assert(~technical.Retained)'));
            testCase.verifyEqual(exist(fullfile(root, 'docs', 'CI.md'), 'file'), 2);
        end
    end
end
