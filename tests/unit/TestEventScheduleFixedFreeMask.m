classdef TestEventScheduleFixedFreeMask < matlab.unittest.TestCase
    methods (Test)
        function holdsFixedEventsAndReturnExactly(testCase)
            schedule=lmz.schedule.EventSchedule.fromCyclic( ...
                {'a','b','c'},[.2;.4;.7],1,'FixedMask',[false;true;false], ...
                'ReturnTimeFixed',true);
            chart=lmz.schedule.EventScheduleChart(schedule);
            testCase.verifyEqual(chart.DecisionSchema.count(),2);
            candidate=chart.decode(chart.encode(schedule)+[.2;-.3]);
            testCase.verifyEqual(candidate.namedTimes({'b'}),.4,'AbsTol',0);
            testCase.verifyEqual(candidate.ReturnTime,1,'AbsTol',0);
        end
    end
end
