classdef TestCommittedHeadStatusContract < matlab.unittest.TestCase
    methods (Test)
        function releaseStatusRecordsCommittedRoundHistory(testCase)
            root=lmz.util.ProjectPaths.root();
            status=fileread(fullfile(root,'docs', ...
                'RELEASE_CANDIDATE_STATUS.md'));
            required={'c2616735354a354fa432bac549f81861f8ddd9a5', ...
                'c0d87860b59cfbdffe96e165cd01c68e2de7d948', ...
                'Round 8 closing HEAD','Round 9 closing HEAD','committed'};
            for index=1:numel(required)
                testCase.verifyNotEmpty(strfind(status,required{index}), ... %#ok<STREMP>
                    sprintf('Release status misses %s.',required{index}));
            end
            stale=['the requested implementation remains an uncommitted ' ...
                'worktree change'];
            testCase.verifyEmpty(strfind(status,stale));
        end

        function roundTenLocalGateIsClosedAndExternallyQualified(testCase)
            root=lmz.util.ProjectPaths.root();
            paths={'docs/RELEASE_CANDIDATE_STATUS.md', ...
                'docs/TEST_STATUS.md','MIGRATION_STATUS.md','CHANGELOG.md', ...
                'README.md','docs/RELEASE_NOTES_1_0.md'};
            for index=1:numel(paths)
                content=fileread(fullfile(root,paths{index}));
                testCase.verifyNotEmpty(strfind(content,'Round 10'), ... %#ok<STREMP>
                    sprintf('%s misses Round 10.',paths{index}));
                testCase.verifyNotEmpty(strfind(content, ... %#ok<STREMP>
                    'ROUND10_LOCAL_AUTOMATION_PASSED'), ...
                    sprintf('%s misses the local-close marker.',paths{index}));
            end
            status=fileread(fullfile(root,'docs', ...
                'RELEASE_CANDIDATE_STATUS.md'));
            qualifiers={'remote CI','human desktop','R2019b runtime', ...
                'redistribution authority'};
            lowerStatus=lower(status);
            for index=1:numel(qualifiers)
                testCase.verifyNotEmpty(strfind(lowerStatus, ... %#ok<STREMP>
                    lower(qualifiers{index})),qualifiers{index});
            end
            combined='';
            for index=1:numel(paths)
                combined=[combined fileread(fullfile(root,paths{index}))]; %#ok<AGROW>
            end
            required={'544/544','19,973/25,363','932','917', ...
                'not an authorized public release'};
            for index=1:numel(required)
                testCase.verifyNotEmpty(strfind(combined,required{index}), ... %#ok<STREMP>
                    sprintf('Round 10 close misses %s.',required{index}));
            end
            stale={'Round 10 closing evidence is **PENDING**', ...
                'aggregate release gates are still **PENDING**', ...
                'Round 10 closing automation PENDING', ...
                'Round 10 aggregates above remain **PENDING**'};
            for index=1:numel(stale)
                testCase.verifyEmpty(strfind(combined,stale{index}), ... %#ok<STREMP>
                    sprintf('Stale Round 10 status remains: %s.',stale{index}));
            end
        end
    end
end
