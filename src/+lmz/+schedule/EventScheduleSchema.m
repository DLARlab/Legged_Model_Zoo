classdef EventScheduleSchema
    %EVENTSCHEDULESCHEMA Immutable names and fixed/free schedule metadata.
    properties (SetAccess=private)
        EventNames
        FixedMask
        ReturnTimeFixed
        MinimumGap
    end
    methods
        function obj=EventScheduleSchema(schedule)
            if ~isa(schedule,'lmz.schedule.EventSchedule')
                error('lmz:Schedule:SchemaType','Expected an EventSchedule.');
            end
            obj.EventNames=schedule.names();
            obj.FixedMask=schedule.fixedMask();
            obj.ReturnTimeFixed=schedule.ReturnTimeFixed;
            obj.MinimumGap=schedule.MinimumGap;
        end
        function value=freeCount(obj)
            value=sum(~obj.FixedMask)+double(~obj.ReturnTimeFixed);
        end
        function value=toStruct(obj)
            value=struct('EventNames',{obj.EventNames}, ...
                'FixedMask',obj.FixedMask,'ReturnTimeFixed',obj.ReturnTimeFixed, ...
                'MinimumGap',obj.MinimumGap);
        end
    end
end
