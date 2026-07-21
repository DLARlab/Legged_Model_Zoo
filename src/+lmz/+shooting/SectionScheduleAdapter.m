classdef SectionScheduleAdapter
    %SECTIONSCHEDULEADAPTER Positive-gap chart boundary for one segment.
    properties (SetAccess=private)
        Chart
    end
    methods
        function obj=SectionScheduleAdapter(schedule)
            if ~isa(schedule,'lmz.schedule.EventSchedule')
                error('lmz:Shooting:ScheduleAdapter', ...
                    'SectionScheduleAdapter requires an EventSchedule.');
            end
            obj.Chart=lmz.schedule.EventScheduleChart(schedule);
        end
        function value=encode(obj,schedule),value=obj.Chart.encode(schedule);end
        function value=decode(obj,coordinates),value=obj.Chart.decode(coordinates);end
        function value=schema(obj),value=obj.Chart.DecisionSchema;end
        function value=toStruct(obj)
            value=struct('Schedule',obj.Chart.Template.toStruct(), ...
                'Schema',obj.Chart.DecisionSchema.toStruct());
        end
    end
end
