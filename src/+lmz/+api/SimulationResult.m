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
        EventRecords
        GroundReactionForces
        Kinematics
    end
    methods
        function obj = SimulationResult(time, stateSchema, states, modes, ...
                observables, parameters, diagnostics, provenance, varargin)
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
            parser = inputParser;
            addParameter(parser,'EventRecords',struct([]));
            addParameter(parser,'GroundReactionForces',[]);
            addParameter(parser,'Kinematics',struct());
            parse(parser,varargin{:});
            if ~isstruct(parser.Results.EventRecords)
                error('lmz:Simulation:InvalidEvents','EventRecords must be a struct array.');
            end
            forces=parser.Results.GroundReactionForces;
            if ~isempty(forces) && (~isnumeric(forces) || size(forces,1)~=numel(time) || ...
                    any(~isfinite(forces(:))))
                error('lmz:Simulation:InvalidForces', ...
                    'Ground-reaction-force rows must match simulation time.');
            end
            if ~isstruct(parser.Results.Kinematics)
                error('lmz:Simulation:InvalidKinematics','Kinematics must be a struct.');
            end
            obj.EventRecords = parser.Results.EventRecords;
            obj.GroundReactionForces = parser.Results.GroundReactionForces;
            obj.Kinematics = parser.Results.Kinematics;
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
                'provenance', obj.Provenance, ...
                'eventRecords', obj.EventRecords, ...
                'groundReactionForces', obj.GroundReactionForces, ...
                'kinematics', obj.Kinematics);
        end
    end
end
