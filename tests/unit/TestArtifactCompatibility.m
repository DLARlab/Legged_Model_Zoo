classdef TestArtifactCompatibility < matlab.unittest.TestCase
    methods (Test)
        function newArtifactsCarryReleaseMetadata(testCase)
            problem=lmztest.AnalyticModel().createProblem('line',struct());
            solution=problem.makeSolution(problem.getDecisionSchema().defaults(),[],[]);
            artifact=solution.toArtifact();
            testCase.verifyEqual(artifact.frameworkVersion,lmz.util.Version.current());
            testCase.verifyEqual(artifact.artifactSchemaVersion,'1.0.0');
            testCase.verifyEqual(artifact.schemaVersion,'1.0.0');
            testCase.verifyEqual(artifact.modelVersion,solution.ModelVersion);
            testCase.verifyEqual(artifact.problemVersion,solution.ProblemVersion);
            testCase.verifyEqual(artifact.minimumMatlabRelease,'R2019b');
            lmz.io.ArtifactStore.validate(artifact);
        end

        function roundFiveAndSixArtifactsRemainReadable(testCase)
            root=lmz.util.ProjectPaths.root();
            paths={ ...
                fullfile(root,'examples','data','slip_quadruped','RoadMap', ...
                    'native','PK_20_2.lmz.mat'), ...
                fullfile(root,'examples','data','slip_biped','GaitMap', ...
                    'native','W1.lmz.mat'), ...
                fullfile(root,'examples','data','slip_quad_load','Scientific', ...
                    'native','P4_TR_RL_Individual_1.lmz.mat')};
            expected={'slip_quadruped','slip_biped','slip_quad_load'};
            for index=1:numel(paths)
                artifact=lmz.io.ArtifactStore.load(paths{index});
                testCase.verifyEqual(artifact.schemaVersion,'1.0.0');
                testCase.verifyEqual(artifact.modelId,expected{index});
            end
        end

        function legacyMetadataRemainsValid(testCase)
            artifact=TestArtifactCompatibility.makeTestArtifact();
            testCase.verifyFalse(isfield(artifact,'frameworkVersion'));
            lmz.io.ArtifactStore.validate(artifact);
        end

        function partialNewMetadataIsRejected(testCase)
            artifact=TestArtifactCompatibility.makeTestArtifact();
            artifact.frameworkVersion='1.0.0-rc.1';
            testCase.verifyError(@()lmz.io.ArtifactStore.validate(artifact), ...
                'lmz:Artifact:IncompleteVersionMetadata');
        end

        function unsupportedFutureSchemaIsRejected(testCase)
            artifact=TestArtifactCompatibility.makeTestArtifact();
            artifact.schemaVersion='2.0.0';
            testCase.verifyError(@()lmz.io.ArtifactStore.validate(artifact), ...
                'lmz:Artifact:UnsupportedVersion');
        end

        function solveRunCarriesReproductionMetadata(testCase)
            model=lmztest.AnalyticModel();problem=model.createProblem('line',struct());
            seed=problem.makeSolution([0;0],[],[]);
            evaluation=problem.evaluate(seed.DecisionValues,[], ...
                lmz.api.RunContext.synchronous(17),false);
            solved=lmz.data.SolveResult(seed,evaluation,1, ...
                struct('funcCount',3,'iterations',1), ...
                struct('MaxIterations',4),seed.toStruct(),17, ...
                struct('solver','test','elapsedTime',0.25,'evaluations',3));
            artifact=solved.toArtifact();
            required={'frameworkVersion','modelVersion','problemVersion', ...
                'matlabRelease','toolboxes','randomSeed','options', ...
                'sourceSeed','sourceArtifactId','sourceDataHashes', ...
                'elapsedTime','functionEvaluations','terminationReason','warnings'};
            for index=1:numel(required)
                testCase.verifyTrue(isfield(artifact,required{index}),required{index});
            end
            testCase.verifyEqual(artifact.randomSeed,17);
            testCase.verifyEqual(artifact.functionEvaluations,3);
            testCase.verifyEqual(artifact.elapsedTime,0.25);
            testCase.verifyEqual(artifact.sourceArtifactId,seed.Id);
            testCase.verifyEqual(artifact.terminationReason,'converged');
            lmz.io.ArtifactStore.validate(artifact);
        end

        function runMetadataCollectsAndOverridesSourceHashes(testCase)
            artifact=TestArtifactCompatibility.makeTestArtifact();
            details=struct('SourceSeed',struct('Id','seed-1', ...
                'Provenance',struct('SourceHash',repmat('a',1,64), ...
                'SourceCommit',repmat('b',1,40))), ...
                'SourceDataHashes',struct('DatasetSHA256',repmat('c',1,64)), ...
                'SourceCommitSHAs',struct('DatasetCommit',repmat('d',1,40)));
            artifact=lmz.io.ArtifactStore.withRunMetadata(artifact,details);
            hashes=struct2cell(artifact.sourceDataHashes);
            commits=struct2cell(artifact.sourceCommitSHAs);
            testCase.verifyTrue(any(strcmp(hashes,repmat('a',1,64))));
            testCase.verifyTrue(any(strcmp(hashes,repmat('c',1,64))));
            testCase.verifyTrue(any(strcmp(commits,repmat('b',1,40))));
            testCase.verifyTrue(any(strcmp(commits,repmat('d',1,40))));
        end
    end

    methods (Static, Access=private)
        function artifact=makeTestArtifact()
            variable=struct('Name','x','Unit','1','Topology','linear', ...
                'Scale',1);
            schema=struct('version','1.0.0','orderedNames',{{'x'}}, ...
                'variables',{{variable}});
            artifact=struct('schemaVersion','1.0.0', ...
                'artifactType','solution','modelId','test_model', ...
                'modelVersion','1.0.0','problemId','test_problem', ...
                'problemVersion','1.0.0','decisionSchema',schema, ...
                'parameterSchema',schema,'decisionValues',0, ...
                'parameterValues',0,'diagnostics',struct(), ...
                'lineage',struct(),'randomSeed',0, ...
                'sourceCommitSHAs',struct(), ...
                'createdAt','2026-07-19T00:00:00Z', ...
                'matlabVersion',version,'codeVersion','legacy');
        end
    end
end
