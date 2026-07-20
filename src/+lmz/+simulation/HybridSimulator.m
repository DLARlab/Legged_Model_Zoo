classdef HybridSimulator
    %HYBRIDSIMULATOR Generic deterministic scheduled/guard hybrid integrator.
    methods
        function result = simulate(~, system, request, context, options)
            if ~isa(system, 'lmz.simulation.HybridSystem')
                error('lmz:Hybrid:System', 'A HybridSystem implementation is required.');
            end
            if nargin < 4 || isempty(context)
                context = lmz.api.RunContext.synchronous(0);
            end
            if nargin < 5
                options = struct();
            end
            options = lmz.simulation.HybridSimulator.options(options);
            if ~isstruct(request) || ~isscalar(request) || ...
                    ~isfield(request, 'TimeSpan') || ~isfield(request, 'Parameters')
                error('lmz:Hybrid:Request', ...
                    'Hybrid request requires TimeSpan and Parameters.');
            end
            span = request.TimeSpan(:).';
            if numel(span) ~= 2 || any(~isfinite(span)) || span(2) <= span(1)
                error('lmz:Hybrid:TimeSpan', ...
                    'TimeSpan must contain finite increasing endpoints.');
            end
            schema = system.stateSchema();
            if ~isa(schema, 'lmz.schema.VariableSchema')
                error('lmz:Hybrid:StateSchema', ...
                    'Hybrid stateSchema must return VariableSchema.');
            end
            state = system.initialState(request);
            schema.validateVector(state);
            state = state(:);
            modeId = system.initialMode(request);
            system.mode(modeId);
            policy = system.eventPolicy(request);
            context.check();

            time = span(1);
            states = state.';
            modes = {modeId};
            records = lmz.simulation.HybridSimulator.emptyRecords();
            currentTime = span(1);
            processed = false(0, 1);
            if isa(policy, 'lmz.simulation.ScheduledEventPolicy')
                processed = false(numel(policy.Events), 1);
            elseif ~isa(policy, 'lmz.simulation.GuardEventPolicy')
                error('lmz:Hybrid:EventPolicy', ...
                    'Event policy must be scheduled or guard based.');
            end
            terminalRequested = false;
            while currentTime < span(2) && ~terminalRequested
                context.check();
                scheduledEvents = lmz.simulation.HybridEvent.empty(0, 1);
                scheduledIndices = [];
                targetTime = span(2);
                if isa(policy, 'lmz.simulation.ScheduledEventPolicy')
                    [scheduledEvents, scheduledIndices] = policy.next( ...
                        currentTime, span(2), modeId, processed);
                    if ~isempty(scheduledEvents)
                        targetTime = scheduledEvents(1).Time;
                    end
                end
                [segmentTime, segmentStates, detectedEvents] = ...
                    lmz.simulation.HybridSimulator.integrateSegment( ...
                    system.mode(modeId), policy, currentTime, targetTime, ...
                    state, request.Parameters, context, options, modeId, ...
                    span(1), span(2));
                if numel(segmentTime) > 1
                    time = [time; segmentTime(2:end)]; %#ok<AGROW>
                    states = [states; segmentStates(2:end, :)]; %#ok<AGROW>
                    modes = [modes; repmat({modeId}, ...
                        numel(segmentTime) - 1, 1)]; %#ok<AGROW>
                end
                state = segmentStates(end, :).';
                currentTime = segmentTime(end);
                events = scheduledEvents;
                if ~isempty(detectedEvents)
                    events = detectedEvents;
                elseif isa(policy, 'lmz.simulation.ScheduledEventPolicy') && ...
                        ~isempty(scheduledIndices)
                    processed(scheduledIndices) = true;
                end
                if isempty(events)
                    break
                end
                for eventIndex = 1:numel(events)
                    event = events(eventIndex);
                    if ~isempty(event.FromMode) && ...
                            ~strcmp(event.FromMode, modeId)
                        continue
                    end
                    preState = state;
                    reset = system.resetMap(event.ResetId);
                    if isempty(reset)
                        postState = preState;
                        resetApplied = false;
                    else
                        if ~isa(reset, 'lmz.simulation.ResetMap')
                            error('lmz:Hybrid:ResetMap', ...
                                'resetMap must return ResetMap or empty.');
                        end
                        postState = reset.apply(event, currentTime, ...
                            preState, request.Parameters, context);
                        schema.validateVector(postState);
                        postState = postState(:);
                        resetApplied = true;
                    end
                    previousMode = modeId;
                    if ~isempty(event.ToMode)
                        modeId = event.ToMode;
                        system.mode(modeId);
                    end
                    record = struct('Id', event.Id, ...
                        'Index', numel(records) + 1, 'Time', currentTime, ...
                        'Priority', event.Priority, ...
                        'FromMode', previousMode, 'ToMode', modeId, ...
                        'PreState', preState, 'PostState', postState, ...
                        'ResetApplied', resetApplied, ...
                        'Terminal', event.Terminal, ...
                        'Metadata', event.Metadata);
                    records(end + 1, 1) = record; %#ok<AGROW>
                    state = postState;
                    terminalRequested = terminalRequested || event.Terminal;
                end
                states(end, :) = state.';
                modes{end} = modeId;
                if terminalRequested
                    break
                end
                if currentTime >= span(2)
                    break
                end
            end
            if any(diff(time) <= 0)
                error('lmz:Hybrid:DuplicateTime', ...
                    'Hybrid public trajectory must be strictly increasing.');
            end
            outputs = system.namedOutputs( ...
                time, states, modes, records, request);
            outputs = lmz.simulation.HybridSimulator.completeOutputs( ...
                outputs, request);
            result = lmz.api.SimulationResult(time, schema, states, modes, ...
                outputs.Observables, outputs.Parameters, outputs.Diagnostics, ...
                outputs.Provenance, 'EventRecords', records, ...
                'GroundReactionForces', outputs.GroundReactionForces, ...
                'Kinematics', outputs.Kinematics);
            context.progress(1, 'Hybrid simulation complete.');
        end
    end

    methods (Static, Access = private)
        function [time, states, events] = integrateSegment(mode, policy, ...
                startTime, finalTime, initialState, parameters, context, ...
                options, modeId, progressStartTime, progressFinalTime)
            if finalTime <= startTime
                time = startTime;
                states = initialState.';
                events = lmz.simulation.HybridEvent.empty(0, 1);
                return
            end
            odeOptions = odeset('RelTol', options.RelativeTolerance, ...
                'AbsTol', options.AbsoluteTolerance, ...
                'MaxStep', options.MaximumStep, ...
                'OutputFcn', @(t, y, flag) ...
                lmz.simulation.HybridSimulator.cancellationOutput( ...
                t, y, flag, context, ...
                progressStartTime, progressFinalTime));
            if isa(policy, 'lmz.simulation.GuardEventPolicy')
                odeOptions = odeset(odeOptions, 'Events', ...
                    @(t, x) guardValues(t, x, policy, modeId, ...
                    parameters, context));
            end
            derivative = @(t, x) mode.derivative(t, x, parameters, context);
            if isa(policy, 'lmz.simulation.GuardEventPolicy')
                [time, states, eventTime, ~, eventIndices] = ode45( ...
                    derivative, [startTime finalTime], initialState, odeOptions);
                if isempty(eventTime)
                    events = lmz.simulation.HybridEvent.empty(0, 1);
                else
                    [~, ~, ~, mapping] = policy.evaluate( ...
                        eventTime(1), states(end, :).', modeId, ...
                        parameters, context);
                    simultaneous = abs(eventTime - eventTime(1)) <= ...
                        32 * eps(max(1, abs(eventTime(1))));
                    events = policy.detected(mapping, ...
                        eventIndices(simultaneous), eventTime(1));
                end
            else
                [time, states] = ode45(derivative, ...
                    [startTime finalTime], initialState, odeOptions);
                events = lmz.simulation.HybridEvent.empty(0, 1);
            end
        end

        function stop = cancellationOutput(time, ~, flag, context, ...
                startTime, finalTime)
            stop = false;
            if isempty(flag)
                fraction = (time(end) - startTime) / ...
                    (finalTime - startTime);
                context.progress(max(0, min(1, fraction)), ...
                    'Integrating hybrid mode.');
                context.check();
            end
        end

        function options = options(options)
            defaults = struct('RelativeTolerance', 1e-9, ...
                'AbsoluteTolerance', 1e-11, 'MaximumStep', 0.02, ...
                'DuplicateTimePolicy', 'post');
            if ~isstruct(options) || ~isscalar(options)
                error('lmz:Hybrid:Options', 'Hybrid options must be a scalar struct.');
            end
            names = fieldnames(options);
            for index = 1:numel(names)
                if ~isfield(defaults, names{index})
                    error('lmz:Hybrid:OptionName', ...
                        'Unknown hybrid option: %s', names{index});
                end
                defaults.(names{index}) = options.(names{index});
            end
            if ~strcmp(defaults.DuplicateTimePolicy, 'post') || ...
                    any(~isfinite([defaults.RelativeTolerance, ...
                    defaults.AbsoluteTolerance, defaults.MaximumStep])) || ...
                    any([defaults.RelativeTolerance, ...
                    defaults.AbsoluteTolerance, defaults.MaximumStep] <= 0)
                error('lmz:Hybrid:OptionValue', ...
                    'Hybrid tolerances/step or duplicate-time policy is invalid.');
            end
            options = defaults;
        end

        function outputs = completeOutputs(outputs, request)
            if ~isstruct(outputs) || ~isscalar(outputs)
                error('lmz:Hybrid:NamedOutputs', ...
                    'namedOutputs must return a scalar struct.');
            end
            defaults = struct('Observables', struct(), ...
                'Parameters', request.Parameters, 'Diagnostics', struct(), ...
                'Provenance', struct('source', 'generic-hybrid-system'), ...
                'GroundReactionForces', [], 'Kinematics', struct());
            names = fieldnames(defaults);
            for index = 1:numel(names)
                if ~isfield(outputs, names{index})
                    outputs.(names{index}) = defaults.(names{index});
                end
            end
        end

        function records = emptyRecords()
            records = struct('Id', {}, 'Index', {}, 'Time', {}, ...
                'Priority', {}, 'FromMode', {}, 'ToMode', {}, ...
                'PreState', {}, 'PostState', {}, 'ResetApplied', {}, ...
                'Terminal', {}, 'Metadata', {});
        end
    end
end

function [value, terminal, direction] = guardValues(time, state, policy, ...
        modeId, parameters, context)
[value, terminal, direction] = policy.evaluate( ...
    time, state, modeId, parameters, context);
end
