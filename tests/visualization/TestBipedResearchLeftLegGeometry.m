classdef TestBipedResearchLeftLegGeometry < matlab.unittest.TestCase
    methods (Test)
        function postUpdateGeometryMatchesCapturedSource(testCase)
            fixture=loadBipedFixture('source_canonical_full.json');
            frame=lmzmodels.slip_biped.ResearchLegGeometry.frame( ...
                fixture.canonical.state,fixture.canonical.eventTimes, ...
                fixture.canonical.time);
            testCase.verifyTrue(frame.Contact.left);
            testCase.verifyEqual(frame.LegLength(1), ...
                fixture.canonical.legLengths(1),'AbsTol',2e-14);
            verifyPart(testCase,frame.Left.Spring1,fixture.left.spring1);
            verifyPart(testCase,frame.Left.Lower,fixture.left.lower);
            verifyPart(testCase,frame.Left.Spring2,fixture.left.spring2);
            verifyPart(testCase,frame.Left.Upper,fixture.left.upper);
            testCase.verifyEqual(frame.Left.Spring1.Faces, ...
                [(1:14).',(2:15).']);
            testCase.verifyEqual(frame.Left.Spring2.Faces,reshape(1:14,2,7).');
            testCase.verifyEqual(frame.Left.Lower.Faces,1:54);
            testCase.verifyEqual(frame.Left.Upper.Faces,[26,1:25]);
        end

        function transientConstructorDifferenceRemainsMeasurable(testCase)
            animated=lmzmodels.slip_biped.ResearchLegGeometry.parts( ...
                1,1.2,1,0,'left');
            original=lmzmodels.slip_biped.ResearchLegGeometry.parts( ...
                1,1.2,1,0,'left','source_constructor');
            testCase.verifyEqual(animated.Lower.Vertices(1,:),[0.96 0.9], ...
                'AbsTol',eps);
            testCase.verifyEqual(original.Lower.Vertices(1,:),[0.97 0.5], ...
                'AbsTol',eps);
            testCase.verifyEqual(animated.GeometryMode,'animated');
        end
    end
end

function verifyPart(testCase,actual,expected)
testCase.verifySize(actual.Vertices,size(expected.vertices));
testCase.verifyEqual(actual.Vertices,expected.vertices,'AbsTol',3e-14);
faces=expected.faces;if isvector(faces),faces=faces(:).';end
testCase.verifyEqual(actual.Faces,faces);
end
function value=loadBipedFixture(name)
path=fullfile(lmz.util.ProjectPaths.tests(),'fixtures','graphics', ...
    'slip_biped',name);value=jsondecode(fileread(path));
end
