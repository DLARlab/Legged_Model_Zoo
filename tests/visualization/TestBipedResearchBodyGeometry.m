classdef TestBipedResearchBodyGeometry < matlab.unittest.TestCase
    methods (Test)
        function bodyMatchesCapturedSourceVertices(testCase)
            fixture=loadBipedFixture('source_canonical_full.json');
            geometry=lmzmodels.slip_biped.ResearchBodyGeometry.compute(2,0.9);
            testCase.verifyClass(geometry,'lmz.viz.PatchGeometry');
            testCase.verifySize(geometry.Vertices,size(fixture.body.vertices));
            testCase.verifyEqual(geometry.Vertices,fixture.body.vertices, ...
                'AbsTol',2e-14);
            testCase.verifyEqual(geometry.Faces,fixture.body.faces(:).');
            testCase.verifyEqual(geometry.Vertices(1,:),geometry.Vertices(end,:), ...
                'AbsTol',eps);
            testCase.verifyEqual(geometry.Metadata.sourceCommit,fixture.sourceCommit);
        end

        function quarteredCogMatchesCapturedSource(testCase)
            fixture=loadBipedFixture('source_canonical_full.json');
            geometry=lmzmodels.slip_biped.ResearchCOGGeometry.compute([2 0.9]);
            testCase.verifySize(geometry.Vertices,size(fixture.cog.vertices));
            testCase.verifySize(geometry.Faces,size(fixture.cog.faces));
            testCase.verifyEqual(geometry.Vertices,fixture.cog.vertices, ...
                'AbsTol',2e-14);
            testCase.verifyEqual(geometry.Faces,fixture.cog.faces);
            testCase.verifyEqual(geometry.Metadata.faceColors, ...
                fixture.cog.faceColors,'AbsTol',eps);
        end
    end
end

function value=loadBipedFixture(name)
path=fullfile(lmz.util.ProjectPaths.tests(),'fixtures','graphics', ...
    'slip_biped',name);value=jsondecode(fileread(path));
end
