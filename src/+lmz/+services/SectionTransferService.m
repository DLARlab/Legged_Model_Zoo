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
            configuration=targetConfiguration(target,symmetry);
            [solutionTemplate,codecRephased,reEvaluationError, ...
                verificationTolerance,codecStatus]=configuredSolution( ...
                model,sourceSolution,configuration,simulation,context);
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
                'Simulation',simulation,'Crossing',crossing, ...
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

function value=targetConfiguration(target,symmetry)
value=struct('StartSectionId',target.Id, ...
    'StopSectionId',target.Id, ...
    'StartStateSide',target.StateSide, ...
    'StopStateSide',target.StateSide, ...
    'StrideCount',1,'SymmetryId',symmetry.Id);
end

function [solution,verified,errorValue,tolerance,status]=configuredSolution( ...
        model,source,configuration,expected,context)
solution=source;verified=false;errorValue=NaN;tolerance=NaN;
status='unsupported-model-codec';
if ~supportsBuiltinCodec(model,source),return,end
problem=model.createProblem('periodic_orbit',configuration);
if ~compatibleSchema(source.DecisionSchema,problem.getDecisionSchema(), ...
        source.DecisionValues)|| ...
        ~compatibleSchema(source.ParameterSchema,problem.getParameterSchema(), ...
        source.ParameterValues)
    status='incompatible-decision-codec';
    return
end
evaluation=problem.evaluate(source.DecisionValues, ...
    source.ParameterValues,context,true);
if ~isa(evaluation.Simulation,'lmz.api.SimulationResult')
    status='target-evaluation-has-no-simulation';
    return
end
[verified,errorValue,tolerance]=sameTrajectory( ...
    expected,evaluation.Simulation);
if ~verified
    status='target-evaluation-mismatch';
    return
end
solution=problem.makeSolution(source.DecisionValues, ...
    source.ParameterValues,evaluation);
if ~strcmp(solution.ProblemId,'periodic_orbit')
    error('lmz:Poincare:TransferCodecProblem', ...
        'A verified built-in transfer did not create periodic_orbit.');
end
status='verified';
end

function valid=supportsBuiltinCodec(model,source)
modelId=model.getManifest().id;
valid=false;
switch modelId
    case 'tutorial_hopper'
        valid=isa(model,'lmzmodels.tutorial_hopper.Model')&& ...
            any(strcmp(source.ProblemId,{'periodic_hop','periodic_orbit'}));
    case 'slip_quadruped'
        valid=isa(model,'lmzmodels.slip_quadruped.Model')&& ...
            any(strcmp(source.ProblemId,{'periodic_apex','periodic_orbit'}));
    case 'slip_biped'
        valid=isa(model,'lmzmodels.slip_biped.Model')&& ...
            any(strcmp(source.ProblemId,{'periodic_apex','periodic_orbit'}));
end
valid=valid&&strcmp(source.ModelId,modelId);
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
