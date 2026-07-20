classdef TestBipedResearchGroundGeometry < matlab.unittest.TestCase
    methods (Test)
        function denseHatchMatchesCapturedSummary(testCase)
            fixture=loadBipedFixture('ground_summary.json');
            geometry=lmzmodels.slip_biped.ResearchGroundGeometry.compute();
            mask=geometry.Layers{1};hatch=geometry.Layers{2};
            testCase.verifyEqual(mask.Vertices,fixture.mask.vertices,'AbsTol',eps);
            testCase.verifyEqual(mask.Faces,fixture.mask.faces(:).');
            testCase.verifySize(hatch.Vertices,[fixture.hatch.vertexCount 2]);
            testCase.verifySize(hatch.Faces,[fixture.hatch.faceCount 4]);
            testCase.verifyEqual([min(hatch.Vertices(:,1)) max(hatch.Vertices(:,1))], ...
                fixture.hatch.xLimits(:).','AbsTol',3e-14);
            testCase.verifyEqual([min(hatch.Vertices(:,2)) max(hatch.Vertices(:,2))], ...
                fixture.hatch.yLimits(:).','AbsTol',eps);
            testCase.verifyEqual(hatch.Vertices(1:4,:),fixture.hatch.firstVertices, ...
                'AbsTol',3e-14);
            testCase.verifyEqual(hatch.Vertices(end-3:end,:),fixture.hatch.lastVertices, ...
                'AbsTol',3e-14);
            testCase.verifyEqual(hatch.Faces(1:4,:),fixture.hatch.firstFaces);
            testCase.verifyEqual(hatch.Faces(end-3:end,:),fixture.hatch.lastFaces);
        end

        function summaryAndQualificationAreExplicit(testCase)
            summary=lmzmodels.slip_biped.ResearchGroundGeometry.summary();
            testCase.verifyEqual(summary.hatchVertexCount,20002);
            testCase.verifyEqual(summary.hatchFaceCount,5001);
            testCase.verifyEqual(summary.xLimits,[-50.1 200.01],'AbsTol',eps);
            metadata=lmzmodels.slip_biped.ResearchGroundGeometry.provenance();
            testCase.verifyNotEmpty(strfind(metadata.adaptation, ...
                'MATLAB-release-dependent'));
        end
    end
end

function value=loadBipedFixture(name)
path=fullfile(lmz.util.ProjectPaths.tests(),'fixtures','graphics', ...
    'slip_biped',name);value=jsondecode(fileread(path));
end
