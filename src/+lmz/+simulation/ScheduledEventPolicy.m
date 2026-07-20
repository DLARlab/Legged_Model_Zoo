classdef ScheduledEventPolicy
    %SCHEDULEDEVENTPOLICY Deterministic time/priority/declaration ordering.
    properties (SetAccess = private)
        Events = lmz.simulation.HybridEvent.empty(0, 1)
    end
    methods
        function obj = ScheduledEventPolicy(events)
            if nargin < 1 || isempty(events)
                return
            end
            if ~isa(events, 'lmz.simulation.HybridEvent')
                error('lmz:Hybrid:ScheduledEvents', ...
                    'Scheduled events must be HybridEvent values.');
            end
            events = events(:);
            keys = [[events.Time].', [events.Priority].', ...
                [events.DeclarationOrder].', (1:numel(events)).'];
            [~, order] = sortrows(keys, [1 2 3 4]);
            obj.Events = events(order);
        end

        function [events, indices] = next(obj, currentTime, finalTime, ...
                modeId, processed)
            if nargin < 5 || isempty(processed)
                processed = false(numel(obj.Events), 1);
            end
            eligible = false(numel(obj.Events), 1);
            tolerance = 32 * eps(max(1, max(abs([currentTime finalTime]))));
            for index = 1:numel(obj.Events)
                event = obj.Events(index);
                modeMatch = isempty(event.FromMode) || ...
                    strcmp(event.FromMode, modeId);
                eligible(index) = ~processed(index) && modeMatch && ...
                    event.Time > currentTime + tolerance && ...
                    event.Time <= finalTime + tolerance;
            end
            indices = find(eligible);
            if isempty(indices)
                events = lmz.simulation.HybridEvent.empty(0, 1);
                return
            end
            firstTime = obj.Events(indices(1)).Time;
            same = arrayfun(@(index) abs(obj.Events(index).Time - firstTime) ...
                <= tolerance, indices);
            indices = indices(same);
            events = obj.Events(indices);
        end
    end
end
