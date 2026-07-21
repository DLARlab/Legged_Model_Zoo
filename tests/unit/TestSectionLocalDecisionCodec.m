classdef TestSectionLocalDecisionCodec < matlab.unittest.TestCase
    methods (Test)
        function namedEndpointOwnsReturnTimeAndRoundTrips(testCase)
            model=lmz.registry.ModelRegistry.discover(). ...
                createModel('slip_quadruped');
            problem=model.createProblem('periodic_orbit', ...
                localConfiguration('back_left_touchdown'));
            codec=problem.SectionCodec;
            u=problem.getDecisionSchema().defaults();
            decoded=codec.decode(u);
            encoded=codec.encode(decoded.InitialState, ...
                decoded.EventTimes,decoded.ReturnTime);
            endpointName=codec.EventNames{codec.EndpointEventIndex};
            testCase.verifyEqual(encoded,u,'AbsTol',1e-12);
            testCase.verifyEqual(decoded.EventTimes( ...
                codec.EndpointEventIndex),decoded.ReturnTime,'AbsTol',1e-12);
            testCase.verifyFalse(any(strcmp( ...
                decoded.EventSchedule.names(),endpointName)));
            testCase.verifyEqual(decoded.EventSchedule.count(),7);
            testCase.verifyFalse(any(strcmp( ...
                codec.StateCoordinates.CoordinateNames,'x')));
        end

        function statePlaneKeepsEveryContactEvent(testCase)
            model=lmz.registry.ModelRegistry.discover(). ...
                createModel('slip_biped');
            problem=model.createProblem('periodic_orbit', ...
                localConfiguration('descending_y_0_95'));
            codec=problem.SectionCodec;
            u=problem.getDecisionSchema().defaults();
            decoded=codec.decode(u);
            encoded=codec.encode(decoded.InitialState, ...
                decoded.EventTimes,decoded.ReturnTime);
            testCase.verifyEqual(codec.EndpointEventIndex,0);
            testCase.verifyEqual(decoded.EventSchedule.count(),4);
            testCase.verifyEqual(encoded,u,'AbsTol',1e-12);
            testCase.verifyNumElements(u,11);
        end
    end
end

function value=localConfiguration(sectionId)
value=struct('StartSectionId',sectionId,'StopSectionId',sectionId, ...
    'SymmetryId','planar_translation');
end
