classdef TestArtifactRoundTrip < matlab.unittest.TestCase
    methods (Test)
        function roundTrip(testCase)
            a=struct('schemaVersion','1','artifactType','solution','modelId','m','modelVersion','1','problemId','p','problemVersion','1', ...
                'decisionSchema',struct(),'parameterSchema',struct(),'decisionValues',1,'parameterValues',2, ...
                'createdAt','now','matlabVersion',version,'codeVersion','test');
            path=[tempname '.mat']; cleanup=onCleanup(@()deleteIfPresent(path));
            lmz.io.ArtifactStore.save(path,a); testCase.verifyEqual(lmz.io.ArtifactStore.load(path),a);
        end
    end
end
function deleteIfPresent(path), if exist(path,'file'), delete(path); end, end
