classdef HybridSimulator
    methods
        function result=simulateScheduled(~,system,request)
            schedule=request.schedule;validation=schedule.validate(request.horizon);validation.throwIfInvalid();[eventTimes,order]=schedule.sorted();bounds=unique([0;eventTimes;request.horizon]);T=[];Y=[];events=struct([]);x=request.initial_state(:);
            for k=2:numel(bounds),span=[bounds(k-1),bounds(k)];if span(2)>span(1),[tp,yp]=ode45(@(t,s)system.flow(t,s,system.modeAt((span(1)+span(2))/2),request.parameters),span,x,request.ode_options);if ~isempty(T),tp(1)=[];yp(1,:)=[];end;T=[T;tp];Y=[Y;yp];x=yp(end,:).';end;hits=find(eventTimes==bounds(k));for h=hits(:).',pre=x;idx=order(h);x=system.reset(schedule.Names{idx},x,request.parameters);T=[T;bounds(k);bounds(k)];Y=[Y;pre.';x.'];e=lmz.hybrid.EventLog.record(schedule.Names{idx},bounds(k),idx,pre,x,schedule.Types{idx});if isempty(events),events=e;else,events(end+1)=e;end;end,end
            result=struct('time',T,'state',Y,'state_schema',request.state_schema,'mode_history',[],'event_log',events,'channels',struct(),'parameters',request.parameters,'observables',struct(),'diagnostics',struct('finite',all(isfinite(Y(:))),'event_order_valid',true),'provenance',lmz.io.Provenance.capture());
        end
    end
end
