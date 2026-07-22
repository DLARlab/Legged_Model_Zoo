classdef TestVersion < matlab.unittest.TestCase
    methods (Test)
        function currentMatchesVersionFile(testCase)
            expected=strtrim(fileread(fullfile(lmz.util.ProjectPaths.root(),'VERSION')));
            testCase.verifyEqual(lmz.util.Version.current(),expected);
            testCase.verifyEqual(expected,'1.0.0-rc.3');
        end

        function parsesSemanticVersion(testCase)
            value=lmz.util.Version.parse('1.2.3-rc.4+build.9');
            testCase.verifyEqual([value.Major value.Minor value.Patch],[1 2 3]);
            testCase.verifyEqual(value.Prerelease,{'rc','4'});
            testCase.verifyEqual(value.Build,{'build','9'});
        end

        function comparesSemanticPrecedence(testCase)
            ordered={'1.0.0-alpha','1.0.0-alpha.1','1.0.0-alpha.beta', ...
                '1.0.0-beta','1.0.0-beta.2','1.0.0-beta.11', ...
                '1.0.0-rc.1','1.0.0-rc.2','1.0.0-rc.3','1.0.0'};
            for index=1:numel(ordered)-1
                testCase.verifyLessThan(lmz.util.Version.compare( ...
                    ordered{index},ordered{index+1}),0);
            end
            testCase.verifyEqual(lmz.util.Version.compare( ...
                '1.2.3+one','1.2.3+two'),0);
        end

        function compatibilityUsesSemanticLine(testCase)
            testCase.verifyTrue(lmz.util.Version.isCompatible('1.4.0','1.2.3'));
            testCase.verifyFalse(lmz.util.Version.isCompatible('2.0.0','1.2.3'));
            testCase.verifyFalse(lmz.util.Version.isCompatible('0.3.1','0.2.9'));
            testCase.verifyTrue(lmz.util.Version.isCompatible('0.2.9','0.2.1'));
        end

        function rejectsMalformedVersions(testCase)
            invalid={'1','1.2','01.2.3','1.02.3','1.2.03','1.0.0-01','v1.0.0'};
            for index=1:numel(invalid)
                testCase.verifyError(@()lmz.util.Version.parse(invalid{index}), ...
                    'lmz:Version:InvalidSemanticVersion');
            end
        end

        function persistentFormatVersionsAreFrozen(testCase)
            testCase.verifyEqual(lmz.util.Version.artifactSchemaVersion(),'1.0.0');
            testCase.verifyEqual(lmz.util.Version.catalogSchemaVersion(),'1.0.0');
            testCase.verifyEqual(lmz.util.Version.minimumMatlabRelease(),'R2019b');
        end
    end
end
