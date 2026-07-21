classdef (Abstract) ContactConstraintProvider < handle
    %CONTACTCONSTRAINTPROVIDER Model boundary for timing-only residuals.
    methods (Abstract)
        value=eventNames(obj)
        value=evaluate(obj,initialState,physicalParameters,schedule,context,includeSimulation)
    end
    methods (Static)
        function schedule=scheduleFromConfiguration(names,times,returnTime,configuration)
            if isfield(configuration,'EventSchedule')
                schedule=configuration.EventSchedule;
                if isstruct(schedule),schedule=lmz.schedule.EventSchedule.fromStruct(schedule);end
                if ~isa(schedule,'lmz.schedule.EventSchedule')
                    error('lmz:Timing:EventSchedule','EventSchedule configuration is invalid.');
                end
                return
            end
            fixed=false(numel(names),1);returnFixed=false;
            if isfield(configuration,'FixedEventMask')
                fixed=logical(configuration.FixedEventMask(:));
            end
            if isfield(configuration,'FreeEvents')
                free=configuration.FreeEvents;
                if ischar(free)&&strcmp(free,'all')
                    fixed=false(numel(names),1);
                else
                    if ischar(free),free={free};elseif isstring(free),free=cellstr(free(:));end
                    if ~iscell(free),error('lmz:Timing:FreeEvents','FreeEvents is invalid.');end
                    fixed=~ismember(names(:),free(:));
                end
            end
            if isfield(configuration,'FixedEvents')
                listed=configuration.FixedEvents;
                if ischar(listed),listed={listed};elseif isstring(listed),listed=cellstr(listed(:));end
                fixed=logical(fixed)|ismember(names(:),listed(:));
            end
            if isfield(configuration,'FreeReturnTime')
                returnFixed=~logical(configuration.FreeReturnTime);
            elseif isfield(configuration,'FixReturnTime')
                returnFixed=logical(configuration.FixReturnTime);
            end
            minimumGap=fieldOr(configuration,'MinimumGap',1e-12);
            startId=fieldOr(configuration,'StartSectionId','apex');
            stopId=fieldOr(configuration,'StopSectionId','apex');
            schedule=lmz.schedule.EventSchedule.fromCyclic(names,times,returnTime, ...
                'FixedMask',fixed,'ReturnTimeFixed',returnFixed, ...
                'MinimumGap',minimumGap,'StartSectionId',startId, ...
                'StopSectionId',stopId);
        end

        function crossing=sectionCrossing(raw,eventName,stateIndex,stateSide)
            if nargin<4, stateSide='post'; end
            records=raw.EventRecords; match=[];
            for index=1:numel(records)
                if isfield(records,'Name')
                    name=records(index).Name;
                elseif isfield(records,'Id')
                    name=records(index).Id;
                else
                    name='';
                end
                if strcmp(name,eventName), match=index; break, end
            end
            if isempty(match)
                error('lmz:Timing:SectionEventMissing', ...
                    'Section event %s was not returned by the model.',eventName);
            end
            record=records(match);
            pre=record.PreState(:); post=record.PostState(:);
            if strcmp(stateSide,'pre'), state=pre; else, state=post; end
            derivative=NaN;
            if nargin>=3&&~isempty(stateIndex)&&numel(raw.Time)>=2
                index=max(2,min(numel(raw.Time),find(raw.Time<=record.Time,1,'last')));
                if isempty(index), index=numel(raw.Time); end
                dt=raw.Time(index)-raw.Time(index-1);
                if dt>0
                    derivative=(raw.States(index,stateIndex)- ...
                        raw.States(index-1,stateIndex))/dt;
                end
            end
            sectionValue=0;
            if nargin>=3&&~isempty(stateIndex)&&stateIndex<=numel(state)
                sectionValue=state(stateIndex);
            end
            direction=0;
            if isfinite(derivative), direction=sign(derivative); end
            grazing=isfinite(derivative)&&abs(derivative)<=1e-8;
            crossing=struct('SectionId','apex','SectionValue',sectionValue, ...
                'DirectionalDerivative',derivative,'CrossingDirection',direction, ...
                'Grazing',grazing,'EventId',eventName,'ModeBefore','', ...
                'ModeAfter','','Time',record.Time,'PreState',pre, ...
                'PostState',post,'State',state,'StateSide',stateSide, ...
                'Occurrence',1,'Accepted',~grazing, ...
                'RejectionReason',ternary(grazing,'grazing',''));
        end

        function assertSupportedApexSchedule(schedule,modelId)
            %ASSERTSUPPORTEDAPEXSCHEDULE Prevent mislabeled timing results.
            if ~isa(schedule,'lmz.schedule.EventSchedule')|| ...
                    ~strcmp(schedule.StartSectionId,'apex')|| ...
                    ~strcmp(schedule.StopSectionId,'apex')
                error('lmz:Timing:UnsupportedSection', ...
                    ['%s timing evidence currently supports apex-to-apex ' ...
                    'returns only; the selected section is not implemented.'], ...
                    modelId);
            end
        end
    end
end

function value=ternary(condition,yes,no)
if condition,value=yes;else,value=no;end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
