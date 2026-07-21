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
            % Assign fields individually so cell-valued modes remain one
            % scalar artifact record instead of expanding a struct array.
            value = struct();
            value.time = obj.Time;
            value.stateSchema = obj.StateSchema.toStruct();
            value.states = obj.States;
            value.modes = obj.Modes;
            value.observables = obj.Observables;
            value.parameters = obj.Parameters;
            value.diagnostics = obj.Diagnostics;
            value.provenance = obj.Provenance;
            value.eventRecords = obj.EventRecords;
            value.groundReactionForces = obj.GroundReactionForces;
            value.kinematics = obj.Kinematics;
        end
    end

    methods (Static)
        function obj = fromStruct(value)
            required = {'time','stateSchema','states','modes','observables', ...
                'parameters','diagnostics','provenance'};
            if ~isstruct(value) || ~isscalar(value) || ...
                    ~all(isfield(value, required))
                error('lmz:Simulation:StoredResult', ...
                    'Stored simulation data are incomplete.');
            end
            eventRecords = struct([]);
            if isfield(value, 'eventRecords')
                eventRecords = value.eventRecords;
            end
            groundReactionForces = [];
            if isfield(value, 'groundReactionForces')
                groundReactionForces = value.groundReactionForces;
            end
            kinematics = struct();
            if isfield(value, 'kinematics')
                kinematics = value.kinematics;
            end
            schema = value.stateSchema;
            if isstruct(schema)
                schema = lmz.schema.VariableSchema.fromStruct(schema);
            end
            obj = lmz.api.SimulationResult(value.time, schema, value.states, ...
                value.modes, value.observables, value.parameters, ...
                value.diagnostics, value.provenance, ...
                'EventRecords', eventRecords, ...
                'GroundReactionForces', groundReactionForces, ...
                'Kinematics', kinematics);
        end
    end
end
