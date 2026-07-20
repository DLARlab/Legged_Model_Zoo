classdef TestQuadLoadResearchRopeGeometry < matlab.unittest.TestCase
    methods (Test)
        function ropeMatchesCapturedDuplicatedEndpointPath(testCase)
            fixture=QuadLoadGraphicsTestSupport.fixture();
            geometry=lmzmodels.slip_quad_load.ResearchRopeGeometry.compute( ...
                fixture.quadrupedCenter,fixture.loadCenter);
            testCase.verifyClass(geometry,'lmz.viz.PatchGeometry');
            testCase.verifyEqual(geometry.Vertices,fixture.ropeVertices, ...
                'AbsTol',eps);
            testCase.verifyEqual(geometry.Faces,1:4);
            testCase.verifyEqual(geometry.Vertices(1,:),geometry.Vertices(2,:));
            testCase.verifyEqual(geometry.Vertices(3,:),geometry.Vertices(4,:));
            testCase.verifyEqual(geometry.Metadata.sourceCommit, ...
                fixture.sourceCommit);
        end

        function endpointsRemainNamedAndValidated(testCase)
            geometry=lmzmodels.slip_quad_load.ResearchRopeGeometry.compute( ...
                [1 2],[3 4]);
            testCase.verifyEqual(geometry.Metadata.startFrame, ...
                'quadruped_center_of_mass');
            testCase.verifyEqual(geometry.Metadata.endFrame,'load_center');
            testCase.verifyError(@() ...
                lmzmodels.slip_quad_load.ResearchRopeGeometry.compute([1 2 3],[3 4]), ...
                'lmz:slip_quad_load:ResearchPoint');
        end
    end
end
