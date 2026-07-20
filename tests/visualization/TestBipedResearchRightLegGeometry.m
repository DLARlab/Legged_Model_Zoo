classdef TestBipedResearchRightLegGeometry < matlab.unittest.TestCase
    methods (Test)
        function postUpdateGeometryMatchesCapturedSource(testCase)
            fixture=loadBipedFixture('source_canonical_full.json');
            frame=lmzmodels.slip_biped.ResearchLegGeometry.frame( ...
                fixture.canonical.state,fixture.canonical.eventTimes, ...
                fixture.canonical.time);
            testCase.verifyFalse(frame.Contact.right);
            testCase.verifyEqual(frame.LegLength(2),1,'AbsTol',eps);
            verifyPart(testCase,frame.Right.Spring1,fixture.right.spring1);
            verifyPart(testCase,frame.Right.Lower,fixture.right.lower);
            verifyPart(testCase,frame.Right.Spring2,fixture.right.spring2);
            verifyPart(testCase,frame.Right.Upper,fixture.right.upper);
            testCase.verifyEqual(frame.Right.Spring1.Faces, ...
                [(1:14).',(2:15).']);
            testCase.verifyEqual(frame.Right.Spring2.Faces,reshape(1:14,2,7).');
            testCase.verifyEqual(frame.Right.Lower.Faces,1:54);
            testCase.verifyEqual(frame.Right.Upper.Faces,[26,1:25]);
        end

        function leftRightStyleDifferenceIsExplicit(testCase)
            style=lmzmodels.slip_biped.ResearchStyle.defaults();
            testCase.verifyEqual(style.leftLeg.faceColor,[202 202 202]/256, ...
                'AbsTol',eps);
            testCase.verifyEqual(style.rightLeg.faceColor,[1 1 1], ...
                'AbsTol',eps);
            testCase.verifyEqual(style.spring.edgeColor,[0 68 158]/256, ...
                'AbsTol',eps);
            testCase.verifyNotEqual(style.leftLeg.faceColor,style.rightLeg.faceColor);
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
