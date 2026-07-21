classdef ContactConstraintProvider < lmz.schedule.ContactConstraintProvider
    %CONTACTCONSTRAINTPROVIDER Analytic hopper ground/return timing rows.
    properties (SetAccess=private)
        Impulse
        StartSection
        StopSection
    end
    methods
        function obj=ContactConstraintProvider(impulse,startSection,stopSection)
            obj.Impulse=impulse;
            if nargin<2,startSection=[];end
            if nargin<3,stopSection=[];end
            obj.StartSection=startSection;
            obj.StopSection=stopSection;
        end
        function value=eventNames(~),value={'impact'};end
        function value=evaluate(obj,initialState,physicalParameters, ...
                schedule,context,includeSimulation)
            if nargin<6,includeSimulation=true;end
            state=initialState(:);parameters=physicalParameters(:);
            if numel(state)~=4||numel(parameters)~=1
                error('lmz:Timing:HopperFixedData', ...
                    'Hopper timing requires four states and gravity.');
            end
            lmzmodels.tutorial_hopper.ParameterSchema.create().validateVector(parameters);
            decision=struct('initial_x',state(1), ...
                'horizontal_speed',state(2),'apex_height',state(3), ...
                'initial_vertical_speed',state(4), ...
                'impact_time',schedule.namedTimes({'impact'}), ...
                'stride_period',schedule.ReturnTime,'impulse',obj.Impulse);
            request=struct('TimeSpan',[0 schedule.ReturnTime], ...
                'Parameters',struct('gravity',parameters(1),'impulse',obj.Impulse), ...
                'Decision',decision,'ProblemId','section_return_timing');
            simulation=lmz.simulation.HybridSimulator().simulate( ...
                lmzmodels.tutorial_hopper.HopperSystem(),request,context, ...
                struct('MaximumStep',schedule.ReturnTime/100));
            impact=simulation.EventRecords(1);
            terminal=simulation.States(end,:).';
            [sectionId,sectionResidual,derivative,modeId,stateSide]= ...
                obj.sectionData(terminal,parameters(1),schedule.StopSectionId);
            direction=localDirection(derivative);grazing=abs(derivative)<=1e-9;
            accepted=abs(sectionResidual)<=1e-7&&~grazing&& ...
                (isempty(obj.StopSection)||obj.StopSection.CrossingDirection==0|| ...
                direction==obj.StopSection.CrossingDirection);
            crossing=struct('SectionId',sectionId, ...
                'SectionValue',sectionResidual, ...
                'DirectionalDerivative',derivative, ...
                'CrossingDirection',direction,'Grazing',grazing,'EventId','', ...
                'ModeBefore',modeId,'ModeAfter',modeId, ...
                'Time',schedule.ReturnTime,'PreState',terminal, ...
                'PostState',terminal,'State',terminal,'StateSide',stateSide, ...
                'Occurrence',1,'Accepted',accepted, ...
                'RejectionReason',localReason(accepted,grazing,direction, ...
                obj.StopSection));
            if ~includeSimulation,returned=[];else,returned=simulation;end
            value=struct('ContactResidual',impact.PreState(3), ...
                'SectionResidual',sectionResidual, ...
                'TerminalState',terminal,'SectionCrossing',crossing, ...
                'Simulation',returned,'Diagnostics',struct( ...
                'ModelId','tutorial_hopper','ResidualNames', ...
                {{'impact_height',[sectionId '_section_value']}}, ...
                'PeriodicityRowsIncluded',false,'Impulse',obj.Impulse, ...
                'StartSectionId',schedule.StartSectionId, ...
                'StopSectionId',schedule.StopSectionId));
        end

        function [id,residual,derivative,modeId,stateSide]= ...
                sectionData(obj,state,gravity,fallbackId)
            if isempty(obj.StopSection)
                id=fallbackId;residual=state(4);derivative=-gravity;
                modeId='flight_up';stateSide='post';return
            end
            descriptor=obj.StopSection.Descriptor;
            id=obj.StopSection.Id;stateSide=obj.StopSection.StateSide;
            index=obj.StopSection.StateSchema.indexOf(descriptor.StateName);
            residual=state(index)-descriptor.Threshold;
            flow=[state(2);0;state(4);-gravity];
            gradient=obj.StopSection.gradient(0,state,gravity,localFlightMode(state));
            derivative=gradient(:).'*flow;
            modeId=localFlightMode(state);
        end
    end
    methods (Static)
        function problem=createProblem(model,configuration)
            if nargin<2,configuration=struct();end
            decisionSchema=lmzmodels.tutorial_hopper.PeriodicHopProblem( ...
                model,struct()).getDecisionSchema();
            decision=decisionSchema.defaults();
            parameters=lmzmodels.tutorial_hopper.ParameterSchema.create().defaults();
            initial=[0;decision(4);decision(1);0];
            if isfield(configuration,'InitialState'),initial=configuration.InitialState(:);end
            if isfield(configuration,'PhysicalParameters'),parameters=configuration.PhysicalParameters(:);end
            impulse=decision(3);
            if isfield(configuration,'ControlParameters')
                control=configuration.ControlParameters;
                if isstruct(control)&&isfield(control,'impulse'),impulse=control.impulse; ...
                elseif isnumeric(control)&&isscalar(control),impulse=control;end
            end
            sections=lmz.registry.ModelRegistry.discover(). ...
                getPoincareSectionRegistry('tutorial_hopper');
            startId=fieldOr(configuration,'StartSectionId','apex');
            stopId=fieldOr(configuration,'StopSectionId','apex');
            start=sections.section(startId);stop=sections.section(stopId);
            if ~isa(start,'lmz.poincare.StateFunctionSection')|| ...
                    ~isa(stop,'lmz.poincare.StateFunctionSection')
                error('lmz:Timing:UnsupportedSection', ...
                    ['tutorial_hopper timing supports its trusted ' ...
                    'state-plane sections; named-event endpoints are not ' ...
                    'independent return-time equations.']);
            end
            if strcmp(startId,'apex')&&strcmp(stopId,'height_descending')
                error('lmz:Timing:UnsupportedSectionOccurrence', ...
                    ['The first descending-height crossing from apex occurs ' ...
                    'before impact. Start at height_descending, or select ' ...
                    'an explicit later-occurrence stride definition.']);
            end
            [initial,impactTime,returnTime]=localTimingSeed( ...
                start,stop,initial,parameters(1),impulse,configuration);
            provider=lmzmodels.tutorial_hopper.ContactConstraintProvider( ...
                impulse,start,stop);
            schedule=lmz.schedule.ContactConstraintProvider.scheduleFromConfiguration( ...
                provider.eventNames(),impactTime,returnTime,configuration);
            if ~strcmp(schedule.StartSectionId,startId)|| ...
                    ~strcmp(schedule.StopSectionId,stopId)
                error('lmz:Timing:ScheduleSectionMismatch', ...
                    'EventSchedule section IDs must match the timing problem.');
            end
            problem=lmz.schedule.SectionReturnTimingProblem(model, ...
                'section_return_timing',provider,initial,parameters,schedule,configuration);
        end
    end
end

function [initial,impactTime,returnTime]=localTimingSeed( ...
        start,stop,apexInitial,gravity,impulse,configuration)
initial=apexInitial;
period=sqrt(8/gravity);
if ~strcmp(start.Id,'apex')&&~isfield(configuration,'InitialState')
    threshold=start.Descriptor.Threshold;
    apexHeight=apexInitial(3);
    fallTime=sqrt(2*(apexHeight-threshold)/gravity);
    initial=[apexInitial(1)+apexInitial(2)*fallTime; ...
        apexInitial(2);threshold;-gravity*fallTime];
end
startValue=initial(start.StateIndex)-start.Descriptor.Threshold;
if abs(startValue)>1e-10
    error('lmz:Timing:InitialStateOffSection', ...
        'Fixed initial state must lie on the selected start section.');
end
startDerivative=localSectionDerivative(start,initial,gravity);
if start.CrossingDirection~=0&& ...
        localDirection(startDerivative)~=start.CrossingDirection
    error('lmz:Timing:InitialStateDirection', ...
        'Fixed initial state has the wrong start-section direction.');
end
impactTime=(initial(4)+sqrt(initial(4)^2+2*gravity*initial(3)))/gravity;
postVelocity=initial(4)-gravity*impactTime+impulse;
if strcmp(stop.Descriptor.StateName,'vy')
    afterImpact=postVelocity/gravity;
else
    target=stop.Descriptor.Threshold;
    discriminant=postVelocity^2-2*gravity*target;
    if discriminant<=0
        error('lmz:Timing:UnreachableSection', ...
            'The selected stop height is unreachable after impact.');
    end
    afterImpact=(postVelocity+sqrt(discriminant))/gravity;
end
returnTime=impactTime+afterImpact;
if strcmp(start.Id,'apex')&&strcmp(stop.Id,'apex')
    impactTime=period/2;returnTime=period;
end
end

function value=localSectionDerivative(section,state,gravity)
flow=[state(2);0;state(4);-gravity];
gradient=section.gradient(0,state,gravity,localFlightMode(state));
value=gradient(:).'*flow;
end

function value=localFlightMode(state)
if state(4)<0,value='flight_down';else,value='flight_up';end
end

function value=localDirection(derivative)
tolerance=1e-9;
if derivative>tolerance,value=1; ...
elseif derivative<-tolerance,value=-1;else,value=0;end
end

function value=localReason(accepted,grazing,direction,section)
if accepted,value='';return,end
if grazing,value='grazing';return,end
if ~isempty(section)&&section.CrossingDirection~=0&& ...
        direction~=section.CrossingDirection
    value='crossing-direction';
else
    value='section-value';
end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
