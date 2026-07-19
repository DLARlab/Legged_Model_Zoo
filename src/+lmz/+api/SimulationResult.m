classdef SimulationResult
    %SIMULATIONRESULT Named, validated output of physical simulation.
    properties (SetAccess=private)
        Time
        StateSchema
        States
        Modes
        Observables
        Parameters
        Diagnostics
        Provenance
    end
    methods
        function obj = SimulationResult(time, stateSchema, states, modes, ...
                observables, parameters, diagnostics, provenance)
            if ~isnumeric(time) || ~iscolumn(time) || any(~isfinite(time)) || ...
                    any(diff(time) <= 0)
                error('lmz:Simulation:InvalidTime', ...
                    'Time must be a finite strictly increasing column.');
            end
            if ~isa(stateSchema, 'lmz.schema.VariableSchema') || ...
                    ~isnumeric(states) || size(states, 1) ~= numel(time) || ...
                    size(states, 2) ~= stateSchema.count() || ...
                    any(~isfinite(states(:)))
                error('lmz:Simulation:InvalidStates', ...
                    'State matrix dimensions must match time and state schema.');
            end
            obj.Time = time;
            obj.StateSchema = stateSchema;
            obj.States = states;
            obj.Modes = modes;
            obj.Observables = observables;
            obj.Parameters = parameters;
            obj.Diagnostics = diagnostics;
            obj.Provenance = provenance;
        end

        function values = state(obj, name)
            values = obj.States(:, obj.StateSchema.indexOf(name));
        end

        function value = toStruct(obj)
            value = struct('time', obj.Time, ...
                'stateSchema', obj.StateSchema.toStruct(), ...
                'states', obj.States, 'modes', obj.Modes, ...
                'observables', obj.Observables, ...
                'parameters', obj.Parameters, ...
                'diagnostics', obj.Diagnostics, ...
                'provenance', obj.Provenance);
        end
    end
end
