classdef MultipleShootingProblem < lmz.api.NonlinearEquationProblem
    %MULTIPLESHOOTINGPROBLEM Explicit segment, defect, and final residuals.
    properties (SetAccess=private)
        ShootingSchema
        Horizon
        Evaluator
        Formulation
        ExpectedDimension
    end
    methods
        function obj=MultipleShootingProblem(model,id,shootingSchema, ...
                parameterSchema,defaultParameters,horizon,segmentEvaluator, ...
                configuration)
            if nargin<8,configuration=struct();end
            if ~isa(shootingSchema,'lmz.shooting.ShootingDecisionSchema')|| ...
                    ~isa(parameterSchema,'lmz.schema.VariableSchema')|| ...
                    ~isa(horizon,'lmz.shooting.ShootingHorizon')
                error('lmz:Shooting:ProblemContract', ...
                    'Multiple-shooting schemas or horizon are invalid.');
            end
            formulation=fieldOr(configuration,'Formulation',horizon.Formulation);
            stored=configuration;stored.Formulation=formulation;
            obj@lmz.api.NonlinearEquationProblem(model,id, ...
                'nonlinear_equation',shootingSchema.VariableSchema, ...
                parameterSchema,defaultParameters,stored);
            obj.Version='1.0.0';obj.ShootingSchema=shootingSchema;
            obj.Horizon=horizon;
            obj.Evaluator=lmz.shooting.MultipleShootingEvaluator(segmentEvaluator);
            obj.Formulation=formulation;
            obj.ExpectedDimension=fieldOr(configuration,'ExpectedLocalDimension',0);
            if ~isnumeric(obj.ExpectedDimension)||~isscalar(obj.ExpectedDimension)|| ...
                    obj.ExpectedDimension<0||obj.ExpectedDimension~=fix(obj.ExpectedDimension)
                error('lmz:Shooting:ExpectedDimension', ...
                    'ExpectedLocalDimension must be a nonnegative integer.');
            end
        end

        function evaluation=evaluate(obj,u,p,context,includeSimulation)
            if nargin<5,includeSimulation=false;end
            obj.DecisionSchema.validateVector(u);
            obj.ParameterSchema.validateVector(p);
            residual=obj.evaluateShooting(u,p,context,includeSimulation);
            evaluation=residual.toEvaluation(includeSimulation);
        end

        function residual=evaluateShooting(obj,u,p,context,includeSimulation)
            if nargin<5,includeSimulation=false;end
            obj.DecisionSchema.validateVector(u);
            obj.ParameterSchema.validateVector(p);
            residual=obj.Evaluator.evaluate(obj.Horizon,obj.ShootingSchema, ...
                u,p,context,includeSimulation,obj.Formulation,obj.Configuration);
        end

        function value=expectedLocalDimension(obj),value=obj.ExpectedDimension;end
        function value=decodeShootingDecision(obj,u)
            value=obj.ShootingSchema.decode(u,obj.Horizon);
        end
        function value=contract(obj)
            manifest=obj.Model.getManifest();
            evaluator=obj.Evaluator.SegmentEvaluator;
            if isa(evaluator,'function_handle')
                evaluatorRecord=struct('Kind','callback', ...
                    'Class','function_handle','Reproducible',false);
            else
                evaluatorRecord=evaluator.toStruct();
                evaluatorRecord.Kind='section_simulation_adapter';
                evaluatorRecord.Reproducible=true;
            end
            value=struct('SchemaVersion','1.0.0', ...
                'ModelId',manifest.id,'ProblemId',obj.Id, ...
                'ProblemVersion',obj.Version, ...
                'Formulation',obj.Formulation, ...
                'SegmentCount',obj.Horizon.segmentCount(), ...
                'NodeCount',obj.Horizon.nodeCount(), ...
                'ExpectedLocalDimension',obj.ExpectedDimension, ...
                'DecisionSchema',obj.ShootingSchema.toStruct(), ...
                'ParameterSchema',obj.ParameterSchema.toStruct(), ...
                'DefaultParameters',obj.DefaultParameters, ...
                'SegmentEvaluator',evaluatorRecord, ...
                'Configuration',plainContract(obj.Configuration), ...
                'Horizon',obj.Horizon.toStruct());
        end
    end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end

function value=plainContract(source)
if isa(source,'function_handle')
    error('lmz:Shooting:ExecutableProblemContract', ...
        'Shooting problem contracts cannot contain function handles.');
elseif isobject(source)
    if ~ismethod(source,'toStruct')
        error('lmz:Shooting:ExecutableProblemContract', ...
            'Shooting problem contracts require plain serializable data.');
    end
    value=plainContract(source.toStruct());
elseif isstruct(source)
    value=source;names=fieldnames(source);
    for item=1:numel(source)
        for index=1:numel(names)
            value(item).(names{index})=plainContract( ...
                source(item).(names{index}));
        end
    end
elseif iscell(source)
    value=cell(size(source));
    for index=1:numel(source),value{index}=plainContract(source{index});end
else
    value=source;
end
end
