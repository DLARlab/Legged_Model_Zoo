classdef TestQuadrupedResearchCOMGeometry < matlab.unittest.TestCase
    methods (Test)
        function sourceRadiiQuarterFacesAndColors(testCase)
            geometry = lmzmodels.slip_quadruped.ResearchCOMGeometry. ...
                compute([0 0 0], 0.15);
            testCase.verifySize(geometry.Outer.Vertices, [40 2]);
            testCase.verifySize(geometry.Inner.Vertices, [48 2]);
            testCase.verifySize(geometry.Inner.Faces, [4 12]);
            outerRadius = sqrt(sum(geometry.Outer.Vertices.^2, 2));
            innerRadius = sqrt(sum(geometry.Inner.Vertices.^2, 2));
            testCase.verifyEqual(outerRadius, 0.075*ones(40, 1), ...
                'AbsTol', 2e-15);
            testCase.verifyEqual(max(innerRadius), 0.1125, ...
                'AbsTol', 2e-15);
            testCase.verifyEqual(geometry.InnerFaceColors, ...
                [1 1 1; 0 0 0; 1 1 1; 0 0 0]);
        end

        function canonicalCompleteArrayFingerprintMatchesFixture(testCase)
            fixture = QuadrupedGraphicsTestSupport.fixture();
            geometry = lmzmodels.slip_quadruped.ResearchCOMGeometry.compute( ...
                fixture.canonical.bodyFrame, fixture.canonical.comRadius);
            expected = fixture.fingerprints;
            testCase.verifyEqual(QuadrupedGraphicsTestSupport.fingerprint( ...
                geometry.Outer.Vertices), expected.comOuterVertices, ...
                'RelTol', 3e-14, 'AbsTol', 1e-11);
            testCase.verifyEqual(QuadrupedGraphicsTestSupport.fingerprint( ...
                geometry.Inner.Vertices), expected.comInnerVertices, ...
                'RelTol', 3e-14, 'AbsTol', 1e-11);
            testCase.verifyEqual(QuadrupedGraphicsTestSupport.fingerprint( ...
                geometry.Inner.Faces), expected.comInnerFaces, 'AbsTol', 0);
        end
    end
end
