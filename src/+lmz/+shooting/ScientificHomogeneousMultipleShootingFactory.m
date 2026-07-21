classdef ScientificHomogeneousMultipleShootingFactory
    %SCIENTIFICHOMOGENEOUSMULTIPLESHOOTINGFACTORY Direct N-return evidence.
    %   Builds a homogeneous scientific horizon from the model-owned
    %   touchdown-section codec and adapter.  The source periodic solution
    %   is used only to initialize section coordinates and a fixed schedule;
    %   every residual call performs N independent direct propagations and
    %   exposes their contact rows and interface defects.
    methods (Static)
        function problem=create(model,configuration)
            if nargin<2,configuration=struct();end
            if ~isa(model,'lmz.api.LeggedModel')|| ...
                    ~isstruct(configuration)||~isscalar(configuration)
                error('lmz:Shooting:ScientificFactoryInput', ...
                    'A model and scalar configuration are required.');
            end
            modelId=model.getManifest().id;
            profile=localProfile(modelId);
            localValidateControlMask(configuration);
            if isfield(configuration,'Horizon')
                horizon=configuration.Horizon;
                if isstruct(horizon)
                    horizon=lmz.shooting.ShootingHorizon.fromStruct(horizon);
                end
                if ~isa(horizon,'lmz.shooting.ShootingHorizon')|| ...
                        ~strcmp(horizon.ModelId,modelId)
                    error('lmz:Shooting:ScientificStoredHorizon', ...
                        'Stored shooting horizon does not match the model.');
                end
                sectionId=horizon.Nodes{1}.SectionId;
            else
                sectionId=fieldOr(configuration,'StartSectionId', ...
                    profile.DefaultSectionId);
            end
            localConfiguration=struct('StartSectionId',sectionId, ...
                'StopSectionId',sectionId);
            if strcmp(modelId,'slip_biped')
                localConfiguration.FixedConfiguration=fieldOr( ...
                    configuration,'FixedConfiguration',profile.FixedConfiguration);
            end
            localProblem=model.createProblem('periodic_orbit', ...
                localConfiguration);
            if localProblem.ApexEquivalent||isempty(localProblem.SectionAdapter)
                error('lmz:Shooting:ScientificSectionRequired', ...
                    'Scientific multiple shooting requires a direct non-apex section.');
            end
            if ~exist('horizon','var')
                horizon=localHorizon(localProblem,configuration,modelId);
            end
            if isfield(configuration,'ShootingDecisionSchema')
                shootingSchema=configuration.ShootingDecisionSchema;
                if isstruct(shootingSchema)
                    shootingSchema=lmz.shooting.ShootingDecisionSchema. ...
                        fromStruct(shootingSchema);
                end
            else
                shootingSchema=lmz.shooting.ShootingDecisionSchema. ...
                    fromHorizon(horizon);
            end
            stored=configuration;
            removable={'Horizon','ShootingDecisionSchema'};
            for index=1:numel(removable)
                if isfield(stored,removable{index})
                    stored=rmfield(stored,removable{index});
                end
            end
            stored.ProblemId='multiple_shooting';
            stored.Formulation='periodic';
            stored.ExpectedLocalDimension=0;
            stored.HorizonLength=horizon.segmentCount();
            stored.StartSectionId=sectionId;
            stored.StopSectionId=sectionId;
            stored.DirectSectionIntegration=true;
            stored.HomogeneousClosedStrideRepetition=false;
            problem=lmz.shooting.PeriodicMultipleShootingProblem( ...
                model,shootingSchema,localProblem.getParameterSchema(), ...
                localProblem.getParameterSchema().defaults(),horizon, ...
                localProblem.SectionAdapter,stored);
        end
    end
end

function horizon=localHorizon(localProblem,configuration,modelId)
count=fieldOr(configuration,'HorizonLength',2);
if ~isnumeric(count)||~isscalar(count)||~isfinite(count)|| ...
        count<1||count~=fix(count)
    error('lmz:Shooting:ScientificHorizonLength', ...
        'HorizonLength must be a positive integer.');
end
context=lmz.api.RunContext.synchronous(0);
decision=localProblem.getDecisionSchema().defaults();
parameters=localProblem.getParameterSchema().defaults();
decoded=localProblem.SectionCodec.decode(decision);
propagated=localProblem.SectionAdapter.evaluate( ...
    decision,parameters,context,false);
translation=propagated.TerminalState(1)-decoded.InitialState(1);
stateSchema=localProblem.SectionCodec.StateCoordinates;
coordinateCount=stateSchema.count();
interfaceMask=localInterfaceMask( ...
    configuration,coordinateCount,count);
nodes=cell(count+1,1);
for index=1:numel(nodes)
    full=decoded.InitialState(:);
    full(1)=full(1)+(index-1)*translation;
    free=interfaceMask(:,index);
    nodes{index}=lmz.shooting.ShootingNode( ...
        'SectionId',localProblem.StartSection.Id, ...
        'SectionHash',localProblem.StartSection.Descriptor.fingerprint(), ...
        'StateSide',localProblem.StartSection.StateSide, ...
        'StateSchema',stateSchema,'FullState',full, ...
        'WorldTranslation',(index-1)*translation, ...
        'FreeCoordinateMask',free, ...
        'Symmetry',struct('Id',localProblem.Symmetry.Id), ...
        'Lineage',struct('Source','section-local-periodic-seed', ...
        'SourceProblemId','periodic_orbit'));
end
eventFree=localEventMask(configuration,decoded.EventSchedule.count());
schedule=decoded.EventSchedule.withFixedMask( ...
    ~eventFree(1:end-1),~eventFree(end));
energyMode=localEnergyMode(configuration);
declaredWork=localDeclaredWork(configuration,count);
energyTolerance=fieldOr(configuration,'EnergyTolerance',1e-9);
if ~isnumeric(energyTolerance)||~isscalar(energyTolerance)|| ...
        ~isfinite(energyTolerance)||energyTolerance<0
    error('lmz:Shooting:ScientificEnergyTolerance', ...
        'EnergyTolerance must be finite and nonnegative.');
end
segments=cell(count,1);
for index=1:count
    energy=struct('Mode',energyMode, ...
        'DeclaredWork',declaredWork(index), ...
        'Tolerance',energyTolerance);
    segments{index}=lmz.shooting.ShootingSegment( ...
        'Index',index,'StartNode',nodes{index}, ...
        'StopNode',nodes{index+1},'EventSchedule',schedule, ...
        'ContactConstraints',schedule.names(), ...
        'PhysicalParameters',struct('ProblemValues',parameters(:)), ...
        'ControlParameters',struct(), ...
        'EnergyWorkSpecification',energy, ...
        'SourceLineage',struct( ...
        'Source','direct-section-local-homogeneous-seed', ...
        'ApexOracleUsedDuringResidualEvaluation',false));
end
horizon=lmz.shooting.ShootingHorizon('ModelId',modelId, ...
    'ProblemId','multiple_shooting','Nodes',nodes,'Segments',segments, ...
    'Formulation','periodic','Lineage',struct( ...
    'Source','section-local-periodic-seed', ...
    'SegmentCount',count,'SchedulesFixed',~any(eventFree), ...
    'InterfaceStateMask',interfaceMask, ...
    'EventFreeMask',eventFree,'EnergyWorkMode',energyMode, ...
    'HomogeneousClosedStrideRepetition',false));
end

function value=localInterfaceMask(configuration,coordinateCount,count)
if ~isfield(configuration,'InterfaceStateMask')
    value=false(coordinateCount,count+1);
    if count>1,value(:,2:count)=true;end
    return
end
source=configuration.InterfaceStateMask;
if ~(islogical(source)||(isnumeric(source)&&isreal(source)&& ...
        all(ismember(source(:),[0 1]))))
    error('lmz:Shooting:ScientificInterfaceStateMask', ...
        'InterfaceStateMask must be a logical mask.');
end
source=logical(source);
if isscalar(source)
    value=repmat(source,coordinateCount,count+1);
elseif isvector(source)&&numel(source)==coordinateCount
    value=repmat(source(:),1,count+1);
elseif isequal(size(source),[coordinateCount count+1])
    value=source;
else
    error('lmz:Shooting:ScientificInterfaceStateMask', ...
        ['InterfaceStateMask must be scalar, one section-coordinate ' ...
        'vector, or coordinate-by-(N+1).']);
end
end

function value=localEventMask(configuration,eventCount)
source=fieldOr(configuration,'EventFreeMask',false(eventCount+1,1));
if ~(islogical(source)||(isnumeric(source)&&isreal(source)&& ...
        all(ismember(source(:),[0 1]))))
    error('lmz:Shooting:ScientificEventFreeMask', ...
        'EventFreeMask must be a logical mask.');
end
source=logical(source(:));
if isscalar(source)
    value=repmat(source,eventCount+1,1);
elseif numel(source)==2
    value=[repmat(source(1),eventCount,1);source(2)];
elseif numel(source)==eventCount+1
    value=source;
else
    error('lmz:Shooting:ScientificEventFreeMask', ...
        ['EventFreeMask must be scalar, [events return], or one value ' ...
        'for every interior event plus return time.']);
end
end

function value=localEnergyMode(configuration)
value=fieldOr(configuration,'EnergyWorkMode','diagnostic_only');
allowed={'energy_neutral','bounded_work','prescribed_work','diagnostic_only'};
if ~ischar(value)||~any(strcmp(value,allowed))
    error('lmz:Shooting:ScientificEnergyWorkMode', ...
        'EnergyWorkMode is invalid.');
end
end

function value=localDeclaredWork(configuration,count)
value=fieldOr(configuration,'DeclaredWork',0);
if ~isnumeric(value)||~isreal(value)||any(~isfinite(value(:)))|| ...
        ~(isscalar(value)||numel(value)==count)
    error('lmz:Shooting:ScientificDeclaredWork', ...
        'DeclaredWork must be scalar or contain one finite value per segment.');
end
if isscalar(value),value=repmat(value,count,1);else,value=value(:);end
end

function localValidateControlMask(configuration)
if ~isfield(configuration,'ControlFreeMask'),return,end
source=configuration.ControlFreeMask;
if ~(islogical(source)||(isnumeric(source)&&isreal(source)&& ...
        all(ismember(source(:),[0 1]))))
    error('lmz:Shooting:ScientificControlFreeMask', ...
        'ControlFreeMask must be a logical mask.');
end
if any(logical(source(:)))
    error('lmz:Shooting:ScientificControlDecisionsUnavailable', ...
        ['The quadruped and biped section adapters expose fixed controls ' ...
        'only; ControlFreeMask cannot select shooting decisions.']);
end
end

function value=localProfile(modelId)
switch modelId
    case 'slip_quadruped'
        value=struct('DefaultSectionId','back_left_touchdown', ...
            'FixedConfiguration',struct());
    case 'slip_biped'
        value=struct('DefaultSectionId','left_touchdown', ...
            'FixedConfiguration',struct('k_leg',20,'omega_swing',6.5));
    otherwise
        error('lmz:Shooting:ScientificMultipleShootingModel', ...
            'Scientific homogeneous multiple shooting is unavailable for %s.', ...
            modelId);
end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
