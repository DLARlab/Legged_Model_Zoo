classdef TestVersionRc2Migration < matlab.unittest.TestCase
    methods (Test)
        function frameworkVersionAdvancesWithoutSchemaChange(testCase)
            testCase.verifyEqual(lmz.util.Version.current(),'1.0.0-rc.2');
            parsed=lmz.util.Version.parse(lmz.util.Version.current());
            testCase.verifyEqual(parsed.Prerelease,{'rc','2'});
            testCase.verifyGreaterThan(lmz.util.Version.compare( ...
                '1.0.0-rc.2','1.0.0-rc.1'),0);
            testCase.verifyLessThan(lmz.util.Version.compare( ...
                '1.0.0-rc.2','1.0.0'),0);
            testCase.verifyEqual( ...
                lmz.util.Version.artifactSchemaVersion(),'1.0.0');
            testCase.verifyEqual( ...
                lmz.util.Version.catalogSchemaVersion(),'1.0.0');
        end

        function newArtifactMetadataCarriesRc2(testCase)
            problem=lmztest.AnalyticModel().createProblem('line',struct());
            solution=problem.makeSolution( ...
                problem.getDecisionSchema().defaults(),[],[]);
            artifact=solution.toArtifact();
            testCase.verifyEqual(artifact.frameworkVersion,'1.0.0-rc.2');
            testCase.verifyEqual(artifact.schemaVersion,'1.0.0');
            testCase.verifyEqual(artifact.artifactSchemaVersion,'1.0.0');
            lmz.io.ArtifactStore.validate(artifact);
        end

        function publicReleaseRecordsNameRc2(testCase)
            root=lmz.util.ProjectPaths.root();
            paths={'CITATION.cff','docs/API_STABILITY.md', ...
                'docs/RELEASE_NOTES_1_0.md'};
            for index=1:numel(paths)
                content=fileread(fullfile(root,paths{index}));
                testCase.verifyNotEmpty(strfind(content,'1.0.0-rc.2'), ... %#ok<STREMP>
                    sprintf('%s does not name rc.2.',paths{index}));
            end
        end

        function quadLoadExampleFacadesAreExplicitlyProvisional(testCase)
            root=lmz.util.ProjectPaths.root();
            content=fileread(fullfile(root,'docs','API_STABILITY.md'));
            names={'StrideTemplateLibrary','QuadLoadFeasibilityEvidence', ...
                'QuadLoadMultipleShootingProblem', ...
                'QuadLoadHorizonContinuation'};
            for index=1:numel(names)
                testCase.verifyNotEmpty(strfind(content,names{index}), ... %#ok<STREMP>
                    sprintf('API stability misses %s.',names{index}));
            end
            testCase.verifyNotEmpty(strfind(content, ... %#ok<STREMP>
                'provisional public APIs'));
            testCase.verifyNotEmpty(strfind(content, ... %#ok<STREMP>
                'SectionSimulationAdapter'));
            testCase.verifyNotEmpty(strfind(content, ... %#ok<STREMP>
                'FeasibilityReport'));
        end
    end
end
