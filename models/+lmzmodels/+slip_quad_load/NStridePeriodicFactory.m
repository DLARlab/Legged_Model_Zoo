classdef NStridePeriodicFactory
    %NSTRIDEPERIODICFACTORY Build a dimensioned scientific load problem.
    methods (Static)
        function problem = create(model, configuration)
            if nargin < 2
                configuration = struct();
            end
            if ~isstruct(configuration) || ~isscalar(configuration)
                error('lmz:QuadLoad:PeriodicConfiguration', ...
                    'N-stride periodic configuration must be scalar.');
            end
            [template, count, plan] = localTemplate(configuration);
            mode = localField(configuration, 'TimingMode', ...
                'explicit_variables');
            if ~strcmp(mode, 'explicit_variables')
                error('lmz:QuadLoad:PeriodicTimingMode', ...
                    ['Quad-load n_stride_periodic exposes all event times ' ...
                    'as explicit decision variables.']);
            end
            configuration.NumberOfStrides = count;
            configuration.TimingMode = 'explicit_variables';
            configuration.ExpectedLocalDimension = 1;
            if isempty(plan)
                startId = localField(configuration, ...
                    'StartSectionId', 'apex');
                stopId = localField(configuration, ...
                    'StopSectionId', startId);
                plan = lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan( ...
                    template, 'ProblemId', 'n_stride_periodic', ...
                    'StartSectionId', startId, ...
                    'StopSectionId', stopId);
            end
            configuration.StridePlan = plan;
            codec = lmzmodels.slip_quad_load.NStridePeriodicCodec(template);
            evaluator = lmzmodels.slip_quad_load.NStridePeriodicEvaluator( ...
                model, codec, configuration);
            callback = @(u, p, context, includeSimulation, contract) ...
                evaluator.evaluate(u, p, context, includeSimulation, contract);
            problem = lmz.multistride.NStridePeriodicProblem(model, ...
                codec.DecisionSchema, codec.ParameterSchema, ...
                codec.parameterDefaults(), callback, configuration);
        end
    end
end

function [template, count, plan] = localTemplate(configuration)
plan = localField(configuration, 'StridePlan', []);
if ~isempty(plan)
    if ~isa(plan, 'lmz.multistride.StridePlan')
        error('lmz:QuadLoad:PeriodicStridePlan', ...
            'StridePlan must implement the native stride-plan contract.');
    end
    count = localField(configuration, ...
        'NumberOfStrides', plan.RequestedStrideCount);
    if plan.CompletedStrideCount ~= count || ...
            plan.RequestedStrideCount ~= count
        error('lmz:QuadLoad:PeriodicStridePlan', ...
            'N-stride periodic evaluation requires a complete plan.');
    end
    template = lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(plan);
    return
end
template = localField(configuration, 'InitialDecision', []);
if ~isempty(template)
    template = lmzmodels.slip_quad_load.XAccumAdapter.encode(template);
    supplied = lmzmodels.slip_quad_load.XAccumAdapter.strideCount(template);
    count = localField(configuration, 'NumberOfStrides', supplied);
    localPositiveInteger(count);
    if supplied < count
        error('lmz:QuadLoad:PeriodicIncompleteDecision', ...
            ['InitialDecision does not contain every requested stride; ' ...
            'complete a StridePlan before creating this problem.']);
    elseif supplied > count
        [template, ~] = lmzmodels.slip_quad_load.XAccumPlanAdapter. ...
            truncate(template, count);
    end
    return
end
count = localField(configuration, 'NumberOfStrides', 1);
localPositiveInteger(count);
catalog = lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
if count == 1
    dataset = lmzmodels.slip_quad_load.XAccumAdapter.loadDataset( ...
        catalog.defaultSinglePath());
elseif count == 2
    dataset = lmzmodels.slip_quad_load.XAccumAdapter.loadDataset( ...
        catalog.defaultMultiPath());
else
    error('lmz:QuadLoad:PeriodicCompletePlanRequired', ...
        ['NumberOfStrides above two requires InitialDecision or a ' ...
        'complete StridePlan.']);
end
template = dataset.XAccum;
end

function localPositiveInteger(value)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 1 || value ~= fix(value)
    error('lmz:QuadLoad:PeriodicStrideCount', ...
        'NumberOfStrides must be a positive integer.');
end
end

function value = localField(source, name, fallback)
if isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end
