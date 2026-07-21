classdef StrideTemplateLibrary
    %STRIDETEMPLATELIBRARY Hash-bound load-transition initialization data.
    properties (SetAccess=private)
        RootPath
        ManifestPath
        Manifest
    end

    methods
        function obj=StrideTemplateLibrary(rootPath)
            if nargin<1
                rootPath=fullfile(lmz.util.ProjectPaths.examples(),'data', ...
                    'slip_quad_load','Scientific','Templates');
            end
            obj.RootPath=lmz.util.PathGuard.canonical(rootPath,true);
            obj.ManifestPath=lmz.util.PathGuard.resolveWithin( ...
                obj.RootPath,'template_manifest.json',true);
            obj.Manifest=lmz.io.SafeJson.read(obj.ManifestPath, ...
                'Root',obj.RootPath);
            obj.validateManifest();
        end

        function value=records(obj)
            value=obj.Manifest.files;
            if iscell(value),value=[value{:}];end
        end

        function value=record(obj,id)
            records=obj.records();index=find(strcmp({records.id},id),1);
            if isempty(index)
                error('lmz:QuadLoad:UnknownStrideTemplate', ...
                    'Unknown quad-load stride template %s.',id);
            end
            value=records(index);
        end

        function value=pathFor(obj,id)
            record=obj.record(id);
            value=lmz.util.PathGuard.resolveWithin( ...
                obj.RootPath,record.relativePath,true);
        end

        function value=validateHash(obj,id)
            record=obj.record(id);path=obj.pathFor(id);
            value=strcmpi(lmz.util.FileHash.sha256(path),record.sha256);
        end

        function value=load(obj,id,context)
            if nargin<3||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            record=obj.record(id);path=obj.pathFor(id);
            if ~obj.validateHash(id)
                error('lmz:QuadLoad:StrideTemplateHash', ...
                    'Stride template %s does not match its SHA-256.',id);
            end
            value=cachedTemplate(record,path,obj.Manifest,context);
        end

        function value=all(obj,context)
            if nargin<2,context=lmz.api.RunContext.synchronous(0);end
            records=obj.records();value=cell(numel(records),1);
            for index=1:numel(records)
                value{index}=obj.load(records(index).id,context);
            end
        end

        function value=segments(obj,context)
            if nargin<2,context=lmz.api.RunContext.synchronous(0);end
            templates=obj.all(context);value=struct([]);
            for templateIndex=1:numel(templates)
                template=templates{templateIndex};
                for stride=1:numel(template.Segments)
                    item=template.Segments(stride);
                    item.TemplateId=template.Id;
                    item.GaitLabel=template.GaitLabel;
                    item.SourceHash=template.SourceHash;
                    item.SourceCommit=template.SourceCommit;
                    if isempty(value),value=item;else,value(end+1,1)=item;end %#ok<AGROW>
                end
            end
            value=value(:);
        end

        function [selected,diagnostics]=select(obj,query,context)
            if nargin<2||isempty(query),query=struct();end
            if nargin<3,context=lmz.api.RunContext.synchronous(0);end
            candidates=obj.segments(context);scores=zeros(numel(candidates),1);
            components=cell(numel(candidates),1);
            for index=1:numel(candidates)
                [scores(index),components{index}]=templateScore( ...
                    candidates(index),query);
            end
            [best,bestIndex]=min(scores);selected=candidates(bestIndex);
            diagnostics=struct('SelectedTemplateId',selected.TemplateId, ...
                'SelectedStrideIndex',selected.StrideIndex, ...
                'Score',best,'Scores',scores,'Components',{components}, ...
                'CandidateCount',numel(candidates), ...
                'Method','scaled_state_schedule_control_physics_gait_v1');
        end
    end

    methods (Access=private)
        function validateManifest(obj)
            required={'schemaVersion','modelId','sourceRepository', ...
                'sourceCommit','extraExamplesIntroductionCommit', ...
                'redistribution','files'};
            if ~all(isfield(obj.Manifest,required))|| ...
                    ~strcmp(obj.Manifest.modelId,'slip_quad_load')
                error('lmz:QuadLoad:StrideTemplateManifest', ...
                    'The stride-template manifest header is invalid.');
            end
            records=obj.records();ids={records.id};
            if numel(unique(ids))~=numel(ids)
                error('lmz:QuadLoad:StrideTemplateManifest', ...
                    'Stride-template IDs must be unique.');
            end
            fields={'id','gaitLabel','relativePath','sourcePath','sha256', ...
                'byteCount','strideCount','xAccumLength','role'};
            for index=1:numel(records)
                item=records(index);
                if ~all(isfield(item,fields))|| ...
                        isempty(regexp(item.sha256,'^[0-9a-f]{64}$','once'))|| ...
                        item.xAccumLength~=44+13*(item.strideCount-1)
                    error('lmz:QuadLoad:StrideTemplateManifest', ...
                        'Stride-template record %d is invalid.',index);
                end
                path=lmz.util.PathGuard.resolveWithin( ...
                    obj.RootPath,item.relativePath,true);
                information=dir(path);
                if information.bytes~=item.byteCount
                    error('lmz:QuadLoad:StrideTemplateSize', ...
                        'Stride template %s has the wrong byte count.',item.id);
                end
            end
        end
    end
end

function value=cachedTemplate(record,path,manifest,context)
persistent cacheKeys cacheValues
key=[record.sha256 ':' manifest.sourceCommit];
if isempty(cacheKeys),cacheKeys={};cacheValues={};end
index=find(strcmp(cacheKeys,key),1);
if ~isempty(index),value=cacheValues{index};return,end
dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(path);
if dataset.StrideCount~=record.strideCount|| ...
        numel(dataset.XAccum)~=record.xAccumLength
    error('lmz:QuadLoad:StrideTemplateLayout', ...
        'Stride template %s does not match its declared layout.',record.id);
end
raw=lmzmodels.slip_quad_load.MultiStrideSimulator().runRaw( ...
    dataset.XAccum,context,false);
plan=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan(dataset.XAccum);
policy=lmzmodels.slip_quad_load.QuadLoadEnergyPolicy( ...
    'Id','allow_non_neutral');
segments=repmat(emptySegment(),dataset.StrideCount,1);
for stride=1:dataset.StrideCount
    boundary=raw.StrideBoundaries(stride);
    startState=raw.LegacyStates(boundary.RawStartIndex,:).';
    terminalState=raw.LegacyStates(boundary.RawEndIndex,:).';
    rows=27*(stride-1)+(1:9);contact=raw.Residual(rows);
    activation=0;activationDetails=struct('Convention','none_first_stride');
    if stride>1
        [activation,activationDetails]=policy.parameterTransitionEnergy( ...
            startState,plan.StrideSpecs(stride-1),plan.StrideSpecs(stride));
    end
    startEnergy=policy.mechanicalEnergy(startState,plan.StrideSpecs(stride));
    terminalEnergy=policy.mechanicalEnergy(terminalState,plan.StrideSpecs(stride));
    segments(stride)=struct('StrideIndex',stride, ...
        'InitialSectionState',startState, ...
        'TerminalSectionState',terminalState, ...
        'EventSchedule',plan.StrideSpecs(stride).EventSchedule, ...
        'ControlParameters',plan.StrideSpecs(stride).ControlParameters, ...
        'PhysicalParameters',plan.StrideSpecs(stride).PhysicalParameters, ...
        'ContactResiduals',contact(:), ...
        'ContactResidualNorm',norm(contact), ...
        'EnergyWorkMetadata',struct( ...
        'ParameterActivationDelta',activation, ...
        'DefaultDeclaredWork',0,'NeutralConstraintResidual',activation, ...
        'SegmentMechanicalEnergyDelta',terminalEnergy-startEnergy, ...
        'ActivationDetails',activationDetails));
end
value=struct('Id',record.id,'GaitLabel',record.gaitLabel, ...
    'Path',path,'StrideCount',dataset.StrideCount, ...
    'XAccum',dataset.XAccum,'InitialSectionState', ...
    segments(1).InitialSectionState,'TerminalSectionState', ...
    segments(end).TerminalSectionState,'Segments',segments, ...
    'SourceRepository',manifest.sourceRepository, ...
    'SourceCommit',manifest.sourceCommit, ...
    'SourcePath',record.sourcePath,'SourceHash',record.sha256, ...
    'ExtraExamplesIntroductionCommit', ...
    manifest.extraExamplesIntroductionCommit, ...
    'Redistribution',manifest.redistribution);
cacheKeys{end+1}=key;cacheValues{end+1}=value;
end

function value=emptySegment()
value=struct('StrideIndex',0,'InitialSectionState',zeros(18,1), ...
    'TerminalSectionState',zeros(18,1),'EventSchedule',struct(), ...
    'ControlParameters',struct(),'PhysicalParameters',struct(), ...
    'ContactResiduals',zeros(0,1),'ContactResidualNorm',Inf, ...
    'EnergyWorkMetadata',struct());
end

function [score,components]=templateScore(candidate,query)
state=component(candidate.InitialSectionState,fieldOr(query, ...
    'InitialSectionState',[]));
schedule=component(scheduleVector(candidate.EventSchedule),fieldOr(query, ...
    'EventSchedule',[]));
controls=component(candidate.ControlParameters.PostSwingStiffness(:), ...
    controlVector(fieldOr(query,'ControlParameters',[])));
physics=component(candidate.PhysicalParameters.TransitionInvariantVector(:), ...
    physicalVector(fieldOr(query,'PhysicalParameters',[])));
gait=0;
if isfield(query,'GaitLabel')&&~isempty(query.GaitLabel)&& ...
        ~strcmp(query.GaitLabel,candidate.GaitLabel)
    gait=1;
end
contact=.01*log1p(candidate.ContactResidualNorm/1e-8);
components=struct('State',state,'Schedule',schedule, ...
    'Controls',controls,'Physics',physics,'GaitMismatch',gait, ...
    'ContactQualityPenalty',contact);
score=state+schedule+controls+physics+gait+contact;
end

function value=component(candidate,target)
if isempty(target),value=0;return,end
candidate=candidate(:);target=target(:);
if numel(candidate)~=numel(target)
    value=1e6;return
end
scale=max(1,abs(target));value=norm((candidate-target)./scale)/sqrt(numel(target));
end

function value=scheduleVector(source)
if isa(source,'lmz.schedule.EventSchedule')
    names=lmzmodels.slip_quad_load.ContactConstraintProvider().eventNames();
    value=[source.namedTimes(names);source.ReturnTime];
elseif isstruct(source)&&isfield(source,'Times')
    value=source.Times(:);
else
    value=[];
end
end

function value=controlVector(source)
if isstruct(source)&&isfield(source,'PostSwingStiffness')
    value=source.PostSwingStiffness(:);
else
    value=[];
end
end

function value=physicalVector(source)
if isstruct(source)&&isfield(source,'TransitionInvariantVector')
    value=source.TransitionInvariantVector(:);
else
    value=[];
end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
