classdef GenericHybridSystem < lmz.simulation.HybridSystem
    properties (SetAccess = private)
        Policy
        InitialValue
    end
    methods
        function obj = GenericHybridSystem(policy, initialValue)
            obj.Policy = policy; obj.InitialValue = initialValue;
        end
        function value = stateSchema(~)
            value = lmz.schema.VariableSchema( ...
                lmz.schema.VariableSpec('q', 'Scale', 1));
        end
        function value = initialState(obj, ~), value = obj.InitialValue; end
        function value = initialMode(~, ~), value = 'mode_a'; end
        function value = mode(~, modeId)
            if ~any(strcmp(modeId, {'mode_a','mode_b'}))
                error('lmztest:Mode', 'Unknown generic mode.');
            end
            value = lmztest.GenericHybridMode(modeId);
        end
        function value = eventPolicy(obj, ~), value = obj.Policy; end
        function value = resetMap(~, eventId)
            value = lmztest.GenericResetMap(eventId);
        end
        function value = namedOutputs(~, time, states, modes, eventRecords, request)
            value = struct('Observables', struct('q', states(:, 1), ...
                'event_count', numel(eventRecords), 'mode_history', {modes}), ...
                'Parameters', request.Parameters, ...
                'Diagnostics', struct('testFixture', true, 'samples', numel(time)), ...
                'Provenance', struct('modelId', 'generic_test', ...
                'problemId', 'hybrid'));
        end
    end
end
