classdef TestEventSchedulePositiveGapChart < matlab.unittest.TestCase
    methods (Test)
        function roundTripsStrictlyOrderedGaps(testCase)
            names={'third','first','second'};times=[.7;.2;.4];
            schedule=lmz.schedule.EventSchedule.fromCyclic(names,times,1);
            chart=lmz.schedule.EventScheduleChart(schedule);
            restored=chart.decode(chart.encode(schedule));
            testCase.verifyGreaterThan(min(chart.positiveGaps(restored)),0);
            testCase.verifyEqual(restored.namedTimes(names),times,'AbsTol',1e-12);
        end
    end
end
