classdef TimingResidualPolicy
    %TIMINGRESIDUALPOLICY Fixed/free timing-row selection and validation.
    methods (Static)
        function value=normalize(value)
            if nargin<1||isempty(value),value='validate_fixed_rows';end
            if isstring(value)&&isscalar(value),value=char(value);end
            allowed={'validate_fixed_rows', ...
                'include_fixed_rows_in_least_squares','diagnostic_only'};
            if ~ischar(value)||~any(strcmp(value,allowed))
                error('lmz:Timing:FixedRowPolicy', ...
                    'FixedRowPolicy must be one of: %s.', ...
                    strjoin(allowed,', '));
            end
        end

        function bindings=bindings(schedule,rowCount,source)
            if nargin<3||isempty(source)
                if rowCount~=schedule.count()
                    error('lmz:Timing:ProviderContactCount', ...
                        ['Provider contact rows must match scheduled events ' ...
                        'unless ContactRowBindings are supplied.']);
                end
                names=schedule.names();
                bindings=repmat(struct('Kind','event','EventName',''), ...
                    rowCount,1);
                for index=1:rowCount
                    bindings(index).EventName=names{index};
                end
                return
            end
            if iscell(source),source=[source{:}];end
            if ~isstruct(source)||numel(source)~=rowCount
                error('lmz:Timing:ContactRowBindings', ...
                    'ContactRowBindings must contain one struct per contact row.');
            end
            bindings=repmat(struct('Kind','','EventName',''),rowCount,1);
            eventNames=schedule.names();
            for index=1:rowCount
                item=source(index);
                if ~isfield(item,'Kind')||~ischar(item.Kind)
                    error('lmz:Timing:ContactRowBindingKind', ...
                        'Each contact row binding requires a text Kind.');
                end
                eventName='';
                if isfield(item,'EventName'),eventName=item.EventName;end
                if ~ischar(eventName)
                    error('lmz:Timing:ContactRowBindingEvent', ...
                        'Contact row EventName must be text.');
                end
                kinds={'event','return','always'};
                if ~any(strcmp(item.Kind,kinds))
                    error('lmz:Timing:ContactRowBindingKind', ...
                        'Contact row Kind must be event, return, or always.');
                end
                if strcmp(item.Kind,'event')&& ...
                        ~any(strcmp(eventName,eventNames))
                    error('lmz:Timing:ContactRowBindingEvent', ...
                        'Event-bound contact row names an unknown event.');
                elseif ~strcmp(item.Kind,'event')&&~isempty(eventName)
                    error('lmz:Timing:ContactRowBindingEvent', ...
                        'Only event-bound contact rows may specify EventName.');
                end
                bindings(index)=struct('Kind',item.Kind, ...
                    'EventName',eventName);
            end
        end

        function [contactMask,includeSection,fixedMask]=activeRows( ...
                schedule,policy,bindings)
            policy=lmz.schedule.TimingResidualPolicy.normalize(policy);
            if nargin<3
                bindings=lmz.schedule.TimingResidualPolicy.bindings( ...
                    schedule,schedule.count(),[]);
            end
            contactMask=false(numel(bindings),1);
            fixedMask=false(numel(bindings),1);
            eventNames=schedule.names();eventFixed=schedule.fixedMask();
            for index=1:numel(bindings)
                switch bindings(index).Kind
                    case 'event'
                        eventIndex=find(strcmp( ...
                            bindings(index).EventName,eventNames),1);
                        fixedMask(index)=eventFixed(eventIndex);
                        contactMask(index)=~fixedMask(index);
                    case 'return'
                        fixedMask(index)=schedule.ReturnTimeFixed;
                        contactMask(index)=~fixedMask(index);
                    case 'always'
                        contactMask(index)=true;
                end
            end
            includeSection=~schedule.ReturnTimeFixed;
            if strcmp(policy,'include_fixed_rows_in_least_squares')
                contactMask=true(numel(bindings),1);
                includeSection=true;
            end
        end

        function [rows,valid,maximum]=fixedRows( ...
                schedule,contact,section,tolerance,bindings)
            if ~isnumeric(tolerance)||~isscalar(tolerance)|| ...
                    ~isfinite(tolerance)||tolerance<0
                error('lmz:Timing:FixedRowTolerance', ...
                    'FixedRowTolerance must be finite and nonnegative.');
            end
            if nargin<5
                bindings=lmz.schedule.TimingResidualPolicy.bindings( ...
                    schedule,numel(contact),[]);
            end
            [~,~,fixedMask]= ...
                lmz.schedule.TimingResidualPolicy.activeRows( ...
                schedule,'validate_fixed_rows',bindings);
            rows=contact(fixedMask);
            if schedule.ReturnTimeFixed,rows=[rows;section(:)];end
            valid=all(isfinite(rows))&&all(abs(rows)<=tolerance);
            if isempty(rows),maximum=0;else,maximum=max(abs(rows));end
        end
    end
end
