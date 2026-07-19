classdef TestArtifactRoundTrip < matlab.unittest.TestCase
    methods (Test)
        function roundTrip(testCase)
            artifact = makeTestArtifact();
            path = [tempname '.mat'];
            cleanup = onCleanup(@() deleteIfPresent(path));
            lmz.io.ArtifactStore.save(path, artifact);
            testCase.verifyEqual(lmz.io.ArtifactStore.load(path), artifact);
            clear cleanup
        end
    end
end

function deleteIfPresent(path)
if exist(path, 'file') == 2
    delete(path);
end
end
