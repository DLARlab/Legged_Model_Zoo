classdef HopperSystem < lmz.simulation.HybridSystem
    methods
        function value = stateSchema(~)
            value = lmzplugins.analytic_hopper.PhysicalStateSchema.create();
        end
        function value = initialState(~, request)
            decision = request.Decision;
            value = [0; decision.horizontal_speed; ...
                decision.apex_height; 0];
        end
        function value = initialMode(~, ~)
            value = 'flight_down';
        end
        function value = mode(~, modeId)
            if ~any(strcmp(modeId, {'flight_down','flight_up'}))
                error('analytic_hopper:Mode', 'Unknown hopper mode %s.', modeId);
            end
            value = lmzplugins.analytic_hopper.FlightMode(modeId);
        end
        function value = eventPolicy(~, request)
            event = lmz.simulation.HybridEvent('impact', ...
                request.Decision.stride_period / 2, ...
                'Priority', 0, 'DeclarationOrder', 1, ...
                'FromMode', 'flight_down', 'ToMode', 'flight_up', ...
                'ResetId', 'impact');
            value = lmz.simulation.ScheduledEventPolicy(event);
        end
        function value = resetMap(~, eventId)
            if strcmp(eventId, 'impact')
                value = lmzplugins.analytic_hopper.ImpactReset();
            else
                value = [];
            end
        end
        function value = namedOutputs(~, time, states, modes, ...
                eventRecords, request)
            value = struct();
            value.Observables = struct('horizontal_position', states(:, 1), ...
                'height', states(:, 3), 'vertical_speed', states(:, 4), ...
                'mode_history', {modes}, ...
                'event_count', numel(eventRecords));
            value.Parameters = request.Parameters;
            value.Diagnostics = struct('engine', 'lmz.simulation.HybridSimulator', ...
                'duplicateTimePolicy', 'post', 'sampleCount', numel(time));
            value.Provenance = struct('modelId', 'analytic_hopper', ...
                'problemId', request.ProblemId, ...
                'source', 'external-analytic-plugin-fixture');
            value.Kinematics = struct('Body', states(:, [1 3]));
        end
    end
end
