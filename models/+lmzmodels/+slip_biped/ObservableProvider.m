classdef ObservableProvider
    %OBSERVABLEPROVIDER Named physical quantities derived from one stride.
    methods (Static)
        function value=compute(time,states,decision,raw,subtype)
            if nargin<5,subtype='';end
            period=decision(12);events=mod(decision(8:11),period);
            durations=mod(decision([9 11])-decision([8 10]),period);
            sortedEvents=sort(events);gaps=diff([sortedEvents;sortedEvents(1)+period]);
            strideLength=states(end,1)-states(1,1);
            gait=lmzmodels.slip_biped.GaitClassifier.classify(decision,subtype);
            value=struct('forward_speed',strideLength/period, ...
                'apex_forward_velocity',decision(1),'stride_period',period, ...
                'stride_length',strideLength,'duty_factors',durations(:).'/period, ...
                'event_phases',events(:).'/period,'minimum_event_gap',min(gaps), ...
                'gait_code',gait.Code,'gait_name',gait.Name, ...
                'gait_abbreviation',gait.Abbreviation,'sample_time',time(:));
            if nargin>=4 && ~isempty(raw)
                value.total_energy=raw.Energy;
                value.vertical_grf=raw.GroundReactionForces(:,5:6);
                value.horizontal_grf=raw.GroundReactionForces(:,3:4);
                value.grf_magnitude=raw.GroundReactionForces(:,1:2);
            end
        end
    end
end
