function [problem,horizon,schema,seed]=makeAnalyticShootingProblem(count,varargin)
%MAKEANALYTICSHOOTINGPROBLEM Deterministic affine shooting test fixture.
parser=inputParser;
addRequired(parser,'count',@(value)isnumeric(value)&&isscalar(value)&& ...
    value>=1&&value==fix(value));
addParameter(parser,'Formulation','periodic',@ischar);
addParameter(parser,'NodeValues',[],@isnumeric);
addParameter(parser,'FreeMasks',{},@iscell);
addParameter(parser,'Gains',0.5,@isnumeric);
addParameter(parser,'Offsets',1,@isnumeric);
addParameter(parser,'Target',2,@isnumeric);
addParameter(parser,'Configuration',struct(),@isstruct);
parse(parser,count,varargin{:});options=parser.Results;

nodeValues=options.NodeValues(:);
if isempty(nodeValues),nodeValues=2*ones(count+1,1);end
if numel(nodeValues)~=count+1||any(~isfinite(nodeValues))
    error('lmztest:ShootingNodeValues', ...
        'Analytic fixture needs one finite value per horizon node.');
end
freeMasks=options.FreeMasks;
if isempty(freeMasks),freeMasks=repmat({true},count+1,1);end
if numel(freeMasks)~=count+1
    error('lmztest:ShootingMasks', ...
        'Analytic fixture needs one free mask per horizon node.');
end
gains=expand(options.Gains,count,'Gains');
offsets=expand(options.Offsets,count,'Offsets');

physicalSchema=lmz.schema.VariableSchema( ...
    lmz.schema.VariableSpec('x','Label','section state', ...
    'DefaultValue',2,'Scale',1),'1.0.0');
stateSchema=lmz.shooting.SectionStateSchema(physicalSchema,{'x'});
nodes=cell(count+1,1);
for index=1:numel(nodes)
    nodes{index}=lmz.shooting.ShootingNode('SectionId','analytic', ...
        'StateSide','post','StateSchema',stateSchema, ...
        'FullState',nodeValues(index), ...
        'FreeCoordinateMask',logical(freeMasks{index}), ...
        'Lineage',struct('Fixture','analytic-affine-v1'));
end
segments=cell(count,1);
energy=struct('Mode','diagnostic_only','DeclaredWork',0, ...
    'Tolerance',1e-10);
for index=1:count
    segments{index}=lmz.shooting.ShootingSegment('Index',index, ...
        'StartNode',nodes{index},'StopNode',nodes{index+1}, ...
        'ControlParameters',struct('Gain',gains(index), ...
        'Offset',offsets(index)), ...
        'EnergyWorkSpecification',energy, ...
        'SourceLineage',struct('Fixture','analytic-affine-v1'));
end
target=struct();
if strcmp(options.Formulation,'transition')
    target=struct('SectionCoordinates',options.Target(:));
end
horizon=lmz.shooting.ShootingHorizon('ModelId','tutorial_hopper', ...
    'ProblemId','periodic_orbit','Nodes',nodes,'Segments',segments, ...
    'Formulation',options.Formulation,'Target',target, ...
    'Lineage',struct('Fixture','analytic-affine-v1'));
schema=lmz.shooting.ShootingDecisionSchema.fromHorizon(horizon);
seed=schema.defaults();
configuration=options.Configuration;
configuration.ProblemId='periodic_orbit';
if ~isfield(configuration,'ResidualTolerance')
    configuration.ResidualTolerance=1e-9;
end
parameterSchema=lmz.schema.VariableSchema( ...
    lmz.schema.VariableSpec.empty(0,1),'1.0.0');
model=lmzmodels.tutorial_hopper.Model();
adapter=lmztest.AnalyticShootingAdapter();
switch options.Formulation
    case 'periodic'
        problem=lmz.shooting.PeriodicMultipleShootingProblem(model, ...
            schema,parameterSchema,[],horizon,adapter,configuration);
    case 'transition'
        problem=lmz.shooting.TransitionMultipleShootingProblem(model, ...
            schema,parameterSchema,[],horizon,adapter,configuration);
    case 'feasibility'
        configuration.Formulation='feasibility';
        problem=lmz.shooting.MultipleShootingProblem(model, ...
            'periodic_orbit',schema,parameterSchema,[],horizon,adapter, ...
            configuration);
    otherwise
        error('lmztest:ShootingFormulation','Unknown analytic formulation.');
end
end

function value=expand(source,count,label)
if isscalar(source),source=repmat(source,count,1);end
value=source(:);
if numel(value)~=count||any(~isfinite(value))
    error('lmztest:ShootingMap','%s must define every segment.',label);
end
end
