classdef TestBipedContactLengthGeometry < matlab.unittest.TestCase
    methods (Test)
        function strictOrdinaryAndWrappedContacts(testCase)
            contact=@lmzmodels.slip_biped.ResearchLegGeometry.contactAt;
            testCase.verifyFalse(contact(0.2,0.2,0.6));
            testCase.verifyTrue(contact(0.3,0.2,0.6));
            testCase.verifyFalse(contact(0.6,0.2,0.6));
            testCase.verifyTrue(contact(0.05,0.7,0.1));
            testCase.verifyFalse(contact(0.3,0.7,0.1));
            testCase.verifyTrue(contact(0.8,0.7,0.1));
            testCase.verifyFalse(contact(0.5,0.5,0.5));
        end

        function wrappingAndLengthsMatchSource(testCase)
            wrapped=lmzmodels.slip_biped.ResearchLegGeometry.wrapEventTimes( ...
                [-0.1 1.1 0.7 0.1],1);
            testCase.verifyEqual(wrapped,[0.9;0.1;0.7;0.1], ...
                'AbsTol',2e-16);
            state=[2;0;0.9;0;0.2;0;-0.3;0];
            frame=lmzmodels.slip_biped.ResearchLegGeometry.frame( ...
                state,[0.2;0.6;0.7;0.1;1],0.3);
            testCase.verifyEqual(frame.LegLength,[0.9/cos(0.2),1], ...
                'AbsTol',2e-14);
            leftFoot=frame.Left.Lower.Vertices(22,:);
            rightFoot=frame.Right.Lower.Vertices(22,:);
            testCase.verifyEqual(leftFoot,[2+frame.LegLength(1)*sin(0.2),0], ...
                'AbsTol',2e-14);
            testCase.verifyEqual(rightFoot,[2+sin(-0.3),0.9-cos(-0.3)], ...
                'AbsTol',2e-14);
        end

        function eventScheduleUsesNamesNotRecordOrder(testCase)
            simulation=makeSimulation([5 3 1 4 2]);
            [schedule,available]= ...
                lmzmodels.slip_biped.ResearchLegGeometry.scheduleFromSimulation( ...
                simulation);
            testCase.verifyTrue(available);
            testCase.verifyEqual(schedule,[0.2;0.6;0.7;0.1;1], ...
                'AbsTol',eps);
        end
    end
end

function simulation=makeSimulation(order)
time=[0;0.3;1];states=[2 0 .9 0 .2 0 -.3 0; ...
    2.1 0 .92 0 .15 0 -.2 0;2.2 0 .95 0 .1 0 -.1 0];
modes=struct('left',[false;true;false],'right',[true;false;true], ...
    'period',1);names={'L_TD','L_LO','R_TD','R_LO','APEX'};
times=[0.2 0.6 0.7 0.1 1];records=repmat(struct('Name','','Time',0),5,1);
for index=1:5
    source=order(index);records(index).Name=names{source};
    records(index).Time=times(source);
end
simulation=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_biped.PhysicalStateSchema.create(),states,modes, ...
    struct(),struct(),struct(),struct(),'EventRecords',records);
end
