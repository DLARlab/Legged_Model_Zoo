classdef PoincareReturnMap
    %POINCARERETURNMAP Evaluate a trusted propagator between two sections.
    properties (SetAccess = private)
        StartSection
        StopSection
        Symmetry
        StateSchema
        StrideDefinition
    end

    methods
        function obj = PoincareReturnMap(startSection, stopSection, ...
                symmetry, stateSchema, strideDefinition)
            if ~isa(startSection, 'lmz.poincare.PoincareSection') || ...
                    ~isa(stopSection, 'lmz.poincare.PoincareSection')
                error('lmz:Poincare:ReturnMapSections', ...
                    'Return-map endpoints must be PoincareSection objects.');
            end
            if ~isa(symmetry, 'lmz.poincare.StateSymmetry') || ...
                    ~isa(stateSchema, 'lmz.schema.VariableSchema')
                error('lmz:Poincare:ReturnMapContract', ...
                    'Return map requires a state symmetry and state schema.');
            end
            if nargin < 5 || isempty(strideDefinition)
                strideDefinition = lmz.poincare.StrideDefinition.fromSections( ...
                    startSection, stopSection, symmetry.Id);
            elseif ~isa(strideDefinition, 'lmz.poincare.StrideDefinition')
                strideDefinition = ...
                    lmz.poincare.StrideDefinition(strideDefinition);
            end
            if ~strcmp(strideDefinition.StartSectionId, startSection.Id) || ...
                    ~strcmp(strideDefinition.StopSectionId, stopSection.Id) || ...
                    ~strcmp(strideDefinition.SymmetryId, symmetry.Id)
                error('lmz:Poincare:ReturnMapStride', ...
                    'Stride definition is incompatible with the return map.');
            end
            obj.StartSection = startSection;
            obj.StopSection = stopSection;
            obj.Symmetry = symmetry;
            obj.StateSchema = stateSchema;
            obj.StrideDefinition = strideDefinition;
        end

        function result = evaluate(obj, initialState, parameters, ...
                propagationFcn, context)
            if nargin < 5 || isempty(context)
                context = lmz.api.RunContext.synchronous(0);
            end
            if ~isa(context, 'lmz.api.RunContext') || ...
                    ~isa(propagationFcn, 'function_handle')
                error('lmz:Poincare:ReturnMapPropagator', ...
                    'Return map requires a trusted propagator and RunContext.');
            end
            obj.StateSchema.validateVector(initialState);
            initialState = initialState(:);
            context.check();
            output = propagationFcn(initialState, parameters, ...
                obj.StrideDefinition, context);
            if isa(output, 'lmz.poincare.PoincareReturnResult')
                result = output;
                return
            end
            [simulation, crossing, ~, diagnostics, startCrossing] = ...
                obj.normalizePropagation(output);
            if isempty(crossing)
                crossing = obj.locateCrossing(simulation);
            end
            if isempty(crossing)
                error('lmz:Poincare:ReturnNotFound', ...
                    'No accepted stop-section crossing was found.');
            end
            eventHistory = localField(diagnostics, 'EventHistory', ...
                localField(crossing.Metadata, 'EventHistory', {}));
            [accepted, reason] = obj.StopSection.acceptCrossing( ...
                crossing, eventHistory);
            crossing = crossing.withAcceptance(accepted, reason);
            if ~accepted
                error('lmz:Poincare:RejectedReturn', ...
                    'Stop-section crossing was rejected: %s', reason);
            end
            if ~isempty(simulation)
                [simulation,truncated]=localTruncateSimulation( ...
                    simulation,crossing);
            else
                truncated=false;
            end
            terminalState = crossing.State(:);
            obj.StateSchema.validateVector(terminalState);
            aligned = obj.Symmetry.align( ...
                terminalState, initialState, obj.StateSchema);
            initialCoordinates = obj.StartSection.coordinates( ...
                initialState, obj.StateSchema);
            returnCoordinates = obj.StopSection.coordinates( ...
                aligned, obj.StateSchema);
            if numel(initialCoordinates) ~= numel(returnCoordinates)
                error('lmz:Poincare:ReturnCoordinateDimension', ...
                    'Start and stop section coordinate dimensions differ.');
            end
            residual = returnCoordinates - initialCoordinates;
            returnTime = crossing.Time;
            if isempty(startCrossing)
                startCrossing = lmz.poincare.SectionCrossing( ...
                    obj.StartSection.Id, 0, ...
                    'PreState', initialState, 'PostState', initialState, ...
                    'StateSide', obj.StrideDefinition.StartStateSide, ...
                    'Occurrence', 1, 'Accepted', true, ...
                    'Metadata', struct('InitialSectionState', true));
            end
            diagnostics.SymmetryDisplacement = obj.Symmetry.displacement( ...
                terminalState, initialState, obj.StateSchema);
            diagnostics.StartSectionId = obj.StartSection.Id;
            diagnostics.StopSectionId = obj.StopSection.Id;
            diagnostics.SectionTerminationPolicy = ...
                lmz.simulation.SectionTerminationPolicy( ...
                obj.StopSection).toStruct();
            diagnostics.TerminatedAtAcceptedCrossing = true;
            diagnostics.TrajectoryTruncated = truncated;
            diagnostics.TransversalityStatus = localField( ...
                crossing.Metadata, 'TransversalityStatus', 'unavailable');
            value = struct('InitialState', initialState, ...
                'TerminalState', terminalState, ...
                'AlignedTerminalState', aligned, ...
                'InitialCoordinates', initialCoordinates, ...
                'ReturnCoordinates', returnCoordinates, ...
                'PeriodicResidual', residual, 'ReturnTime', returnTime, ...
                'StartCrossing', startCrossing, ...
                'StopCrossing', crossing, 'Simulation', simulation, ...
                'Diagnostics', diagnostics, ...
                'StrideDefinition', obj.StrideDefinition, ...
                'StartSectionDescriptor', obj.StartSection.toStruct(), ...
                'StopSectionDescriptor', obj.StopSection.toStruct(), ...
                'SymmetryDescriptor', obj.Symmetry.toStruct());
            result = lmz.poincare.PoincareReturnResult(value);
            context.progress(1, 'Poincare return map complete.');
        end

        function value = periodicResidual(obj, initialState, terminalState)
            obj.StateSchema.validateVector(initialState);
            obj.StateSchema.validateVector(terminalState);
            aligned = obj.Symmetry.align( ...
                terminalState, initialState, obj.StateSchema);
            first = obj.StartSection.coordinates(initialState, obj.StateSchema);
            second = obj.StopSection.coordinates(aligned, obj.StateSchema);
            if numel(first) ~= numel(second)
                error('lmz:Poincare:ReturnCoordinateDimension', ...
                    'Start and stop section coordinate dimensions differ.');
            end
            value = second - first;
        end
    end

    methods (Access = private)
        function [simulation, crossing, returnTime, diagnostics, ...
                startCrossing] = normalizePropagation(obj, output)
            crossing = [];
            returnTime = [];
            diagnostics = struct();
            startCrossing = [];
            if isa(output, 'lmz.api.SimulationResult')
                simulation = output;
                return
            end
            if ~isstruct(output) || ~isscalar(output)
                error('lmz:Poincare:PropagationResult', ...
                    ['Poincare propagator must return SimulationResult, ' ...
                    'PoincareReturnResult, or a scalar struct.']);
            end
            simulation = localField(output, 'Simulation', []);
            crossing = localField(output, 'StopCrossing', ...
                localField(output, 'Crossing', []));
            returnTime = localField(output, 'ReturnTime', []);
            diagnostics = localField(output, 'Diagnostics', struct());
            startCrossing = localField(output, 'StartCrossing', []);
            if ~isempty(simulation) && ...
                    ~isa(simulation, 'lmz.api.SimulationResult')
                error('lmz:Poincare:PropagationSimulation', ...
                    'Propagation Simulation has an invalid type.');
            end
            if ~isempty(crossing) && ...
                    ~isa(crossing, 'lmz.poincare.SectionCrossing')
                error('lmz:Poincare:PropagationCrossing', ...
                    'Propagation crossing has an invalid type.');
            end
            if isempty(crossing) && isfield(output, 'TerminalState')
                terminal = output.TerminalState;
                obj.StateSchema.validateVector(terminal);
                if isempty(returnTime)
                    error('lmz:Poincare:PropagationReturnTime', ...
                        'TerminalState propagation requires ReturnTime.');
                end
                crossing = lmz.poincare.SectionCrossing( ...
                    obj.StopSection.Id, returnTime, ...
                    'PreState', terminal, 'PostState', terminal, ...
                    'StateSide', obj.StrideDefinition.StopStateSide, ...
                    'CrossingDirection', obj.StopSection.CrossingDirection, ...
                    'Occurrence', obj.StopSection.ReturnOccurrence, ...
                    'Metadata', struct('TransversalityStatus', 'unavailable'));
            end
            if ~isstruct(diagnostics) || ~isscalar(diagnostics)
                error('lmz:Poincare:PropagationDiagnostics', ...
                    'Propagation diagnostics must be a scalar struct.');
            end
        end

        function crossing = locateCrossing(obj, simulation)
            crossing = [];
            if isempty(simulation)
                return
            end
            if isa(obj.StopSection, 'lmz.poincare.NamedEventSection') || ...
                    (isa(obj.StopSection, 'lmz.poincare.CompositeSection') && ...
                    isa(obj.StopSection.Primary, ...
                    'lmz.poincare.NamedEventSection'))
                crossing = obj.locateNamedEvent(simulation);
            elseif isa(obj.StopSection, ...
                    'lmz.poincare.StateFunctionSection') || ...
                    (isa(obj.StopSection, 'lmz.poincare.CompositeSection') && ...
                    isa(obj.StopSection.Primary, ...
                    'lmz.poincare.StateFunctionSection'))
                crossing = obj.locateStatePlane(simulation);
            else
                error('lmz:Poincare:ReturnLocator', ...
                    'Custom sections require an explicit crossing.');
            end
        end

        function crossing = locateNamedEvent(obj, simulation)
            crossing = [];
            records = simulation.EventRecords;
            if isempty(records)
                return
            end
            times = [records.Time];
            [~, order] = sortrows([times(:), (1:numel(records)).'], [1 2]);
            records = records(order);
            history = {};
            occurrence = 0;
            initialRecord = [];
            policy = lmz.simulation.SectionTerminationPolicy( ...
                obj.StopSection);
            for index = 1:numel(records)
                record = records(index);
                if obj.StopSection.matches(record)
                    if record.Time <= policy.InitialRootTolerance
                        initialRecord = record;
                        continue
                    end
                    occurrence = occurrence + 1;
                    candidate = obj.StopSection.crossingFromRecord(record, ...
                        'Occurrence', occurrence, 'EventHistory', history);
                    [accepted,~] = policy.accept(candidate,history);
                    if accepted
                        crossing = candidate.withAcceptance(true,'');
                        return
                    end
                end
                history{end + 1} = localEventId(record); %#ok<AGROW>
            end
            if isempty(crossing) && ~isempty(initialRecord) && ...
                    strcmp(obj.StartSection.Id,obj.StopSection.Id)
                endpoint = initialRecord;
                endpoint.Time = simulation.Time(end);
                endpoint.State = simulation.States(end,:).';
                endpoint.PreState = endpoint.State;
                endpoint.PostState = endpoint.State;
                candidate = obj.StopSection.crossingFromRecord(endpoint, ...
                    'Occurrence',1,'EventHistory',history);
                [accepted,~] = policy.accept(candidate,history);
                if accepted
                    crossing = candidate.withAcceptance(true,'');
                end
            end
        end

        function crossing = locateStatePlane(obj, simulation)
            crossing = [];
            eventHistory = simulation.EventRecords;
            occurrence = 0;
            policy = lmz.simulation.SectionTerminationPolicy( ...
                obj.StopSection);
            for index = 1:numel(simulation.Time) - 1
                modeId = localMode(simulation.Modes, index);
                history = localEventsBefore(eventHistory, simulation.Time(index));
                [detected, candidate] = obj.StopSection.detectCrossing( ...
                    simulation.Time(index), simulation.States(index, :).', ...
                    simulation.Time(index + 1), ...
                    simulation.States(index + 1, :).', 'ModeId', modeId, ...
                    'Occurrence', occurrence + 1, 'EventHistory', history);
                if detected
                    occurrence = occurrence + 1;
                    [accepted,~] = policy.accept(candidate,history);
                    if accepted
                        crossing = candidate.withAcceptance(true,'');
                        return
                    end
                end
            end
        end
    end
end

function [result,truncated]=localTruncateSimulation(source,crossing)
time=source.Time;target=crossing.Time;
tolerance=64*eps(max(1,abs(target)));
if target>=time(end)-tolerance
    result=source;truncated=false;return
end
before=find(time<target-tolerance);
at=find(abs(time-target)<=tolerance,1);
if isempty(at)
    indices=before;
    newTime=[time(indices);target];
    newStates=[source.States(indices,:);crossing.State(:).'];
    append=true;
else
    indices=[before;at];
    newTime=time(indices);
    newStates=source.States(indices,:);
    newStates(end,:)=crossing.State(:).';
    append=false;
end
newModes=localTruncateModes(source.Modes,indices,append,crossing, ...
    numel(time));
records=source.EventRecords;
if ~isempty(records)
    records=records([records.Time]<=target+tolerance);
end
forces=[];
if ~isempty(source.GroundReactionForces)
    forces=source.GroundReactionForces(indices,:);
    crossingForce=interp1(time,source.GroundReactionForces,target,'linear');
    if append,forces=[forces;crossingForce];else,forces(end,:)=crossingForce;end
end
kinematics=localTruncateSampled(source.Kinematics,indices,append, ...
    time,target);
diagnostics=source.Diagnostics;
diagnostics.SectionTermination=struct('SectionId',crossing.SectionId, ...
    'AcceptedTime',target,'SourceEndTime',time(end), ...
    'SourceSampleCount',numel(time), ...
    'ReturnedSampleCount',numel(newTime));
result=lmz.api.SimulationResult(newTime,source.StateSchema,newStates, ...
    newModes,source.Observables,source.Parameters,diagnostics, ...
    source.Provenance,'EventRecords',records, ...
    'GroundReactionForces',forces,'Kinematics',kinematics);
truncated=true;
end

function value=localTruncateModes(source,indices,append,crossing,total)
value=source;
if iscell(source)&&numel(source)==total
    value=source(indices);
    final=localCrossingMode(crossing);
    if isempty(final)&&~isempty(value),final=value{end};end
    if append,value=[value;{final}];elseif ~isempty(value),value{end}=final;end
elseif isstring(source)&&numel(source)==total
    value=source(indices);
    final=string(localCrossingMode(crossing));
    if append,value=[value;final];elseif ~isempty(value),value(end)=final;end
elseif isstruct(source)&&isscalar(source)
    names=fieldnames(source);
    for index=1:numel(names)
        item=source.(names{index});
        if numel(item)==total
            item=item(:);item=item(indices);
            if append
                expanded=repmat(item(1),numel(item)+1,1);
                expanded(1:end-1)=item;
                expanded(end)=item(end);
                item=expanded;
            end
            value.(names{index})=item;
        end
    end
end
end

function value=localCrossingMode(crossing)
if strcmp(crossing.StateSide,'pre'),value=crossing.ModeBefore; ...
else,value=crossing.ModeAfter;end
end

function value=localTruncateSampled(source,indices,append,time,target)
value=source;
if ~isstruct(source)||~isscalar(source),return,end
names=fieldnames(source);
for index=1:numel(names)
    item=source.(names{index});
    if isnumeric(item)&&size(item,1)==numel(time)
        selected=item(indices,:);
        endpoint=interp1(time,item,target,'linear');
        if append
            expanded=zeros(size(selected,1)+1,size(selected,2), ...
                'like',selected);
            expanded(1:end-1,:)=selected;
            expanded(end,:)=endpoint;
            selected=expanded;
        else
            selected(end,:)=endpoint;
        end
        value.(names{index})=selected;
    elseif iscell(item)&&size(item,1)==numel(time)
        selected=item(indices,:);
        if append
            expanded=cell(size(selected,1)+1,size(selected,2));
            expanded(1:end-1,:)=selected;
            expanded(end,:)=selected(end,:);
            selected=expanded;
        end
        value.(names{index})=selected;
    end
end
end

function value = localField(source, name, fallback)
if isstruct(source) && isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end

function value = localEventId(record)
if isfield(record, 'Id')
    value = record.Id;
elseif isfield(record, 'Name')
    value = record.Name;
else
    value = '';
end
end

function value = localEventsBefore(records, time)
value = {};
for index = 1:numel(records)
    if isfield(records(index), 'Time') && records(index).Time < time
        value{end + 1} = localEventId(records(index)); %#ok<AGROW>
    end
end
end

function value = localMode(modes, index)
value = '';
if iscell(modes) && numel(modes) >= index && ischar(modes{index})
    value = modes{index};
elseif isstring(modes) && numel(modes) >= index
    value = char(modes(index));
end
end
