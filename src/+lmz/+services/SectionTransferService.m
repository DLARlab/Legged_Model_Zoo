classdef SectionTransferService
    %SECTIONTRANSFERSERVICE Rephase one closed orbit to a catalog section.
    methods
        function result=transfer(~,model,sourceSolution,targetSectionId,context)
            if nargin<5||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if ~isa(model,'lmz.api.LeggedModel')|| ...
                    ~isa(sourceSolution,'lmz.data.Solution')|| ...
                    ~ischar(targetSectionId)
                error('lmz:Poincare:TransferInput', ...
                    'Section transfer requires a model, solution, and section ID.');
            end
            % First recover the source orbit on its own default section.
            % Locating the target is deliberately separate: source and
            % target sections may have different coordinate dimensions,
            % while transfer needs a crossing rather than a periodic
            % coordinate comparison.
            returned=lmz.services.PoincareReturnService().simulate( ...
                model,sourceSolution,struct(),context);
            source=returned.Simulation;
            sections=lmz.poincare.PoincareSectionRegistry.fromJson( ...
                objCatalogPath(model),'ModelId',sourceSolution.ModelId, ...
                'StateSchema',source.StateSchema);
            target=sections.section(targetSectionId);
            symmetry=sections.symmetryFor(targetSectionId);
            [simulation,crossing,orbitError,observablesPreserved, ...
                displacement]=lmz.services.SectionTransferService. ...
                rephaseSimulationToSection(source,target,symmetry);
            configuration=targetConfiguration( ...
                target,symmetry,sourceSolution,simulation);
            [solutionTemplate,codecRephased,reEvaluationError, ...
                verificationTolerance,codecStatus,targetSimulation]= ...
                configuredSolution( ...
                model,sourceSolution,configuration,simulation,context);
            deliveredSimulation=simulation;
            if codecRephased&&isa(targetSimulation, ...
                    'lmz.api.SimulationResult')
                deliveredSimulation=targetSimulation;
            end
            lineage=struct('Operation','section_transfer', ...
                'SourceSolutionId',sourceSolution.Id, ...
                'SourceProblemId',sourceSolution.ProblemId, ...
                'SourceSectionId',sourceSectionId(sourceSolution,returned), ...
                'TargetSectionId',targetSectionId, ...
                'StartSectionId',targetSectionId, ...
                'StopSectionId',targetSectionId, ...
                'Configuration',configuration, ...
                'CrossingTime',crossing.Time, ...
                'SymmetryId',symmetry.Id, ...
                'SymmetryDisplacement',displacement, ...
                'StartSectionHash',target.Descriptor.fingerprint(), ...
                'StopSectionHash',target.Descriptor.fingerprint(), ...
                'SectionCatalogHash',sections.CatalogHash, ...
                'DecisionCodecRephased',codecRephased, ...
                'ReEvaluationMaxError',reEvaluationError, ...
                'ReEvaluationTolerance',verificationTolerance);
            diagnostics=solutionTemplate.Diagnostics;
            if ~isstruct(diagnostics)||~isscalar(diagnostics)
                diagnostics=struct();
            end
            diagnostics.RephasedTrajectory=true;
            diagnostics.DecisionCodecRephased=codecRephased;
            diagnostics.PhysicalOrbitMaxError=orbitError;
            diagnostics.TargetCrossing=crossing.toStruct();
            diagnostics.ReEvaluationMaxError=reEvaluationError;
            diagnostics.ReEvaluationTolerance=verificationTolerance;
            diagnostics.DecisionCodecStatus=codecStatus;
            data=solutionTemplate.toStruct();
            data.DecisionSchema=solutionTemplate.DecisionSchema;
            data.ParameterSchema=solutionTemplate.ParameterSchema;
            data.ResidualBlocks=solutionTemplate.ResidualBlocks;
            data.Id=lmz.util.Ids.new('solution');
            data.Lineage=lineage;
            data.Diagnostics=diagnostics;
            solution=lmz.data.Solution(data);
            value=struct('Solution',solution,'SourceSolution',sourceSolution, ...
                'Simulation',deliveredSimulation,'Crossing',crossing, ...
                'SourceReturn',returned, ...
                'Lineage',lineage,'PhysicalOrbitMaxError',orbitError, ...
                'PhaseInvariantObservablesPreserved',observablesPreserved, ...
                'DecisionCodecRephased',codecRephased);
            result=lmz.data.SectionTransferResult(value);
            context.progress(1,'Section transfer complete.');
        end
    end

    methods (Static)
        function [simulation,crossing,orbitError,observablesPreserved, ...
                displacement]=rephaseSimulationToSection(source,target,symmetry)
            %REPHASESIMULATIONTOSECTION Rotate a closed trajectory to TARGET.
            if ~isa(source,'lmz.api.SimulationResult')|| ...
                    ~isa(target,'lmz.poincare.PoincareSection')|| ...
                    ~isa(symmetry,'lmz.poincare.StateSymmetry')
                error('lmz:Poincare:RephaseInput', ...
                    'Rephasing requires a simulation, section, and symmetry.');
            end
            crossing=locateCrossing(target,source);
            displacement=symmetry.displacement(source.States(end,:).', ...
                source.States(1,:).',source.StateSchema);
            if crossing.Time<=source.Time(1)+timeTolerance(source.Time(1))|| ...
                    crossing.Time>=source.Time(end)-timeTolerance(source.Time(end))
                simulation=source;
                orbitError=closureError(source,symmetry,displacement);
            else
                [simulation,orbitError]=rephaseSimulation( ...
                    source,crossing,symmetry,displacement,target.Id);
            end
            scale=max(1,max(abs(source.States(:))));
            observablesPreserved=isfinite(orbitError)&& ...
                orbitError<=1e-9*scale;
        end
    end
end

function value=targetConfiguration(target,symmetry,source,simulation)
value=struct('StartSectionId',target.Id, ...
    'StopSectionId',target.Id, ...
    'StartStateSide',target.StateSide, ...
    'StopStateSide',target.StateSide, ...
    'StrideCount',1,'SymmetryId',symmetry.Id);
value.SourceParameterValues=source.ParameterValues(:);
sourceDecision=sourceApexDecision(source);
if ~isempty(sourceDecision)
    value.SourceDecisionValues=sourceDecision(:);
end
names=canonicalEventNames(source);
if isempty(names),return,end
value.InitialSectionState=simulation.States(1,:).';
value.InitialEventNames=names;
value.InitialEventTimes=eventTimes(simulation.EventRecords,names);
value.InitialReturnTime=simulation.Time(end);
end

function [solution,verified,errorValue,tolerance,status,actualSimulation]= ...
        configuredSolution( ...
        model,source,configuration,expected,context)
solution=source;verified=false;errorValue=NaN;tolerance=NaN;
status='unsupported-model-codec';actualSimulation=[];
if ~supportsRegisteredCodec(model,source),return,end
problem=model.createProblem('periodic_orbit',configuration);
if ~compatibleSchema(source.ParameterSchema,problem.getParameterSchema(), ...
        source.ParameterValues)
    status='incompatible-decision-codec';
    return
end
sectionLocal=isprop(problem,'SectionCodec')&&~isempty(problem.SectionCodec);
scientificApex=isScientificApexTarget(problem,configuration);
if sectionLocal
    decision=problem.getDecisionSchema().defaults();
elseif scientificApex
    decision=apexSeedDecision(source,configuration,expected, ...
        problem.getDecisionSchema());
else
    if ~compatibleSchema(source.DecisionSchema,problem.getDecisionSchema(), ...
            source.DecisionValues)
        status='incompatible-decision-codec';
        return
    end
    decision=source.DecisionValues;
end
evaluation=problem.evaluate(decision,source.ParameterValues,context,true);
if ~isa(evaluation.Simulation,'lmz.api.SimulationResult')
    status='target-evaluation-has-no-simulation';
    return
end
actualSimulation=evaluation.Simulation;
if sectionLocal
    [verified,errorValue,tolerance]=sameSectionSeed( ...
        expected,evaluation.Simulation,evaluation);
elseif scientificApex
    [verified,errorValue,tolerance]=sameApexSeed( ...
        expected,evaluation.Simulation);
else
    [verified,errorValue,tolerance]=sameTrajectory( ...
        expected,evaluation.Simulation);
end
if ~verified
    status='target-evaluation-mismatch';
    return
end
solution=problem.makeSolution(decision, ...
    source.ParameterValues,evaluation);
if ~strcmp(solution.ProblemId,'periodic_orbit')
    error('lmz:Poincare:TransferCodecProblem', ...
        'A verified built-in transfer did not create periodic_orbit.');
end
if sectionLocal&&~evaluation.PhysicalValidity
    status='verified-section-local-seed-requires-correction';
elseif sectionLocal
    status='verified-section-local-seed';
elseif scientificApex&&~evaluation.PhysicalValidity
    status='verified-apex-seed-requires-correction';
elseif scientificApex
    status='verified-apex-seed';
else
    status='verified';
end
end

function valid=isScientificApexTarget(problem,configuration)
valid=hasCyclicSchedule(problem.getDecisionSchema())&& ...
    strcmp(configuration.StartSectionId,'apex')&& ...
    strcmp(configuration.StopSectionId,'apex');
end

function value=apexSeedDecision(~,configuration,simulation,schema)
expectedCount=schema.count();
if isfield(configuration,'SourceDecisionValues')&& ...
        isnumeric(configuration.SourceDecisionValues)&& ...
        numel(configuration.SourceDecisionValues)==expectedCount&& ...
    all(isfinite(configuration.SourceDecisionValues(:)))
    value=configuration.SourceDecisionValues(:);
else
    value=apexDecisionFromSimulation(schema,simulation);
end
end

function value=apexDecisionFromSimulation(schema,simulation)
value=schema.defaults();stateNames=simulation.StateSchema.names();
eventNames={simulation.EventRecords.Name};
for index=1:schema.count()
    spec=schema.Specs(index);
    stateIndex=find(strcmp(spec.Name,stateNames),1);
    if strcmp(spec.Group,'initial_state')&&~isempty(stateIndex)
        value(index)=simulation.States(1,stateIndex);
    elseif strcmp(spec.Topology,'cyclic_time')
        eventName=eventNameForSpec(spec.Name,eventNames);
        value(index)=eventTimes(simulation.EventRecords,{eventName});
    elseif strcmp(spec.Group,'event_timing')&& ...
            any(arrayfun(@(candidate)strcmp(candidate.PeriodSource, ...
            spec.Name),schema.Specs))
        value(index)=simulation.Time(end);
    end
end
schema.validateVector(value);
end

function [valid,errorValue,tolerance]=sameApexSeed(expected,actual)
valid=false;errorValue=Inf;
scale=max([1;abs(expected.Time(:)); ...
    abs(expected.States(1,2:end).');abs(actual.Time(:)); ...
    abs(actual.States(1,2:end).')]);
tolerance=1e-5*scale;
if ~isequal(expected.StateSchema.names(),actual.StateSchema.names())|| ...
        isempty(expected.Time)||isempty(actual.Time)
    return
end
errorValue=max([0;abs(expected.Time(1)-actual.Time(1)); ...
    abs(expected.Time(end)-actual.Time(end)); ...
    abs(expected.States(1,2:end).'-actual.States(1,2:end).')]);
valid=isfinite(errorValue)&&errorValue<=tolerance;
end

function [valid,errorValue,tolerance]=sameSectionSeed(expected,actual,evaluation)
valid=false;errorValue=Inf;
scale=max([1;abs(expected.Time(:));abs(expected.States(1,:).'); ...
    abs(actual.Time(:));abs(actual.States(1,:).')]);
tolerance=1e-10*scale;
if ~isequal(expected.StateSchema.names(),actual.StateSchema.names())|| ...
        isempty(expected.Time)||isempty(actual.Time)|| ...
        ~isfield(evaluation.Diagnostics,'DirectSectionIntegration')|| ...
        ~evaluation.Diagnostics.DirectSectionIntegration
    return
end
errorValue=max([0;abs(expected.Time(1)-actual.Time(1)); ...
    abs(expected.Time(end)-actual.Time(end)); ...
    abs(expected.States(1,:).'-actual.States(1,:).')]);
valid=isfinite(errorValue)&&errorValue<=tolerance;
end

function names=canonicalEventNames(source)
names={};
schema=source.DecisionSchema;
if ~isa(schema,'lmz.schema.VariableSchema'),return,end
for index=1:schema.count()
    spec=schema.Specs(index);
    if strcmp(spec.Topology,'cyclic_time')
        names{end+1}=eventNameForSpec(spec.Name,{}); %#ok<AGROW>
    end
end
if ~isempty(names),return,end
lineage=source.Lineage;
if isstruct(lineage)&&isscalar(lineage)&& ...
        isfield(lineage,'Configuration')&& ...
        isstruct(lineage.Configuration)&& ...
        isfield(lineage.Configuration,'InitialEventNames')
    names=lineage.Configuration.InitialEventNames;
    if ischar(names),names={names};end
    if ~iscell(names)||~all(cellfun(@ischar,names)),names={};end
end
end

function value=eventNameForSpec(name,available)
value=name;
if ~isempty(available)&&any(strcmp(value,available)),return,end
if numel(name)>1&&name(1)=='t'
    candidate=name(2:end);
    if isempty(available)||any(strcmp(candidate,available))
        value=candidate;
    end
end
end

function values=eventTimes(records,names)
values=zeros(numel(names),1);available={records.Name};
for index=1:numel(names)
    source=find(strcmp(names{index},available),1);
    if isempty(source)
        error('lmz:Poincare:TransferSeedEvent', ...
            'Transferred simulation is missing event %s.',names{index});
    end
    values(index)=records(source).Time;
end
end

function value=sourceApexDecision(source)
value=[];
lineage=source.Lineage;
if isstruct(lineage)&&isscalar(lineage)&& ...
        isfield(lineage,'Configuration')&& ...
        isstruct(lineage.Configuration)&& ...
        isscalar(lineage.Configuration)&& ...
        isfield(lineage.Configuration,'SourceDecisionValues')
    value=lineage.Configuration.SourceDecisionValues;
    return
end
if hasCyclicSchedule(source.DecisionSchema)
    value=source.DecisionValues;
end
end

function valid=supportsRegisteredCodec(model,source)
modelId=model.getManifest().id;
problems=model.listProblems();
valid=strcmp(source.ModelId,modelId)&& ...
    any(strcmp('periodic_orbit',problems))&& ...
    any(strcmp(source.ProblemId,problems));
end

function valid=hasCyclicSchedule(schema)
valid=isa(schema,'lmz.schema.VariableSchema')&& ...
    any(arrayfun(@(spec)strcmp(spec.Topology,'cyclic_time'),schema.Specs));
end

function valid=compatibleSchema(source,target,values)
valid=isequal(source.names(),target.names())&& ...
    source.count()==target.count();
if ~valid,return,end
try
    target.validateVector(values);
catch
    valid=false;
end
end

function [valid,errorValue,tolerance]=sameTrajectory(expected,actual)
valid=false;errorValue=Inf;
scale=max([1;abs(expected.Time(:));abs(expected.States(:)); ...
    abs(actual.Time(:));abs(actual.States(:))]);
tolerance=1e-10*scale;
if ~isequal(size(expected.Time),size(actual.Time))|| ...
        ~isequal(size(expected.States),size(actual.States))|| ...
        ~isequal(expected.StateSchema.names(),actual.StateSchema.names())
    return
end
errorValue=max([0;abs(expected.Time(:)-actual.Time(:)); ...
    abs(expected.States(:)-actual.States(:))]);
valid=isfinite(errorValue)&&errorValue<=tolerance;
end

function path=objCatalogPath(model)
manifest=model.registeredManifest();
if ~isempty(manifest)&&isfield(manifest,'poincareSectionsPath')
    path=manifest.poincareSectionsPath;return
end
path=fullfile(lmz.util.ProjectPaths.catalog(), ...
    model.getManifest().id,'poincare_sections.json');
end

function [result,errorValue]=rephaseSimulation(source,crossing,symmetry, ...
        displacement,targetSectionId)
time=source.Time;period=time(end);origin=crossing.Time;
if origin<=time(1)||origin>=period
    error('lmz:Poincare:TransferCrossingTime', ...
        'Transfer crossing must lie strictly inside the source period.');
end
after=find(time>origin);before=find(time>0&time<origin);
startState=crossing.State(:).';
afterStates=source.States(after,:);
beforeStates=symmetry.apply(source.States(before,:), ...
    displacement,source.StateSchema);
endState=symmetry.apply(startState,displacement,source.StateSchema);
newTime=[0;time(after)-origin;period-origin+time(before);period];
newStates=[startState;afterStates;beforeStates;endState];
newModes=rotateModes(source.Modes,after,before,crossing,numel(time));
records=rotateRecords(source.EventRecords,origin,period,symmetry, ...
    displacement,source.StateSchema);
forces=[];
if ~isempty(source.GroundReactionForces)
    crossingForce=interp1(time,source.GroundReactionForces,origin,'linear');
    forces=[crossingForce;source.GroundReactionForces(after,:); ...
        source.GroundReactionForces(before,:);crossingForce];
end
diagnostics=source.Diagnostics;
diagnostics.SectionTransfer=struct('TargetSectionId',targetSectionId, ...
    'SourceTimeOrigin',origin,'SymmetryId',symmetry.Id, ...
    'SymmetryDisplacement',displacement, ...
    'SourceSampleCount',numel(time),'TransferredSampleCount',numel(newTime));
kinematics=rotateSampledValue(source.Kinematics,after,before,numel(time));
observables=struct('rephased',true, ...
    'source_observables',source.Observables);
errorValue=trajectoryOrbitError(source,newTime,newStates,crossing,symmetry, ...
    displacement);
diagnostics.SectionTransfer.PhysicalOrbitMaxError=errorValue;
result=lmz.api.SimulationResult(newTime,source.StateSchema,newStates, ...
    newModes,observables,source.Parameters,diagnostics,source.Provenance, ...
    'EventRecords',records,'GroundReactionForces',forces, ...
    'Kinematics',kinematics);
end

function value=trajectoryOrbitError(source,newTime,newStates,crossing, ...
        symmetry,shift)
period=source.Time(end);origin=crossing.Time;
expected=zeros(size(newStates));
for index=1:numel(newTime)
    phase=newTime(index)+origin;
    wrapped=phase>period+timeTolerance(period);
    if wrapped,phase=phase-period;end
    if index==1
        state=crossing.State(:).';
    elseif index==numel(newTime)
        state=symmetry.apply(crossing.State(:).',shift,source.StateSchema);
    else
        state=interp1(source.Time,source.States,phase,'linear');
        if wrapped
            state=symmetry.apply(state,shift,source.StateSchema);
        end
    end
    expected(index,:)=state;
end
value=max(abs(newStates(:)-expected(:)));
closureExpected=symmetry.apply(newStates(1,:),shift,source.StateSchema);
value=max(value,max(abs(newStates(end,:)-closureExpected)));
end

function value=closureError(simulation,symmetry,shift)
expected=symmetry.apply(simulation.States(1,:),shift, ...
    simulation.StateSchema);
value=max(abs(simulation.States(end,:)-expected));
end

function modes=rotateModes(source,after,before,crossing,total)
if iscell(source)
    if strcmp(crossing.StateSide,'pre'),first={crossing.ModeBefore}; ...
    else,first={crossing.ModeAfter};end
    if isempty(first{1}),first=source(max(1,findIndex(after,1)));end
    modes=[first;source(after);source(before);first];return
end

if ~isstruct(source),modes=source;return,end
modes=struct();names=fieldnames(source);
for index=1:numel(names)
    value=source.(names{index});
    if numel(value)==total
        value=value(:);first=value(max(1,findIndex(after,1)));
        modes.(names{index})=[first;value(after);value(before);first];
    else
        modes.(names{index})=value;
    end
end
end

function value=rotateSampledValue(source,after,before,total)
value=source;
if ~isstruct(source)||~isscalar(source),return,end
names=fieldnames(source);
for index=1:numel(names)
    item=source.(names{index});
    if isnumeric(item)&&size(item,1)==total
        first=item(max(1,findIndex(after,1)),:);
        value.(names{index})=[first;item(after,:);item(before,:);first];
    elseif iscell(item)&&size(item,1)==total
        first=item(max(1,findIndex(after,1)),:);
        value.(names{index})=[first;item(after,:);item(before,:);first];
    end
end
end

function value=findIndex(indices,fallback)
if isempty(indices),value=fallback;else,value=indices(1);end
end

function records=rotateRecords(records,origin,period,symmetry,shift,schema)
for index=1:numel(records)
    wrapped=records(index).Time<origin;
    if records(index).Time>=origin
        records(index).Time=records(index).Time-origin;
    else
        records(index).Time=records(index).Time+period-origin;
    end
    if wrapped
        fields={'State','PreState','PostState'};
        for fieldIndex=1:numel(fields)
            name=fields{fieldIndex};
            if isfield(records,name)
                records(index).(name)=symmetry.apply( ...
                    records(index).(name),shift,schema);
            end
        end
    end
end
if ~isempty(records)
    [~,order]=sortrows([[records.Time].',(1:numel(records)).'],[1 2]);
    records=records(order);
end
end

function crossing=locateCrossing(section,simulation)
if isa(section,'lmz.poincare.NamedEventSection')|| ...
        (isa(section,'lmz.poincare.CompositeSection')&& ...
        isa(section.Primary,'lmz.poincare.NamedEventSection'))
    crossing=locateNamedEvent(section,simulation.EventRecords);
elseif isa(section,'lmz.poincare.StateFunctionSection')|| ...
        (isa(section,'lmz.poincare.CompositeSection')&& ...
        isa(section.Primary,'lmz.poincare.StateFunctionSection'))
    crossing=locateStatePlane(section,simulation);
else
    error('lmz:Poincare:TransferSectionKind', ...
        'Section transfer requires a named-event or state-plane primary.');
end
if isempty(crossing)
    error('lmz:Poincare:TransferCrossingNotFound', ...
        'No accepted target-section crossing was found.');
end
end

function crossing=locateNamedEvent(section,records)
crossing=[];
if isempty(records),return,end
[~,order]=sortrows([[records.Time].',(1:numel(records)).'],[1 2]);
records=records(order);history={};occurrence=0;
for index=1:numel(records)
    record=records(index);
    if section.matches(record)
        occurrence=occurrence+1;
        candidate=section.crossingFromRecord(record, ...
            'Occurrence',occurrence,'EventHistory',history);
        if candidate.Accepted,crossing=candidate;return,end
    end
    history{end+1}=eventId(record); %#ok<AGROW>
end
end

function crossing=locateStatePlane(section,simulation)
crossing=[];occurrence=0;
for index=1:numel(simulation.Time)-1
    history=eventsBefore(simulation.EventRecords,simulation.Time(index));
    [detected,candidate]=section.detectCrossing( ...
        simulation.Time(index),simulation.States(index,:).', ...
        simulation.Time(index+1),simulation.States(index+1,:).', ...
        'ModeId',modeAt(simulation.Modes,index), ...
        'Occurrence',occurrence+1,'EventHistory',history);
    if detected
        occurrence=occurrence+1;
        if candidate.Accepted,crossing=candidate;return,end
    end
end
end

function value=eventsBefore(records,time)
value={};
for index=1:numel(records)
    if records(index).Time<time
        value{end+1}=eventId(records(index)); %#ok<AGROW>
    end
end
end

function value=eventId(record)
if isfield(record,'Id')
    value=record.Id;
elseif isfield(record,'Name')
    value=record.Name;
else
    value='';
end
end

function value=modeAt(modes,index)
value='';
if iscell(modes)&&numel(modes)>=index&&ischar(modes{index})
    value=modes{index};
elseif isstring(modes)&&numel(modes)>=index
    value=char(modes(index));
end
end

function value=timeTolerance(time)
value=64*eps(max(1,abs(time)));
end

function value=sourceSectionId(solution,returned)
value=returned.StrideDefinition.StartSectionId;
lineage=solution.Lineage;
if ~isstruct(lineage)||~isscalar(lineage),return,end
if isfield(lineage,'TargetSectionId')&&ischar(lineage.TargetSectionId)
    value=lineage.TargetSectionId;
elseif isfield(lineage,'Configuration')&& ...
        isstruct(lineage.Configuration)&& ...
        isfield(lineage.Configuration,'StartSectionId')&& ...
        ischar(lineage.Configuration.StartSectionId)
    value=lineage.Configuration.StartSectionId;
end
end
