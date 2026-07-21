classdef TestQuadLoadShootingArtifactIntegrity < matlab.unittest.TestCase
    methods (Test)
        function ordinaryArtifactBindsSourcesAndConfiguration(testCase)
            artifact=quadLoadArtifact();
            lmz.io.ArtifactStore.validate(artifact);

            evidence=artifact.sourceDataHashes. ...
                QuadLoadFeasibilityEvidence;
            template=artifact.sourceDataHashes.QuadLoadStrideTemplate;
            testCase.verifyEqual(evidence.relativePath,[ ...
                'examples/data/slip_quad_load/Scientific/' ...
                'MultipleShooting/round10_feasibility_evidence.json']);
            testCase.verifyEqual(template.relativePath,[ ...
                'examples/data/slip_quad_load/Scientific/Templates/' ...
                'P4_TR_RL_Individual_1.mat']);
            testCase.verifyFalse(isAbsolute(evidence.relativePath));
            testCase.verifyFalse(isAbsolute(template.relativePath));
            testCase.verifyEqual(evidence.sha256,fileDigest( ...
                evidence.relativePath));
            testCase.verifyEqual(template.sha256,fileDigest( ...
                template.relativePath));
            configuration=artifact.shootingProblemContract.Configuration;
            expected=lmz.io.ArtifactStore.dataHash(configuration);
            testCase.verifyEqual(artifact.problemConfigurationHash,expected);
            testCase.verifyEqual(artifact.sourceDataHashes. ...
                ProblemConfiguration,expected);
            testCase.verifyFalse(hasExecutable(artifact));

            [reproduced,report]=lmz.services.reproduceRun(artifact);
            testCase.verifyClass(reproduced, ...
                'lmz.shooting.ShootingResult');
            names={report.HashChecks.Name};
            required={'QuadLoadFeasibilityEvidence', ...
                'QuadLoadStrideTemplate','ProblemConfiguration'};
            for index=1:numel(required)
                location=find(strcmp(names,required{index}),1);
                testCase.verifyNotEmpty(location,required{index});
                testCase.verifyTrue(report.HashChecks(location).Verified, ...
                    required{index});
            end
            testCase.verifyGreaterThanOrEqual(report.VerifiedHashCount,3);
        end

        function tamperedHashesAreRejected(testCase)
            artifact=quadLoadArtifact();
            badEvidence=artifact;
            badEvidence.sourceDataHashes.QuadLoadFeasibilityEvidence. ...
                sha256=repmat('0',1,64);
            testCase.verifyError(@()lmz.services.reproduceRun(badEvidence), ...
                'lmz:Reproduce:SourceHashMismatch');

            badTemplate=artifact;
            badTemplate.sourceDataHashes.QuadLoadStrideTemplate.sha256= ...
                repmat('0',1,64);
            testCase.verifyError(@()lmz.services.reproduceRun(badTemplate), ...
                'lmz:Reproduce:SourceHashMismatch');

            badConfiguration=artifact;
            badConfiguration.shootingProblemContract.Configuration. ...
                ResidualTolerance=2*badConfiguration. ...
                shootingProblemContract.Configuration.ResidualTolerance;
            badConfiguration.shootingProblemContractHash= ...
                lmz.io.ArtifactStore.dataHash( ...
                badConfiguration.shootingProblemContract);
            testCase.verifyError( ...
                @()lmz.services.reproduceRun(badConfiguration), ...
                'lmz:Artifact:ProblemConfigurationHash');
        end

        function executableSourceMetadataIsRejected(testCase)
            artifact=quadLoadArtifact();
            artifact.sourceDataHashes.QuadLoadStrideTemplate.Loader=@sin;
            testCase.verifyError(@()lmz.io.ArtifactStore.validate(artifact), ...
                'lmz:Artifact:ExecutableWorkflowData');
        end
    end
end

function artifact=quadLoadArtifact()
persistent cached
if ~isempty(cached),artifact=cached;return,end
evidence=lmzmodels.slip_quad_load.QuadLoadFeasibilityEvidence();
record=evidence.caseRecord('n2_transition_feasibility_root');
configuration=evidence.configuration(record);
configuration.FreeNodeMask=false(record.numberOfStrides+1,14);
configuration.EventFreeMask=false;
configuration.FreeControlMask=false(record.numberOfStrides,4);
configuration.FreeControlMask(2,1)=true;
configuration.ExpectedLocalDimension=0;
context=lmz.api.RunContext.synchronous(1023);
problem=lmzmodels.slip_quad_load. ...
    QuadLoadMultipleShootingProblem([],configuration);
decision=problem.getDecisionSchema().defaults();
result=lmz.services.MultipleShootingService().solve(problem,decision, ...
    struct('ResidualTolerance',1e-7,'MaxIterations',4, ...
    'MaxFunctionEvaluations',30,'Display','off'),context);
cached=result.toArtifact();artifact=cached;
end

function value=fileDigest(relativePath)
path=fullfile(lmz.util.ProjectPaths.root(), ...
    strrep(relativePath,'/',filesep));
value=lmz.util.FileHash.sha256(path);
end

function value=isAbsolute(path)
value=~isempty(path)&&(path(1)==filesep|| ...
    ~isempty(regexp(path,'^[A-Za-z]:[\\/]','once')));
end

function value=hasExecutable(item)
if isa(item,'function_handle')||isobject(item)
    value=true;return
end
value=false;
if isstruct(item)
    names=fieldnames(item);
    for itemIndex=1:numel(item)
        for fieldIndex=1:numel(names)
            if hasExecutable(item(itemIndex).(names{fieldIndex}))
                value=true;return
            end
        end
    end
elseif iscell(item)
    for index=1:numel(item)
        if hasExecutable(item{index}),value=true;return,end
    end
end
end
