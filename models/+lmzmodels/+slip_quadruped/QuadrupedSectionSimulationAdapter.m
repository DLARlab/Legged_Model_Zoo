classdef QuadrupedSectionSimulationAdapter < ...
        lmz.shooting.SectionSimulationAdapter
    %QUADRUPEDSECTIONSIMULATIONADAPTER Direct target-section RoadMap return.
    %   The preserved apex evaluator remains untouched. This adapter reuses
    %   its source equations with a section-local initial state and a rotated
    %   cyclic schedule; the legacy terminal variable is treated only as a
    %   return time and its apex residual is not used.
    properties (SetAccess=private)
        Codec
    end

    methods
        function obj=QuadrupedSectionSimulationAdapter(codec)
            valid=isa(codec, ...
                'lmzmodels.slip_quadruped.QuadrupedSectionDecisionCodec')|| ...
                isa(codec,['lmzmodels.slip_quadruped.' ...
                'QuadrupedSectionTransitionDecisionCodec']);
            if ~valid
                error('lmz:Shooting:QuadrupedCodec', ...
                    'Quadruped section adapter requires its model codec.');
            end
            obj.Codec=codec;
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
            decoded=localDecoded(obj.Codec,request);
            [decoded,endpointRegularization]=localEndpointTimeChart( ...
                obj.Codec,decoded);
            parameters=localParameters(request);
            localValidateEnergyMode(request);
            parameterSchema=lmzmodels.slip_quadruped.ParameterSchema.create();
            parameterSchema.validateVector(parameters);
            initial=decoded.InitialState(:);
            propagationInitial=localStartState(initial,obj.Codec.StartSection, ...
                parameters);
            legacyDecision=[propagationInitial(2:end); ...
                decoded.EventTimes(:);decoded.ReturnTime];
            raw=lmzmodels.slip_quadruped.LegacyQuadrupedEvaluator(). ...
                evaluate(legacyDecision,parameters,context);
            raw=localWorldGauge(raw,initial(1));
            raw=localPhysicalApexRecord(raw, ...
                localApexTime(obj.Codec,decoded));
            [terminal,crossing,records]=localTerminal(raw, ...
                obj.Codec.StopSection,parameters);
            coordinates=obj.Codec.StopSection.coordinates(terminal, ...
                obj.Codec.StateCoordinates.PhysicalSchema);
            sectionResidual=localSectionResidual( ...
                obj.Codec.StopSection,decoded.ReturnTime,terminal,parameters,raw);
            [contactResiduals,contactNames]=localContactResiduals( ...
                raw.Residual(1:8),obj.Codec);
            simulation=[];
            if includeSimulation
                states=raw.States;
                states(1,:)=propagationInitial(:).';
                states(end,:)=terminal(:).';
                observables=lmzmodels.slip_quadruped.ObservableProvider.compute( ...
                    raw.Time,states,legacyDecision,raw.GroundReactionForces);
                interim=lmz.api.SimulationResult(raw.Time, ...
                    obj.Codec.StateCoordinates.PhysicalSchema,states,raw.Modes, ...
                    observables,lmzmodels.slip_quadruped.ParameterSchema. ...
                    create().unpack(parameters),struct( ...
                    'Evaluator','section-local-quadruped-v1', ...
                    'DirectSectionIntegration',true, ...
                    'StartSectionId',obj.Codec.StartSection.Id, ...
                    'StopSectionId',obj.Codec.StopSection.Id, ...
                    'EndpointRole','section_return','HiddenTimingSolve',false), ...
                    struct('sourceRepository','DLARlab/SLIP_Model_Zoo', ...
                    'sourceCommit','2c106101383ecee1b2a9d695efe09fbd72d5718a'), ...
                    'EventRecords',records, ...
                    'GroundReactionForces',raw.GroundReactionForces);
                simulation=lmz.api.SimulationResult(interim.Time, ...
                    interim.StateSchema,interim.States,interim.Modes, ...
                    interim.Observables,interim.Parameters, ...
                    interim.Diagnostics,interim.Provenance, ...
                    'EventRecords',interim.EventRecords, ...
                    'GroundReactionForces',interim.GroundReactionForces, ...
                    'Kinematics',lmzmodels.slip_quadruped. ...
                    KinematicsProvider.compute(interim));
            end
            finite=all(isfinite([raw.Residual(:);terminal(:); ...
                sectionResidual(:)]));
            value=struct('TerminalState',terminal, ...
                'TerminalCoordinates',coordinates, ...
                'ContactResiduals',contactResiduals, ...
                'SectionResidual',sectionResidual(:), ...
                'EnergyResidual',zeros(0,1),'Crossing',crossing, ...
                'Simulation',simulation,'PhysicalValidity', ...
                finite&&all(raw.States(:,3)>0)&&crossing.Accepted, ...
                'Diagnostics',struct('ModelId','slip_quadruped', ...
                'Formulation',localFormulation(obj.Codec), ...
                'DirectSectionIntegration',true, ...
                'ApexOracleUsed',false,'SourceApexPhaseGaugePreserved',false, ...
                'StartSectionId',obj.Codec.StartSection.Id, ...
                'StopSectionId',obj.Codec.StopSection.Id, ...
                'StartStateSide',obj.Codec.StartSection.StateSide, ...
                'StopStateSide',obj.Codec.StopSection.StateSide, ...
                'ContactConstraintNames',{contactNames}, ...
                'EndpointTimeRegularization',endpointRegularization, ...
                'LegacyEndpointVariableRole','return_time_only', ...
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
if numel(source)~=22,return,end
period=decoded.ReturnTime;
sourceTimes=mod(source(14:21),source(22));
localTimes=mod(decoded.EventTimes(:),period);
origin=mod(sourceTimes(1)-localTimes(1),period);
value=mod(period-origin,period);
if value<=256*eps(max(1,period)),value=period;end
end

function value=localDecoded(codec,request)
if ~isstruct(request)||~isscalar(request)
    error('lmz:Shooting:QuadrupedSectionRequest', ...
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
        error('lmz:Shooting:QuadrupedDecodedDecision', ...
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
    error('lmz:Shooting:QuadrupedDecodedDecision', ...
        'Decoded quadruped section decision is incomplete.');
end
end

function [value,maximumShift]=localEndpointTimeChart(codec,value)
maximumShift=0;
if ~isa(codec,['lmzmodels.slip_quadruped.' ...
        'QuadrupedSectionTransitionDecisionCodec'])
    return
end
indices=find(strcmp(codec.BoundaryRoles,'return'));
if isempty(indices),return,end
period=value.ReturnTime;
separation=512*eps(max(1,period));
for offset=1:numel(indices)
    index=indices(offset);
    replacement=period-(numel(indices)-offset+1)*separation;
    maximumShift=max(maximumShift,abs(value.EventTimes(index)-replacement));
    value.EventTimes(index)=replacement;
end
end

function [values,names]=localContactResiduals(raw,codec)
if isa(codec,['lmzmodels.slip_quadruped.' ...
        'QuadrupedSectionTransitionDecisionCodec'])
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
if isa(codec,['lmzmodels.slip_quadruped.' ...
        'QuadrupedSectionTransitionDecisionCodec'])
    value='direct-mixed-section-transition-v1';
else
    value='direct-section-local-single-shooting-v1';
end
end

function value=localParameters(request)
if ~isfield(request,'PhysicalParameters')
    error('lmz:Shooting:QuadrupedParameters', ...
        'Quadruped section request requires physical parameters.');
end
source=request.PhysicalParameters;
if isstruct(source)&&isscalar(source)&&isfield(source,'ProblemValues')
    source=source.ProblemValues;
end
if ~isnumeric(source)
    error('lmz:Shooting:QuadrupedParameters', ...
        'Quadruped problem parameters must resolve to a numeric vector.');
end
value=source(:);
end

function localValidateEnergyMode(request)
if ~isfield(request,'Segment')|| ...
        ~isa(request.Segment,'lmz.shooting.ShootingSegment')
    return
end
mode=request.Segment.EnergyWorkSpecification.Mode;
if ~strcmp(mode,'diagnostic_only')
    error('lmz:Shooting:ScientificEnergyResidualUnavailable', ...
        ['The quadruped source does not expose a total-energy channel; ' ...
        '%s cannot be enforced by this section adapter.'],mode);
end
end

function state=localStartState(state,section,parameters)
primary=localPrimary(section);
if ~strcmp(section.StateSide,'pre')|| ...
        ~isa(primary,'lmz.poincare.NamedEventSection')|| ...
        isempty(regexp(primary.Descriptor.EventId,'_TD$','once'))
    return
end
state=localReset(state,primary.Descriptor.EventId,parameters);
end

function [terminal,crossing,records]=localTerminal(raw,section,parameters)
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
        derivative=localGuardDerivative(records(index).PreState(:), ...
            records(index).Name,parameters);
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
        error('lmz:Shooting:QuadrupedStopEvent', ...
            'The requested stop event was not simulated.');
    end
    preState=localEndpointPreState(records(target),raw);
    postState=preState;
    if ~isempty(regexp(primary.Descriptor.EventId,'_TD$','once'))
        postState=localReset(postState,primary.Descriptor.EventId,parameters);
    end
    records(target).Time=raw.Time(end);
    records(target).State=postState(:).';
    records(target).PreState=preState(:).';
    records(target).PostState=postState(:).';
    records(target).DirectionalDerivative=localGuardDerivative( ...
        preState,primary.Descriptor.EventId,parameters);
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
if isa(section,'lmz.poincare.CompositeSection')&& ...
        isa(primary,'lmz.poincare.StateFunctionSection')
    % A state-plane composite shares the scalar primary equation; its
    % additional conditions are enforced by crossing acceptance.
    value=primary.value(time,state,parameters,'');
end
if isempty(raw.Time),value=NaN;end
end

function value=localPrimary(section)
if isa(section,'lmz.poincare.CompositeSection'),value=section.Primary; ...
else,value=section;end
end

function derivative=localGuardDerivative(state,eventId,parameters)
l=parameters(4);lb=parameters(6);
dy=state(4);phi=state(5);dphi=state(6);
switch eventId
    case {'BL_TD','BL_LO'}
        alpha=state(7);dalpha=state(8);
        derivative=dy-lb*cos(phi)*dphi+ ...
            l*sin(phi+alpha)*(dphi+dalpha);
    case {'FL_TD','FL_LO'}
        alpha=state(9);dalpha=state(10);
        derivative=dy+(1-lb)*cos(phi)*dphi+ ...
            l*sin(phi+alpha)*(dphi+dalpha);
    case {'BR_TD','BR_LO'}
        alpha=state(11);dalpha=state(12);
        derivative=dy-lb*cos(phi)*dphi+ ...
            l*sin(phi+alpha)*(dphi+dalpha);
    case {'FR_TD','FR_LO'}
        alpha=state(13);dalpha=state(14);
        derivative=dy+(1-lb)*cos(phi)*dphi+ ...
            l*sin(phi+alpha)*(dphi+dalpha);
    otherwise
        derivative=NaN;
end
end

function state=localReset(state,eventId,parameters)
lb=parameters(6);phi=state(5);dphi=state(6);y=state(3);dy=state(4);dx=state(2);
switch eventId
    case 'BL_TD'
        state(8)=backRate(dx,y,dy,phi,dphi,state(7),lb);
    case 'FL_TD'
        state(10)=frontRate(dx,y,dy,phi,dphi,state(9),lb);
    case 'BR_TD'
        state(12)=backRate(dx,y,dy,phi,dphi,state(11),lb);
    case 'FR_TD'
        state(14)=frontRate(dx,y,dy,phi,dphi,state(13),lb);
end
end

function value=backRate(dx,y,dy,phi,dphi,alpha,lb)
t4=alpha+phi;t16=2*t4;
value=-(dx+2*dphi*y+dx*cos(t16)+dy*sin(t16)- ...
    dphi*lb*sin(phi)-dphi*lb*sin(alpha+t4))/(2*y-2*lb*sin(phi));
end

function value=frontRate(dx,y,dy,phi,dphi,alpha,lb)
t2=cos(phi);t3=sin(phi);t4=alpha+phi;t6=lb-1;t5=tan(t4);
t8=t3*t6;t9=t5^2+1;t10=-t8;t12=t2*t5*t6;t13=1/t9;
value=(t13*(dx+dy*t5-dphi*(t10+t12+t9*(t8-y))))/(t8-y);
end
