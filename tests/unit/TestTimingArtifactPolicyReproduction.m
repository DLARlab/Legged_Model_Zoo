classdef TestTimingArtifactPolicyReproduction < matlab.unittest.TestCase
    methods (Test)
        function rectangularPolicyAndSolverSurviveArtifact(testCase)
            [artifact,original]=contactTimingArtifact();
            lmz.io.ArtifactStore.validate(artifact);
            configuration=artifact.problemMetadata.configuration;
            expected=lmz.io.ArtifactStore.dataHash(configuration);
            testCase.verifyEqual(artifact.problemConfigurationHash,expected);
            testCase.verifyEqual(artifact.sourceDataHashes. ...
                ProblemConfiguration,expected);
            testCase.verifyEqual(configuration.FixedRowPolicy, ...
                'include_fixed_rows_in_least_squares');
            [reproduced,report]=lmz.services.reproduceRun(artifact);
            testCase.verifyEqual(report.ArtifactType,'contact-timing-run');
            testCase.verifyTrue(reproduced.SolverDiagnostics.Success);
            testCase.verifyEqual(reproduced.SolverDiagnostics. ...
                RankDiagnostics.SolverSelected,'lsqnonlin');
            testCase.verifyEqual(reproduced.SolvedSchedule.times(), ...
                original.SolvedSchedule.times(),'AbsTol',1e-12);
            names={report.HashChecks.Name};
            location=find(strcmp(names,'ProblemConfiguration'));
            testCase.verifyEqual(numel(location),1);
            testCase.verifyTrue(report.HashChecks(location).Verified);
            testCase.verifyEqual(report.HashChecks(location).Status, ...
                'verified-payload');
        end

        function rejectsConfigurationAndPayloadTampering(testCase)
            artifact=contactTimingArtifact();
            badConfiguration=artifact;
            badConfiguration.problemMetadata.configuration. ...
                FixedRowPolicy='validate_fixed_rows';
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate(badConfiguration), ...
                'lmz:Artifact:ProblemConfigurationHash');
            testCase.verifyError( ...
                @()lmz.services.reproduceRun(badConfiguration), ...
                'lmz:Artifact:ProblemConfigurationHash');

            rebasedConfiguration=badConfiguration;
            rebasedHash=lmz.io.ArtifactStore.dataHash( ...
                rebasedConfiguration.problemMetadata.configuration);
            rebasedConfiguration.problemConfigurationHash=rebasedHash;
            rebasedConfiguration.sourceDataHashes. ...
                ProblemConfiguration=rebasedHash;
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate(rebasedConfiguration), ...
                'lmz:Artifact:ProblemConfigurationPayload');

            badPayload=artifact;
            badPayload.contactTimingResult.FixedInitialState(1)= ...
                badPayload.contactTimingResult.FixedInitialState(1)+0.25;
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate(badPayload), ...
                'lmz:Artifact:ProblemConfigurationPayload');

            executableConfiguration=artifact;
            executableConfiguration.problemMetadata.configuration. ...
                Callback=@sin;
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate( ...
                executableConfiguration), ...
                'lmz:Artifact:ExecutableWorkflowData');
        end

        function migratesLegacySchemaOneTimingArtifact(testCase)
            artifact=contactTimingArtifact();
            expected=artifact.problemConfigurationHash;
            artifact=rmfield(artifact,'problemConfigurationHash');
            artifact.sourceDataHashes=rmfield(artifact.sourceDataHashes, ...
                'ProblemConfiguration');
            [loaded,pathCleanup]=saveRawAndLoad(artifact); %#ok<ASGLU>
            testCase.verifyEqual(loaded.schemaVersion,'1.0.0');
            testCase.verifyEqual(loaded.problemConfigurationHash,expected);
            testCase.verifyEqual(loaded.sourceDataHashes. ...
                ProblemConfiguration,expected);
            clear pathCleanup
        end
    end
end

function [artifact,result]=contactTimingArtifact()
persistent cachedArtifact cachedResult
if isempty(cachedArtifact)
    registry=lmz.registry.ModelRegistry.discover();
    model=registry.createModel('tutorial_hopper');
    source=model.createProblem('section_return_timing',struct());
    schedule=source.InputSchedule.withFixedMask(true,false);
    problem=model.createProblem('section_return_timing',struct( ...
        'EventSchedule',schedule,'FixedRowPolicy', ...
        'include_fixed_rows_in_least_squares'));
    cachedResult=lmz.services.ContactTimingService().solve(problem, ...
        problem.InputSchedule,struct('Solver','lsqnonlin'), ...
        lmz.api.RunContext.synchronous(1016));
    cachedArtifact=cachedResult.toArtifact();
end
artifact=cachedArtifact;result=cachedResult;
end

function [loaded,cleanup]=saveRawAndLoad(artifact)
path=[tempname(tempdir) '.mat'];
cleanup=onCleanup(@()deleteIfPresent(path));
save(path,'artifact');
loaded=lmz.io.ArtifactStore.load(path);
end

function deleteIfPresent(path)
if exist(path,'file')==2,delete(path);end
end
