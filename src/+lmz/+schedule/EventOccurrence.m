classdef EventOccurrence
    %EVENTOCCURRENCE One named event relative to a stride start section.
    properties (SetAccess=private)
        Name
        Time
        Fixed
        Metadata
    end

    methods
        function obj = EventOccurrence(name,time,varargin)
            parser=inputParser;
            addRequired(parser,'name',@lmz.schedule.EventOccurrence.isName);
            addRequired(parser,'time',@(x)isnumeric(x)&&isreal(x)&&isscalar(x)&&isfinite(x));
            addParameter(parser,'Fixed',false,@(x)islogical(x)&&isscalar(x));
            addParameter(parser,'Metadata',struct(),@(x)isstruct(x)&&isscalar(x));
            parse(parser,name,time,varargin{:});
            obj.Name=parser.Results.name;
            obj.Time=parser.Results.time;
            obj.Fixed=parser.Results.Fixed;
            obj.Metadata=parser.Results.Metadata;
        end

        function value=withTime(obj,time)
            value=lmz.schedule.EventOccurrence(obj.Name,time, ...
                'Fixed',obj.Fixed,'Metadata',obj.Metadata);
        end

        function value=withFixed(obj,fixed)
            value=lmz.schedule.EventOccurrence(obj.Name,obj.Time, ...
                'Fixed',fixed,'Metadata',obj.Metadata);
        end

        function value=toStruct(obj)
            value=struct('Name',obj.Name,'Time',obj.Time, ...
                'Fixed',obj.Fixed,'Metadata',obj.Metadata);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            obj=lmz.schedule.EventOccurrence(value.Name,value.Time, ...
                'Fixed',value.Fixed,'Metadata',value.Metadata);
        end
    end

    methods (Static, Access=private)
        function valid=isName(value)
            valid=ischar(value)&&~isempty(regexp(value, ...
                '^[A-Za-z][A-Za-z0-9_.-]*$','once'));
        end
    end
end
