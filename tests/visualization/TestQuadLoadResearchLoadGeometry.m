classdef TestQuadLoadResearchLoadGeometry < matlab.unittest.TestCase
    methods (Test)
        function loadMatchesCapturedSourcePatch(testCase)
            fixture=QuadLoadGraphicsTestSupport.fixture();
            geometry=lmzmodels.slip_quad_load.ResearchLoadGeometry.compute( ...
                fixture.loadCenter);
            testCase.verifyClass(geometry,'lmz.viz.PatchGeometry');
            testCase.verifyEqual(geometry.Vertices,fixture.loadVertices, ...
                'AbsTol',eps);
            testCase.verifyEqual(geometry.Faces,1:4);
            testCase.verifyEqual(geometry.Metadata.halfWidth, ...
                fixture.loadCenter(2),'AbsTol',eps);
            testCase.verifyEqual(geometry.Metadata.halfHeight, ...
                fixture.loadCenter(2),'AbsTol',eps);
            testCase.verifyEqual(geometry.Metadata.sourceCommit, ...
                fixture.sourceCommit);
        end

        function loadUsesSourceYAsBothHalfExtents(testCase)
            geometry=lmzmodels.slip_quad_load.ResearchLoadGeometry.compute([3 .25]);
            testCase.verifyEqual(geometry.Vertices, ...
                [2.75 0;3.25 0;3.25 .5;2.75 .5],'AbsTol',eps);
            testCase.verifyError(@() ...
                lmzmodels.slip_quad_load.ResearchLoadGeometry.compute([1 nan]), ...
                'lmz:slip_quad_load:ResearchPoint');
        end
    end
end
