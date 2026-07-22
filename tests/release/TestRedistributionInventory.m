classdef TestRedistributionInventory < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addReleaseTools(testCase)
            path=fullfile(lmz.util.ProjectPaths.root(),'tools','release');addpath(path);
            testCase.addTeardown(@()rmpath(path));
        end
    end
    methods (Test)
        function inventoryIsCompleteAndHashCurrent(testCase)
            [report,manifest]=scan_redistribution();
            testCase.verifyEqual(report.StructuralViolationCount,0);
            testCase.verifyEmpty(report.StaleHashes);
            testCase.verifyEmpty(report.MissingFiles);
            testCase.verifyEmpty(report.UnlistedFiles);
            testCase.verifyGreaterThan(numel(manifest.files),300);
        end

        function decisionsRemainHonestlyBlocked(testCase)
            [report,manifest]=scan_redistribution();
            testCase.verifyEqual(manifest.projectDecision.decisionStatus,'unresolved');
            testCase.verifyFalse(manifest.projectDecision.redistributable);
            testCase.verifyNotEmpty(report.BlockingFiles);
            categories={manifest.files.category};
            testCase.verifyTrue(any(strncmp(categories,'scientific-biped',16)));
            testCase.verifyTrue(any(strncmp(categories,'scientific-quadruped',20)));
            testCase.verifyTrue(any(strncmp(categories,'scientific-load',15)));
        end

        function localPromptsAreAbsentAndMaintainerToolsAreExcluded(testCase)
            [~,manifest]=scan_redistribution();entries=manifest.files;
            paths={entries.relativePath};
            testCase.verifyFalse(any(contains(paths,'Prompt.md')));
            categories={entries.category};
            indices=find(strcmp(categories,'maintainer-only-tool'));
            testCase.verifyNotEmpty(indices);
            for index=indices,testCase.verifyEmpty(entries(index).releaseRoles);end
        end

        function analyticTutorialShipsInBothProfilesButRemainsBlocked(testCase)
            [~,manifest]=scan_redistribution();entries=manifest.files;
            paths={entries.relativePath};
            expected={'catalog/tutorial_hopper/manifest.json', ...
                'models/+lmzmodels/+tutorial_hopper/Model.m', ...
                'examples/data/tutorial_hopper/default_hop.json', ...
                'examples/demo_tutorial_hopper.m'};
            for index=1:numel(expected)
                match=find(strcmp(paths,expected{index}),1);
                testCase.assertNotEmpty(match,sprintf('Missing %s.',expected{index}));
                testCase.verifyEqual(entries(match).category,'tutorial-analytic');
                testCase.verifyEqual(sort(entries(match).profiles(:)), ...
                    {'core';'scientific'});
                testCase.verifyEqual(entries(match).licenseId,'NOASSERTION');
                testCase.verifyEqual(entries(match).decisionStatus,'unresolved');
                testCase.verifyFalse(entries(match).redistributable);
            end
            [coreFiles,core]=release_file_list('core','source-zip');
            testCase.verifyFalse(core.Authorized);
            for index=1:numel(expected)
                testCase.verifyTrue(any(strcmp(coreFiles,expected{index})));
            end
        end

        function roundElevenCapturesRemainScientificOnly(testCase)
            [~,manifest]=scan_redistribution();entries=manifest.files;
            paths={entries.relativePath};
            indices=find(strncmp(paths,'docs/images/round11/',20)& ...
                endsWith(paths,'.png'));
            testCase.verifyNumElements(indices,8);
            for index=indices
                testCase.verifyEqual(entries(index).category, ...
                    'scientific-quadruped-derived');
                testCase.verifyEqual(entries(index).profiles,{'scientific'});
                testCase.verifyEqual(entries(index).generatedFrom, ...
                    {'examples/data/slip_quadruped/RoadMap/roadmap_manifest.json'});
                testCase.verifyEqual(entries(index).sourceRepository, ...
                    'https://github.com/DLARlab/SLIP_Model_Zoo.git');
                testCase.verifyEqual(entries(index).sourceCommit, ...
                    '2c106101383ecee1b2a9d695efe09fbd72d5718a');
                testCase.verifyEqual(entries(index).licenseId,'NOASSERTION');
                testCase.verifyEqual(entries(index).requiredNotice, ...
                    'Quadruped owner redistribution decision required.');
                testCase.verifyEqual(entries(index).decisionStatus,'unresolved');
                testCase.verifyFalse(entries(index).redistributable);
            end
            [coreFiles,~]=release_file_list('core','source-zip');
            coreCaptures=strncmp(coreFiles, ...
                'docs/images/round11/',20)&endsWith(coreFiles,'.png');
            testCase.verifyFalse(any(coreCaptures));
            [coreToolboxFiles,~]=release_file_list('core','toolbox');
            coreToolboxCaptures=strncmp(coreToolboxFiles, ...
                'docs/images/round11/',20)&endsWith(coreToolboxFiles,'.png');
            testCase.verifyFalse(any(coreToolboxCaptures));
        end
    end
end
