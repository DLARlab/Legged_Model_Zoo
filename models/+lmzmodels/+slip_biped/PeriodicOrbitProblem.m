classdef PeriodicOrbitProblem < lmz.api.NonlinearEquationProblem
    %PERIODICORBITPROBLEM Section-local configurable jerboa orbit problem.
    %   The exact apex preset delegates unchanged to PeriodicApexProblem.
    %   Non-apex periodic sections own their state and schedule decisions
    %   and are propagated directly in the selected target-section chart.
    properties (SetAccess=private)
        ApexProblem
        ReturnEvaluator
        SectionCodec
        SectionAdapter
        SectionCatalog
        StartSection
        StopSection
        Symmetry
        ApexEquivalent = true
    end

    methods
        function obj=PeriodicOrbitProblem(model,configuration)
            if nargin<2,configuration=struct();end
            if ~isstruct(configuration)||~isscalar(configuration)
                error('lmz:Poincare:ScientificConfiguration', ...
                    'Periodic-orbit configuration must be a scalar struct.');
            end
            apex=lmzmodels.slip_biped.PeriodicApexProblem(model,struct());
            [catalog,startSection,stopSection,symmetry,equivalent]= ...
                localConfiguration(model,configuration);
            codec=[];adapter=[];
            decisionSchema=apex.getDecisionSchema();
            defaults=apex.getParameterSchema().defaults();
            if ~equivalent
                localValidateDirectPeriodic(startSection,stopSection, ...
                    configuration);
                [codec,configuration,defaults]=localCodec( ...
                    apex,catalog,startSection,stopSection, ...
                    configuration,defaults);
                fixedConfiguration=localField(configuration, ...
                    'FixedConfiguration',apex.FixedConfiguration);
                adapter=lmzmodels.slip_biped. ...
                    BipedSectionSimulationAdapter(codec, ...
                    'FixedConfiguration',fixedConfiguration);
                configuration.FixedConfiguration=fixedConfiguration;
                decisionSchema=codec.decisionSchema();
            end
            obj@lmz.api.NonlinearEquationProblem(model, ...
                'periodic_orbit','nonlinear_equation',decisionSchema, ...
                apex.getParameterSchema(),defaults,configuration);
            obj.Version='2.0.0';
            obj.ApexProblem=apex;
            obj.ReturnEvaluator=lmz.poincare. ...
                ScientificPeriodicOrbitEvaluator();
            obj.SectionCodec=codec;
            obj.SectionAdapter=adapter;
            obj.SectionCatalog=catalog;
            obj.StartSection=startSection;
            obj.StopSection=stopSection;
            obj.Symmetry=symmetry;
            obj.ApexEquivalent=equivalent;
        end

        function evaluation=evaluate(obj,u,p,context,includeSimulation)
            if nargin<5,includeSimulation=false;end
            if nargin<4||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            context.check();
            obj.ParameterSchema.validateVector(p);
            if obj.ApexEquivalent
                returned=obj.ReturnEvaluator.evaluate(obj.Model, ...
                    obj.ApexProblem,u,p,obj.Configuration,7,context, ...
                    includeSimulation);
                base=returned.BaseEvaluation;
                diagnostics=base.Diagnostics;
                diagnostics.PeriodicOrbit=returned.Diagnostics;
                evaluation=lmz.data.ProblemEvaluation( ...
                    base.ResidualBlocks,'Simulation',base.Simulation, ...
                    'Feasibility',base.Feasibility, ...
                    'PhysicalValidity',base.PhysicalValidity, ...
                    'Warnings',base.Warnings,'Diagnostics',diagnostics);
                return
            end

            [sectionDecision,migrated]=localizeDecision(obj,u,p,context);
            decoded=obj.SectionCodec.decode(sectionDecision);
            propagated=obj.SectionAdapter.evaluate(sectionDecision,p, ...
                context,includeSimulation);
            schema=obj.Model.getPhysicalStateSchema();
            aligned=obj.Symmetry.align(propagated.TerminalState, ...
                decoded.InitialState,schema);
            initialCoordinates=obj.StartSection.coordinates( ...
                decoded.InitialState,schema);
            terminalCoordinates=obj.StopSection.coordinates(aligned,schema);
            periodic=terminalCoordinates-initialCoordinates;

            blocks=lmz.data.ResidualBlock.empty(0,1);
            blocks(end+1,1)=lmz.data.ResidualBlock( ...
                'section_periodicity',periodic,ones(numel(periodic),1));
            if ~isempty(propagated.SectionResidual)
                blocks(end+1,1)=lmz.data.ResidualBlock( ...
                    'return_section',propagated.SectionResidual, ...
                    ones(numel(propagated.SectionResidual),1));
            end
            blocks(end+1,1)=lmz.data.ResidualBlock( ...
                'contact_geometry',propagated.ContactResiduals, ...
                ones(numel(propagated.ContactResiduals),1));

            gaps=diff([0;decoded.EventSchedule.times(); ...
                decoded.ReturnTime]);
            finite=all(isfinite([sectionDecision(:);p(:);periodic(:); ...
                propagated.ContactResiduals(:); ...
                propagated.SectionResidual(:)]));
            valid=finite&&propagated.PhysicalValidity&&all(gaps>0);
            feasibility=struct('Valid',valid, ...
                'Messages',{localMessages(valid,propagated.Crossing)}, ...
                'MinimumEventGap',min(gaps), ...
                'MinimumBodyHeight',localMinimumHeight( ...
                    propagated.Simulation), ...
                'SectionResidualNorm',norm(periodic), ...
                'AcceptedReturnCrossing',propagated.Crossing.Accepted);
            displacement=obj.Symmetry.displacement( ...
                propagated.TerminalState,decoded.InitialState,schema);
            diagnostics=propagated.Diagnostics;
            diagnostics.Formulation= ...
                'section-local-scientific-periodic-orbit-v2';
            diagnostics.LegacyEquivalent=false;
            diagnostics.ApexPresetEquivalent=false;
            diagnostics.DirectSectionIntegration=true;
            diagnostics.SourceApexPhaseGaugePreserved=false;
            diagnostics.HiddenTimingSolve=false;
            diagnostics.RephasedSimulation= ...
                norm(periodic)<=1e-6&&propagated.Crossing.Accepted;
            diagnostics.PostProcessedTrajectoryRephase=false;
            diagnostics.LegacyApexDecisionMigrated=migrated;
            diagnostics.LocalDecisionValues=sectionDecision;
            diagnostics.StartSectionId=obj.StartSection.Id;
            diagnostics.StopSectionId=obj.StopSection.Id;
            diagnostics.StartStateSide=obj.StartSection.StateSide;
            diagnostics.StopStateSide=obj.StopSection.StateSide;
            diagnostics.SymmetryId=obj.Symmetry.Id;
            diagnostics.SymmetryDisplacement=displacement;
            diagnostics.SectionCatalogHash=obj.SectionCatalog.CatalogHash;
            diagnostics.StartSectionHash= ...
                obj.StartSection.Descriptor.fingerprint();
            diagnostics.StopSectionHash= ...
                obj.StopSection.Descriptor.fingerprint();
            diagnostics.StartCrossing=localInitialCrossing( ...
                obj.StartSection,decoded.InitialState).toStruct();
            diagnostics.StopCrossing=propagated.Crossing.toStruct();
            diagnostics.InitialSectionCoordinates=initialCoordinates;
            diagnostics.ReturnSectionCoordinates=terminalCoordinates;
            evaluation=lmz.data.ProblemEvaluation(blocks, ...
                'Simulation',propagated.Simulation, ...
                'Feasibility',feasibility,'PhysicalValidity',valid, ...
                'Diagnostics',diagnostics);
        end

        function names=listObservables(obj)
            names=obj.ApexProblem.listObservables();
        end

        function solution=makeSolution(obj,u,p,evaluation)
            if nargin<3||isempty(p),p=obj.DefaultParameters;end
            if nargin<4,evaluation=[];end
            if ~obj.ApexEquivalent
                if ~isempty(evaluation)&&isfield(evaluation.Diagnostics, ...
                        'LocalDecisionValues')
                    u=evaluation.Diagnostics.LocalDecisionValues;
                elseif numel(u)~=obj.DecisionSchema.count()
                    [u,~]=localizeDecision(obj,u,p, ...
                        lmz.api.RunContext.synchronous(0));
                end
            end
            source=makeSolution@lmz.api.BaseProblem(obj,u,p,evaluation);
            data=source.toStruct();
            data.DecisionSchema=source.DecisionSchema;
            data.ParameterSchema=source.ParameterSchema;
            data.ResidualBlocks=source.ResidualBlocks;
            if obj.ApexEquivalent
                classification= ...
                    lmzmodels.slip_biped.GaitClassifier.classify(u);
            else
                classification=lmzmodels.slip_biped.GaitClassifier. ...
                    classify(localLegacyDecision(obj.SectionCodec,u));
            end
            data.Classification=classification;
            if ~isempty(evaluation)&&~isempty(evaluation.Simulation)
                data.Observables=evaluation.Simulation.Observables;
            end
            data.Lineage=localLineage(obj.Configuration,evaluation);
            data.Provenance=struct('source', ...
                'scientific-biped-configurable-section', ...
                'sourceCommit', ...
                '4595146c5881a5313bc8fe92de85099193ef9be9');
            solution=lmz.data.Solution(data);
        end
    end
end

function [catalog,startSection,stopSection,symmetry,equivalent]= ...
        localConfiguration(model,configuration)
registry=lmz.registry.ModelRegistry.discover();
catalog=registry.getPoincareSectionRegistry('slip_biped');
startId=localField(configuration,'StartSectionId','apex');
stopId=localField(configuration,'StopSectionId',startId);
startSection=localConfiguredSection( ...
    catalog.section(startId),configuration,'Start', ...
    model.getPhysicalStateSchema());
stopSection=localConfiguredSection( ...
    catalog.section(stopId),configuration,'Stop', ...
    model.getPhysicalStateSchema());
symmetry=catalog.symmetryFor(stopId);
requested=localField(configuration,'SymmetryId',symmetry.Id);
if strcmp(requested,'identity')
    symmetry=lmz.poincare.IdentitySymmetry();
elseif ~strcmp(requested,symmetry.Id)
    error('lmz:Poincare:ScientificSymmetry', ...
        'SymmetryId must be identity or the section catalog symmetry.');
end
equivalent=localApexEquivalent( ...
    startSection,stopSection,symmetry,configuration);
end

function section=localConfiguredSection(section,configuration,prefix,schema)
value=section.toStruct();
fields={'StateSide','CrossingDirection','MinimumReturnTime', ...
    'RequiredEventSequence','ReturnOccurrence'};
targets={'stateSide','crossingDirection','minimumReturnTime', ...
    'requiredEventSequence','returnOccurrence'};
for index=1:numel(fields)
    name=[prefix fields{index}];
    if isfield(configuration,name)
        value.(targets{index})=configuration.(name);
    elseif strcmp(prefix,'Stop')&&isfield(configuration,fields{index})
        value.(targets{index})=configuration.(fields{index});
    end
end
descriptor=lmz.poincare.PoincareSectionDescriptor(value);
if strcmp(descriptor.Kind,'named_event')
    section=lmz.poincare.NamedEventSection(descriptor);
elseif strcmp(descriptor.Kind,'state_plane')
    section=lmz.poincare.StateFunctionSection(descriptor,schema);
elseif isa(section,'lmz.poincare.CompositeSection')
    section=lmz.poincare.CompositeSection( ...
        descriptor,section.Primary,section.Conditions);
else
    error('lmz:Poincare:ScientificSectionKind', ...
        'The selected section kind has no direct scientific adapter.');
end
end

function valid=localApexEquivalent(startSection,stopSection,symmetry,configuration)
valid=strcmp(startSection.Id,'apex')&&strcmp(stopSection.Id,'apex')&& ...
    strcmp(startSection.StateSide,'post')&& ...
    strcmp(stopSection.StateSide,'post')&& ...
    strcmp(symmetry.Id,'planar_translation');
fields={'StartCrossingDirection','StopCrossingDirection', ...
    'CrossingDirection','StartMinimumReturnTime','StopMinimumReturnTime', ...
    'MinimumReturnTime','StartRequiredEventSequence', ...
    'StopRequiredEventSequence','RequiredEventSequence', ...
    'StartReturnOccurrence','StopReturnOccurrence','ReturnOccurrence'};
valid=valid&&~any(isfield(configuration,fields));
end

function localValidateDirectPeriodic(startSection,stopSection,configuration)
strideCount=localField(configuration,'StrideCount',1);
if ~isnumeric(strideCount)||~isscalar(strideCount)||strideCount~=1
    error('lmz:Poincare:ScientificStrideCount', ...
        ['Scientific periodic_orbit uses one return. Use an N-stride ' ...
        'problem for StrideCount other than one.']);
end
if strcmp(startSection.Id,'apex')||strcmp(stopSection.Id,'apex')
    error('lmz:Shooting:ApexPresetConfiguration', ...
        ['Custom apex sides/directions require an explicit transition ' ...
        'problem; the source-equivalent apex preset is immutable.']);
end
if ~strcmp(startSection.Id,stopSection.Id)
    error('lmz:Shooting:TransitionProblemRequired', ...
        ['Periodic closure requires the same start and stop section. ' ...
        'Use TransitionMultipleShootingProblem for mixed endpoints.']);
end
if ~isequal(startSection.Descriptor.CoordinateNames, ...
        stopSection.Descriptor.CoordinateNames)
    error('lmz:Poincare:ScientificCoordinateDimension', ...
        'Periodic start/stop section coordinate schemas must agree.');
end
end

function [codec,configuration,parameters]=localCodec( ...
        apex,catalog,startSection,stopSection,configuration,parameters)
sourceDecision=localField(configuration,'SourceDecisionValues', ...
    apex.getDecisionSchema().defaults());
sourceParameters=localField(configuration,'SourceParameterValues',parameters);
apex.getDecisionSchema().validateVector(sourceDecision);
apex.getParameterSchema().validateVector(sourceParameters);
parameters=sourceParameters(:);
names={'L_TD','L_LO','R_TD','R_LO'};
if all(isfield(configuration,{'InitialSectionState', ...
        'InitialEventTimes','InitialReturnTime'}))
    state=configuration.InitialSectionState(:);
    eventTimes=localConfiguredEventTimes(configuration,names);
    returnTime=configuration.InitialReturnTime;
else
    context=lmz.api.RunContext.synchronous(0);
    evaluation=apex.evaluate(sourceDecision,sourceParameters,context,true);
    symmetry=catalog.symmetryFor(startSection.Id);
    [simulation,~]=lmz.services.SectionTransferService. ...
        rephaseSimulationToSection(evaluation.Simulation, ...
        startSection,symmetry);
    state=simulation.States(1,:).';
    eventTimes=localEventTimes(simulation.EventRecords,names);
    returnTime=simulation.Time(end);
end
codec=lmzmodels.slip_biped.BipedSectionDecisionCodec( ...
    startSection,stopSection,eventTimes,returnTime,state,sourceDecision);
configuration.SourceDecisionValues=sourceDecision(:);
configuration.SourceParameterValues=sourceParameters(:);
configuration.InitialSectionState=state(:);
configuration.InitialEventNames=names;
configuration.InitialEventTimes=eventTimes(:);
configuration.InitialReturnTime=returnTime;
configuration.SectionDecisionCodec='biped-section-local-v1';
end

function values=localConfiguredEventTimes(configuration,names)
values=configuration.InitialEventTimes(:);
if isfield(configuration,'InitialEventNames')
    stored=configuration.InitialEventNames;
    if ischar(stored),stored={stored};end
    if ~iscell(stored)||numel(stored)~=numel(values)
        error('lmz:Shooting:SectionSeedEvents', ...
            'Stored section event names/times are inconsistent.');
    end
    ordered=zeros(numel(names),1);
    for index=1:numel(names)
        source=find(strcmp(names{index},stored),1);
        if isempty(source)
            error('lmz:Shooting:SectionSeedEvents', ...
                'Stored section seed is missing event %s.',names{index});
        end
        ordered(index)=values(source);
    end
    values=ordered;
elseif numel(values)~=numel(names)
    error('lmz:Shooting:SectionSeedEvents', ...
        'Stored section event-time count is invalid.');
end
end

function values=localEventTimes(records,names)
values=zeros(numel(names),1);
available={records.Name};
for index=1:numel(names)
    source=find(strcmp(names{index},available),1);
    if isempty(source)
        error('lmz:Shooting:SectionSeedEvents', ...
            'Source orbit is missing event %s.',names{index});
    end
    values(index)=records(source).Time;
end
end

function [decision,migrated]=localizeDecision(obj,decision,parameters,context)
migrated=false;
if numel(decision)==obj.DecisionSchema.count()
    obj.DecisionSchema.validateVector(decision);
    decision=decision(:);
    return
end
if numel(decision)~=obj.ApexProblem.getDecisionSchema().count()
    obj.DecisionSchema.validateVector(decision);
end
obj.ApexProblem.getDecisionSchema().validateVector(decision);
evaluation=obj.ApexProblem.evaluate(decision,parameters,context,true);
[simulation,~]=lmz.services.SectionTransferService. ...
    rephaseSimulationToSection(evaluation.Simulation,obj.StartSection, ...
    obj.Symmetry);
names=obj.SectionCodec.EventNames;
times=localEventTimes(simulation.EventRecords,names);
decision=obj.SectionCodec.encode(simulation.States(1,:).', ...
    times,simulation.Time(end));
migrated=true;
end

function value=localLegacyDecision(codec,decision)
decoded=codec.decode(decision);
value=[decoded.InitialState(2:end);decoded.EventTimes;decoded.ReturnTime];
end

function crossing=localInitialCrossing(section,state)
primary=section;
if isa(primary,'lmz.poincare.CompositeSection'),primary=primary.Primary;end
eventId='';
if isa(primary,'lmz.poincare.NamedEventSection')
    eventId=primary.Descriptor.EventId;
end
crossing=lmz.poincare.SectionCrossing(section.Id,0, ...
    'EventId',eventId,'PreState',state,'PostState',state, ...
    'StateSide',section.StateSide,'Occurrence',1,'Accepted',true, ...
    'Metadata',struct('DecisionOwnedSectionState',true));
end

function value=localMinimumHeight(simulation)
if isempty(simulation),value=NaN;else,value=min(simulation.States(:,3));end
end

function value=localMessages(valid,crossing)
value={};
if ~crossing.Accepted
    value{end+1}=['Return crossing rejected: ' ...
        crossing.RejectionReason '.'];
end
if ~valid&&isempty(value)
    value{end+1}='Section-local candidate is physically invalid.';
end
end

function value=localLineage(configuration,evaluation)
value=struct('Operation','periodic_orbit_configuration', ...
    'Configuration',configuration);
if ~isempty(evaluation)&&isfield(evaluation.Diagnostics,'StartSectionHash')
    value.StartSectionHash=evaluation.Diagnostics.StartSectionHash;
    value.StopSectionHash=evaluation.Diagnostics.StopSectionHash;
    value.SectionCatalogHash=evaluation.Diagnostics.SectionCatalogHash;
elseif ~isempty(evaluation)&&isfield(evaluation.Diagnostics,'PeriodicOrbit')
    details=evaluation.Diagnostics.PeriodicOrbit;
    value.StartSectionHash=details.StartSectionHash;
    value.StopSectionHash=details.StopSectionHash;
    value.SectionCatalogHash=details.SectionCatalogHash;
end
end

function value=localField(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
