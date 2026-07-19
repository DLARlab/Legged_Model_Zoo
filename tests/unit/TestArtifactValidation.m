classdef TestArtifactValidation < matlab.unittest.TestCase
    methods (Test)
        function rejectsMissingField(testCase)
            artifact = rmfield(makeTestArtifact(), 'modelId');
            testCase.verifyError(@() ...
                lmz.io.ArtifactStore.validate(artifact), ...
                'lmz:Artifact:MissingField');
        end

        function rejectsBadDimension(testCase)
            artifact = makeTestArtifact();
            artifact.decisionValues = [1; 2];
            testCase.verifyError(@() ...
                lmz.io.ArtifactStore.validate(artifact), ...
                'lmz:Artifact:ValueDimensionMismatch');
        end

        function rejectsNonfiniteValues(testCase)
            artifact = makeTestArtifact();
            artifact.parameterValues = NaN;
            testCase.verifyError(@() ...
                lmz.io.ArtifactStore.validate(artifact), ...
                'lmz:Artifact:NonfiniteValues');
        end

        function rejectsWrongVersion(testCase)
            artifact = makeTestArtifact();
            artifact.schemaVersion = '99.0.0';
            testCase.verifyError(@() ...
                lmz.io.ArtifactStore.validate(artifact), ...
                'lmz:Artifact:UnsupportedVersion');
        end
    end
end
