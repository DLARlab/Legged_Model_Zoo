classdef HopperSystem < lmz.simulation.HybridSystem
    %HOPPERSYSTEM Scheduled-impact analytic hybrid system.
    methods
        function value = stateSchema(~)
            value = ...
                lmzmodels.tutorial_hopper.PhysicalStateSchema.create();
        end

        function value = initialState(~, request)
            decision = request.Decision;
            initialX=0;if isfield(decision,'initial_x'),initialX=decision.initial_x;end
            initialVy=0;if isfield(decision,'initial_vertical_speed'), ...
                    initialVy=decision.initial_vertical_speed;end
            value = [initialX; decision.horizontal_speed; ...
                decision.apex_height; initialVy];
        end

        function value = initialMode(~, ~)
            value = 'flight_down';
        end

        function value = mode(~, modeId)
            if ~any(strcmp(modeId, {'flight_down','flight_up'}))
                error('lmz:tutorial_hopper:Mode', ...
                    'Unknown hopper mode %s.', modeId);
            end
            value = lmzmodels.tutorial_hopper.FlightMode(modeId);
        end

        function value = eventPolicy(~, request)
            impactTime=request.Decision.stride_period/2;
            if isfield(request.Decision,'impact_time')
                impactTime=request.Decision.impact_time;
            end
            event = lmz.simulation.HybridEvent('impact', ...
                impactTime, ...
                'Priority', 0, 'DeclarationOrder', 1, ...
                'FromMode', 'flight_down', 'ToMode', 'flight_up', ...
                'ResetId', 'impact');
            value = lmz.simulation.ScheduledEventPolicy(event);
        end

        function value = resetMap(~, eventId)
            if strcmp(eventId, 'impact')
                value = lmzmodels.tutorial_hopper.ImpactReset();
            else
                value = [];
            end
        end

        function value = namedOutputs(~, time, states, modes, ...
                eventRecords, request)
            value = struct();
            value.Observables = struct( ...
                'horizontal_position', states(:, 1), ...
                'height', states(:, 3), ...
                'vertical_speed', states(:, 4), ...
                'mode_history', {modes}, ...
                'event_count', numel(eventRecords));
            value.Parameters = request.Parameters;
            value.Diagnostics = struct( ...
                'engine', 'lmz.simulation.HybridSimulator', ...
                'duplicateTimePolicy', 'post', ...
                'sampleCount', numel(time));
            value.Provenance = struct( ...
                'modelId', 'tutorial_hopper', ...
                'problemId', request.ProblemId, ...
                'source', 'built-in-analytic-tutorial');
            value.Kinematics = struct('Body', states(:, [1 3]));
        end
    end
end
