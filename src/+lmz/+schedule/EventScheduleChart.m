classdef EventScheduleChart
    %EVENTSCHEDULECHART Smooth ordered-gap coordinates for free event times.
    properties (SetAccess=private)
        Template
        Schema
        DecisionSchema
    end

    methods
        function obj=EventScheduleChart(schedule)
            if ~isa(schedule,'lmz.schedule.EventSchedule')
                error('lmz:Schedule:ChartType','Expected an EventSchedule.');
            end
            schedule.validate();
            obj.Template=schedule;
            obj.Schema=lmz.schedule.EventScheduleSchema(schedule);
            count=obj.Schema.freeCount();
            specs=lmz.schema.VariableSpec.empty(0,1);
            for index=1:count
                specs(index,1)=lmz.schema.VariableSpec( ...
                    sprintf('schedule_q_%d',index), ...
                    'Label',sprintf('Schedule coordinate %d',index), ...
                    'Group','event_schedule','Unit','','DefaultValue',0, ...
                    'Scale',1,'Role','schedule','EnergyEffect','invariant');
            end
            provisional=lmz.schema.VariableSchema(specs,'1.0.0');
            obj.DecisionSchema=provisional;
            defaults=obj.encode(schedule);
            for index=1:count
                specs(index,1)=lmz.schema.VariableSpec( ...
                    sprintf('schedule_q_%d',index), ...
                    'Label',sprintf('Schedule coordinate %d',index), ...
                    'Group','event_schedule','Unit','', ...
                    'DefaultValue',defaults(index),'Scale',1, ...
                    'Role','schedule','EnergyEffect','invariant');
            end
            obj.DecisionSchema=lmz.schema.VariableSchema(specs,'1.0.0');
        end

        function schedule=decode(obj,coordinates)
            obj.DecisionSchema.validateVector(coordinates);
            q=coordinates(:); cursor=1;
            n=obj.Template.count();
            times=obj.Template.times();
            fixed=obj.Template.fixedMask();
            gap=obj.Template.MinimumGap;
            fixedIndices=find(fixed);
            lowerIndex=0; lowerTime=0;
            for anchorIndex=1:numel(fixedIndices)
                upperIndex=fixedIndices(anchorIndex);
                upperTime=times(upperIndex);
                freeIndices=(lowerIndex+1):(upperIndex-1);
                [values,cursor]=obj.decodeBoundedRun(q,cursor,lowerTime, ...
                    upperTime,numel(freeIndices),gap);
                times(freeIndices)=values;
                lowerIndex=upperIndex; lowerTime=upperTime;
            end
            if obj.Template.ReturnTimeFixed
                freeIndices=(lowerIndex+1):n;
                [values,cursor]=obj.decodeBoundedRun(q,cursor,lowerTime, ...
                    obj.Template.ReturnTime,numel(freeIndices),gap);
                times(freeIndices)=values;
                returnTime=obj.Template.ReturnTime;
            else
                freeIndices=(lowerIndex+1):n;
                current=lowerTime;
                for index=1:numel(freeIndices)
                    current=current+gap+obj.softplus(q(cursor));
                    times(freeIndices(index))=current;
                    cursor=cursor+1;
                end
                returnTime=current+gap+obj.softplus(q(cursor));
                cursor=cursor+1;
            end
            if cursor-1~=numel(q)
                error('lmz:Schedule:ChartDecode', ...
                    'Schedule chart did not consume every coordinate.');
            end
            schedule=obj.Template.withTimes(times,returnTime);
        end

        function coordinates=encode(obj,schedule)
            obj.assertCompatible(schedule);
            n=schedule.count(); times=schedule.times();
            fixed=obj.Template.fixedMask(); gap=obj.Template.MinimumGap;
            coordinates=zeros(obj.Schema.freeCount(),1); cursor=1;
            fixedIndices=find(fixed); lowerIndex=0; lowerTime=0;
            for anchorIndex=1:numel(fixedIndices)
                upperIndex=fixedIndices(anchorIndex);
                upperTime=obj.Template.times(); upperTime=upperTime(upperIndex);
                freeIndices=(lowerIndex+1):(upperIndex-1);
                [values,cursor]=obj.encodeBoundedRun(coordinates,cursor, ...
                    lowerTime,upperTime,times(freeIndices),gap);
                coordinates=values;
                lowerIndex=upperIndex; lowerTime=upperTime;
            end
            if obj.Template.ReturnTimeFixed
                freeIndices=(lowerIndex+1):n;
                [coordinates,cursor]=obj.encodeBoundedRun(coordinates,cursor, ...
                    lowerTime,obj.Template.ReturnTime,times(freeIndices),gap);
            else
                freeIndices=(lowerIndex+1):n; current=lowerTime;
                for index=1:numel(freeIndices)
                    physicalGap=times(freeIndices(index))-current-gap;
                    coordinates(cursor)=obj.inverseSoftplus(physicalGap);
                    cursor=cursor+1; current=times(freeIndices(index));
                end
                coordinates(cursor)=obj.inverseSoftplus( ...
                    schedule.ReturnTime-current-gap);
                cursor=cursor+1;
            end
            if cursor-1~=numel(coordinates)
                error('lmz:Schedule:ChartEncode', ...
                    'Schedule chart did not produce every coordinate.');
            end
        end

        function gaps=positiveGaps(~,schedule)
            gaps=diff([0;schedule.times();schedule.ReturnTime]);
        end

        function value=toStruct(obj)
            value=struct('SchemaVersion','1.0.0', ...
                'Template',obj.Template.toStruct(), ...
                'ScheduleSchema',obj.Schema.toStruct(), ...
                'DecisionSchema',obj.DecisionSchema.toStruct(), ...
                'CoordinateKind','ordered-positive-gap');
        end
    end

    methods (Access=private)
        function assertCompatible(obj,schedule)
            if ~isa(schedule,'lmz.schedule.EventSchedule')|| ...
                    ~isequal(schedule.names(),obj.Template.names())|| ...
                    ~isequal(schedule.fixedMask(),obj.Template.fixedMask())|| ...
                    schedule.ReturnTimeFixed~=obj.Template.ReturnTimeFixed
                error('lmz:Schedule:ChartCompatibility', ...
                    'Schedule does not match the chart names or fixed/free mask.');
            end
            schedule.validate();
            fixed=obj.Template.fixedMask();
            original=obj.Template.times(); candidate=schedule.times();
            if any(candidate(fixed)~=original(fixed))|| ...
                    (obj.Template.ReturnTimeFixed&& ...
                    schedule.ReturnTime~=obj.Template.ReturnTime)
                error('lmz:Schedule:FixedValueChanged', ...
                    'A schedule fixed value changed.');
            end
        end
    end

    methods (Static, Access=private)
        function [values,cursor]=decodeBoundedRun(q,cursor,lower,upper,count,gap)
            values=zeros(count,1);
            if count==0, return, end
            available=upper-lower-(count+1)*gap;
            if available<=0
                error('lmz:Schedule:FixedAnchors', ...
                    'Fixed schedule anchors leave no feasible positive gaps.');
            end
            current=lower; remaining=available;
            for index=1:count
                fraction=1/(1+exp(-q(cursor)));
                % Keep trial schedules strictly inside the ordered-gap
                % chart even when a nonlinear solver proposes a coordinate
                % large enough to saturate the logistic map numerically.
                fraction=min(1-eps,max(eps,fraction));
                extra=remaining*fraction;
                current=current+gap+extra;
                values(index)=current;
                remaining=remaining-extra;
                cursor=cursor+1;
            end
        end

        function [coordinates,cursor]=encodeBoundedRun(coordinates,cursor, ...
                lower,upper,values,gap)
            count=numel(values);
            if count==0, return, end
            available=upper-lower-(count+1)*gap;
            if available<=0
                error('lmz:Schedule:FixedAnchors', ...
                    'Fixed schedule anchors leave no feasible positive gaps.');
            end
            current=lower; remaining=available;
            for index=1:count
                extra=values(index)-current-gap;
                if extra<0||extra>remaining
                    error('lmz:Schedule:ChartDomain', ...
                        'Schedule lies outside the fixed-anchor chart domain.');
                end
                fraction=max(eps,min(1-eps,extra/remaining));
                coordinates(cursor)=log(fraction/(1-fraction));
                remaining=remaining-extra;
                current=values(index); cursor=cursor+1;
            end
        end

        function value=softplus(q)
            value=log1p(exp(-abs(q)))+max(q,0);
        end

        function value=inverseSoftplus(x)
            if ~isfinite(x)||x<0
                error('lmz:Schedule:GapDomain', ...
                    'A positive-gap chart received a nonpositive physical gap.');
            end
            x=max(x,realmin);
            if x>35
                value=x;
            else
                value=log(expm1(x));
            end
        end
    end
end
