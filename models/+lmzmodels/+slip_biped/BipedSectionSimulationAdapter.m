classdef BipedSectionSimulationAdapter < ...
        lmz.shooting.SectionSimulationAdapter
    %BIPEDSECTIONSIMULATIONADAPTER Direct target-section jerboa return.
    %   The source equations are integrated from the selected section state
    %   with a cyclically rotated event schedule.  The legacy apex endpoint
    %   variable is used only as the requested return time on this path.
    properties (SetAccess=private)
        Codec
        FixedConfiguration
    end

    methods
        function obj=BipedSectionSimulationAdapter(codec,varargin)
            parser=inputParser;
            addRequired(parser,'codec',@(x) isa(x, ...
                'lmzmodels.slip_biped.BipedSectionDecisionCodec')|| ...
                isa(x,['lmzmodels.slip_biped.' ...
                'BipedSectionTransitionDecisionCodec']));
            addParameter(parser,'FixedConfiguration', ...
                struct('k_leg',20,'omega_swing',6.5), ...
                @(x) isstruct(x)&&isscalar(x));
            parse(parser,codec,varargin{:});
            configuration=parser.Results.FixedConfiguration;
            if ~all(isfield(configuration,{'k_leg','omega_swing'}))|| ...
                    ~isnumeric(configuration.k_leg)|| ...
                    ~isscalar(configuration.k_leg)|| ...
                    ~isfinite(configuration.k_leg)||configuration.k_leg<=0|| ...
                    ~isnumeric(configuration.omega_swing)|| ...
                    ~isscalar(configuration.omega_swing)|| ...
                    ~isfinite(configuration.omega_swing)|| ...
                    configuration.omega_swing<=0
                error('lmz:Shooting:BipedConfiguration', ...
                    'Biped section configuration is invalid.');
            end
            obj.Codec=codec;
            obj.FixedConfiguration=configuration;
        end

        function value=evaluate(obj,decision,parameters,context,includeSimulation)
            if nargin<5,includeSimulation=false;end
            request=struct('DecodedDecision',obj.Codec.decode(decision), ...
                'PhysicalParameters',parameters(:),'Configuration',struct(), ...
                'Segment',[],'StartNode',[],'StopNode',[], ...
                'EventSchedule',[],'ControlParameters',[]);
            value=obj.simulateSegment(request,context,includeSimulation);
        end

        function value=simulateSegment(obj,request,context,includeSimulation)
            if nargin<4,includeSimulation=false;end
            if nargin<3||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            context.check();
            decoded=localDecoded(obj.Codec,request);
            parameters=localParameters(request);
            parameterSchema=lmzmodels.slip_biped.OffsetParameterSchema.create();
            parameterSchema.validateVector(parameters);
            initial=decoded.InitialState(:);
            propagationInitial=localStartState(initial, ...
                obj.Codec.StartSection);
            legacyDecision=[propagationInitial(2:end); ...
                decoded.EventTimes(:);decoded.ReturnTime];
            raw=lmzmodels.slip_biped.LegacyBipedEvaluator().evaluate( ...
                legacyDecision,parameters,context,obj.FixedConfiguration);
            [energyResidual,energyDiagnostics]= ...
                localEnergyResidual(raw,request);
            raw=localWorldGauge(raw,initial(1));
            raw=localPhysicalApexRecord(raw, ...
                localApexTime(obj.Codec,decoded));
            [terminal,crossing,records]=localTerminal(raw, ...
                obj.Codec.StopSection);
            stateSchema=obj.Codec.StateCoordinates.PhysicalSchema;
            coordinates=obj.Codec.StopSection.coordinates(terminal,stateSchema);
            sectionResidual=localSectionResidual( ...
                obj.Codec.StopSection,decoded.ReturnTime,terminal,parameters,raw);
            [contactResiduals,contactNames]=localContactResiduals( ...
                raw.Residual(8:11),obj.Codec);
            simulation=[];
            if includeSimulation
                states=raw.States;
                states(1,:)=propagationInitial(:).';
                states(end,:)=terminal(:).';
                observableRaw=raw;
                observableRaw.States=states;
                observables=lmzmodels.slip_biped.ObservableProvider.compute( ...
                    raw.Time,states,legacyDecision,observableRaw,'');
                parameterStruct=parameterSchema.unpack(parameters);
                parameterStruct.k_leg=obj.FixedConfiguration.k_leg;
                parameterStruct.omega_swing= ...
                    obj.FixedConfiguration.omega_swing;
                interim=lmz.api.SimulationResult(raw.Time,stateSchema, ...
                    states,raw.Modes,observables,parameterStruct,struct( ...
                    'Evaluator','section-local-biped-v1', ...
                    'DirectSectionIntegration',true, ...
                    'StartSectionId',obj.Codec.StartSection.Id, ...
                    'StopSectionId',obj.Codec.StopSection.Id, ...
                    'EndpointRole','section_return', ...
                    'HiddenTimingSolve',false),struct( ...
                    'sourceRepository', ...
                    ['DLARlab/' ...
                    '2022_A_Template_Model_Explains_Jerboa_Gait_Transitions'], ...
                    'sourceCommit', ...
                    '4595146c5881a5313bc8fe92de85099193ef9be9'), ...
                    'EventRecords',records, ...
                    'GroundReactionForces',raw.GroundReactionForces);
                simulation=lmz.api.SimulationResult(interim.Time, ...
                    interim.StateSchema,interim.States,interim.Modes, ...
                    interim.Observables,interim.Parameters, ...
                    interim.Diagnostics,interim.Provenance, ...
                    'EventRecords',interim.EventRecords, ...
                    'GroundReactionForces',interim.GroundReactionForces, ...
                    'Kinematics',lmzmodels.slip_biped. ...
                    KinematicsProvider.compute(interim));
            end
            finite=all(isfinite([raw.Residual(:);terminal(:); ...
                sectionResidual(:)]));
            value=struct('TerminalState',terminal, ...
                'TerminalCoordinates',coordinates, ...
                'ContactResiduals',contactResiduals, ...
                'SectionResidual',sectionResidual(:), ...
                'EnergyResidual',energyResidual,'Crossing',crossing, ...
                'Simulation',simulation,'PhysicalValidity', ...
                finite&&all(raw.States(:,3)>0)&&crossing.Accepted, ...
                'Diagnostics',struct('ModelId','slip_biped', ...
                'Formulation',localFormulation(obj.Codec), ...
                'DirectSectionIntegration',true, ...
                'ApexOracleUsed',false, ...
                'SourceApexPhaseGaugePreserved',false, ...
                'StartSectionId',obj.Codec.StartSection.Id, ...
                'StopSectionId',obj.Codec.StopSection.Id, ...
                'StartStateSide',obj.Codec.StartSection.StateSide, ...
                'StopStateSide',obj.Codec.StopSection.StateSide, ...
                'ContactConstraintNames',{contactNames}, ...
                'Energy',energyDiagnostics, ...
                'EnergyValid',energyDiagnostics.Accepted, ...
                'LegacyEndpointVariableRole','return_time_only', ...
                'SourceSymmetryResidual',raw.Residual(13:14), ...
                'RawResidual',raw.Residual));
            value=obj.validateResult(value);
        end
    end
end

function raw=localWorldGauge(raw,origin)
raw.States(:,1)=raw.States(:,1)+origin;
for index=1:numel(raw.EventRecords)
    fields={'State','PreState','PostState'};
    for fieldIndex=1:numel(fields)
        name=fields{fieldIndex};
        if ~isempty(raw.EventRecords(index).(name))
            raw.EventRecords(index).(name)(1)= ...
                raw.EventRecords(index).(name)(1)+origin;
        end
    end
end
end

function raw=localPhysicalApexRecord(raw,hint)
target=find(strcmp({raw.EventRecords.Name},'APEX'),1,'last');
if isempty(target),return,end
raw.EventRecords(target).Name='SECTION_RETURN';
dy=raw.States(:,4);
indices=find((dy(1:end-1)>0&dy(2:end)<=0)| ...
    (dy(1:end-1)<0&dy(2:end)>=0));
if isempty(indices),return,end
if isempty(hint)||~isfinite(hint)
    index=indices(1);
else
    candidateTimes=raw.Time(indices);
    [~,selected]=min(abs(candidateTimes-hint));
    index=indices(selected);
end
denominator=dy(index)-dy(index+1);
if denominator==0,fraction=0.5;else,fraction=dy(index)/denominator;end
fraction=max(0,min(1,fraction));
state=raw.States(index,:)+fraction* ...
    (raw.States(index+1,:)-raw.States(index,:));
time=raw.Time(index)+fraction*(raw.Time(index+1)-raw.Time(index));
raw.EventRecords(target).Name='APEX';
raw.EventRecords(target).Time=time;
raw.EventRecords(target).State=state;
raw.EventRecords(target).PreState=state;
raw.EventRecords(target).PostState=state;
raw.EventRecords(target).ObservedDirectionalDerivative= ...
    (dy(index+1)-dy(index))/(raw.Time(index+1)-raw.Time(index));
% The immutable source APEX descriptor owns its historical direction.  The
% measured derivative remains explicit without changing that oracle label.
raw.EventRecords(target).DirectionalDerivative=NaN;
raw.EventRecords(target).Direction=[];
end

function value=localApexTime(codec,decoded)
value=NaN;source=codec.SourceDecision(:);
if numel(source)~=12,return,end
period=decoded.ReturnTime;
sourceTimes=mod(source(8:11),source(12));
localTimes=mod(decoded.EventTimes(:),period);
origin=mod(sourceTimes(1)-localTimes(1),period);
value=mod(period-origin,period);
if value<=256*eps(max(1,period)),value=period;end
end

function value=localDecoded(codec,request)
if ~isstruct(request)||~isscalar(request)
    error('lmz:Shooting:BipedSectionRequest', ...
        'Section request must be a scalar struct.');
end
value=[];
if isfield(request,'DecodedDecision')
    value=request.DecodedDecision;
    if isnumeric(value),value=codec.decode(value);end
end
required={'InitialState','EventTimes','ReturnTime'};
if ~isstruct(value)||~all(isfield(value,required))
    if ~isfield(request,'StartNode')|| ...
            ~isa(request.StartNode,'lmz.shooting.ShootingNode')|| ...
            ~isfield(request,'EventSchedule')|| ...
            ~isa(request.EventSchedule,'lmz.schedule.EventSchedule')
        error('lmz:Shooting:BipedDecodedDecision', ...
            ['Section request requires a local decision or a shooting ' ...
            'start node and EventSchedule.']);
    end
    schedule=request.EventSchedule;
    if ismethod(codec,'decodeSegment')
        value=codec.decodeSegment(request.StartNode.FullState(:),schedule);
        return
    end
    eventTimes=zeros(numel(codec.EventNames),1);
    for index=1:numel(codec.EventNames)
        if index==codec.EndpointEventIndex
            eventTimes(index)=schedule.ReturnTime;
        else
            eventTimes(index)=schedule.namedTimes(codec.EventNames{index});
        end
    end
    value=struct('InitialState',request.StartNode.FullState(:), ...
        'EventTimes',eventTimes,'ReturnTime',schedule.ReturnTime, ...
        'EventSchedule',schedule);
end
if ~all(isfield(value,required))
    error('lmz:Shooting:BipedDecodedDecision', ...
        'Decoded biped section decision is incomplete.');
end
end

function [values,names]=localContactResiduals(raw,codec)
if isa(codec,['lmzmodels.slip_biped.' ...
        'BipedSectionTransitionDecisionCodec'])
    names=reshape(codec.ActiveContactNames,[],1);
    indices=zeros(numel(names),1);
    for index=1:numel(names)
        indices(index)=find(strcmp(names{index},codec.EventNames),1);
    end
    values=raw(indices);
else
    names=reshape(codec.EventNames,[],1);values=raw(:);
end
end

function value=localFormulation(codec)
if isa(codec,['lmzmodels.slip_biped.' ...
        'BipedSectionTransitionDecisionCodec'])
    value='direct-mixed-section-transition-v1';
else
    value='direct-section-local-single-shooting-v1';
end
end

function value=localParameters(request)
if ~isfield(request,'PhysicalParameters')
    error('lmz:Shooting:BipedParameters', ...
        'Biped section request requires physical parameters.');
end
source=request.PhysicalParameters;
if isstruct(source)&&isscalar(source)&&isfield(source,'ProblemValues')
    source=source.ProblemValues;
end
if ~isnumeric(source)
    error('lmz:Shooting:BipedParameters', ...
        'Biped problem parameters must resolve to a numeric vector.');
end
value=source(:);
end

function [value,diagnostics]=localEnergyResidual(raw,request)
value=zeros(0,1);
diagnostics=struct('Mode','diagnostic_only','Available',false, ...
    'EnergyDelta',NaN,'DeclaredWork',0,'Residual',zeros(0,1), ...
    'Tolerance',0,'Accepted',true);
if ~isfield(request,'Segment')|| ...
        ~isa(request.Segment,'lmz.shooting.ShootingSegment')
    return
end
specification=request.Segment.EnergyWorkSpecification;
diagnostics.Mode=specification.Mode;
diagnostics.DeclaredWork=specification.DeclaredWork;
diagnostics.Tolerance=specification.Tolerance;
energy=raw.Energy;
if isempty(energy)||any(~isfinite(energy(:)))
    if strcmp(specification.Mode,'diagnostic_only'),return,end
    error('lmz:Shooting:ScientificEnergyResidualUnavailable', ...
        'The biped source did not return a finite total-energy channel.');
end
delta=energy(end)-energy(1);diagnostics.Available=true;
diagnostics.EnergyDelta=delta;
switch specification.Mode
    case 'energy_neutral'
        value=delta;
    case 'bounded_work'
        value=max(0,abs(delta)-abs(specification.DeclaredWork));
    case {'prescribed_work','diagnostic_only'}
        value=delta-specification.DeclaredWork;
    otherwise
        error('lmz:Shooting:ScientificEnergyMode', ...
            'Unsupported biped energy/work mode %s.',specification.Mode);
end
diagnostics.Residual=value;
diagnostics.Accepted=strcmp(specification.Mode,'diagnostic_only')|| ...
    all(abs(value)<=specification.Tolerance);
end

function state=localStartState(state,section)
primary=localPrimary(section);
if ~strcmp(section.StateSide,'pre')|| ...
        ~isa(primary,'lmz.poincare.NamedEventSection')
    return
end
switch primary.Descriptor.EventId
    case 'L_TD'
        state(6)=touchdownRate(state(2),state(3),state(4),state(5));
    case 'R_TD'
        state(8)=touchdownRate(state(2),state(3),state(4),state(7));
end
end

function value=touchdownRate(dx,y,dy,alpha)
tangent=tan(alpha);
value=-(dx+dy*tangent)/(y*(tangent^2+1));
end

function [terminal,crossing,records]=localTerminal(raw,section)
records=raw.EventRecords;
primary=localPrimary(section);
for index=1:numel(records)
    derivative=[];
    if strcmp(records(index).Name,'APEX')&& ...
            isfield(records,'DirectionalDerivative')&& ...
            isscalar(records(index).DirectionalDerivative)&& ...
            isfinite(records(index).DirectionalDerivative)
        derivative=records(index).DirectionalDerivative;
    end
    if isempty(derivative)
        derivative=localGuardDerivative( ...
            records(index).PreState(:),records(index).Name);
    end
    records(index).DirectionalDerivative=derivative;
    if isfinite(derivative)
        records(index).Direction=sign(derivative);
    else
        records(index).Direction=[];
    end
end
if isa(primary,'lmz.poincare.NamedEventSection')
    target=[];
    for index=1:numel(records)
        if strcmp(records(index).Name,primary.Descriptor.EventId)
            target=index;
        end
    end
    if isempty(target)
        error('lmz:Shooting:BipedStopEvent', ...
            'The requested stop event was not simulated.');
    end
    preState=localEndpointPreState(records(target),raw);
    postState=preState;
    if any(strcmp(primary.Descriptor.EventId,{'L_TD','R_TD'}))
        postState=localStartState(postState,localPreSection(section));
    end
    records(target).Time=raw.Time(end);
    records(target).State=postState(:).';
    records(target).PreState=preState(:).';
    records(target).PostState=postState(:).';
    records(target).DirectionalDerivative=localGuardDerivative( ...
        preState,primary.Descriptor.EventId);
    records(target).Direction=sign(records(target).DirectionalDerivative);
    candidateTimes=[records.Time].';
    candidateNames={records.Name}.';
    keep=(1:numel(records)).'~=target&candidateTimes>0& ...
        candidateTimes<raw.Time(end);
    [~,order]=sort(candidateTimes(keep));
    selected=candidateNames(keep);
    history=reshape(selected(order),1,[]);
    crossing=section.crossingFromRecord(records(target), ...
        'Occurrence',1,'EventHistory',history);
    terminal=crossing.State(:);
else
    terminal=raw.States(end,:).';
    dt=raw.Time(end)-raw.Time(end-1);
    flow=(raw.States(end,:)-raw.States(end-1,:)).'/dt;
    crossing=primary.crossingAt(raw.Time(end),terminal,flow, ...
        'ModeId','','Occurrence',1,'EventHistory',{records.Name});
end

function value=localPreSection(section)
% Return a minimal named-event proxy whose pre side requests the touchdown
% reset in localStartState.  Composite primaries retain their event ID.
descriptor=localPrimary(section).Descriptor.toStruct();
descriptor.stateSide='pre';
value=lmz.poincare.NamedEventSection( ...
    lmz.poincare.PoincareSectionDescriptor(descriptor));
end
end

function value=localEndpointPreState(record,raw)
value=raw.States(end,:).';
if isfield(record,'PreState')&&isnumeric(record.PreState)&& ...
        numel(record.PreState)==size(raw.States,2)&& ...
        all(isfinite(record.PreState(:)))&& ...
        abs(record.Time-raw.Time(end))<=1e-10*max(1,raw.Time(end))
    value=record.PreState(:);
end
end

function value=localSectionResidual(section,time,state,parameters,raw)
primary=localPrimary(section);
if isa(primary,'lmz.poincare.StateFunctionSection')
    value=primary.value(time,state,parameters,'');
else
    value=zeros(0,1);
end
if isempty(raw.Time),value=NaN;end
end

function value=localPrimary(section)
if isa(section,'lmz.poincare.CompositeSection')
    value=section.Primary;
else
    value=section;
end
end

function derivative=localGuardDerivative(state,eventId)
dy=state(4);
switch eventId
    case {'L_TD','L_LO'}
        alpha=state(5);dalpha=state(6);
    case {'R_TD','R_LO'}
        alpha=state(7);dalpha=state(8);
    otherwise
        derivative=NaN;
        return
end
derivative=dy+sin(alpha)*dalpha;
end
