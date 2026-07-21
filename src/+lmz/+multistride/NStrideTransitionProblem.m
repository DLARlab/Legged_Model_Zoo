classdef NStrideTransitionProblem < lmz.api.NonlinearEquationProblem
    %NSTRIDETRANSITIONPROBLEM Explicit N-stride endpoint transition form.
    properties (SetAccess=private)
        NumberOfStrides
        TimingMode
        StridePlan
        Evaluator
        ExpectedDimension
    end

    methods
        function obj=NStrideTransitionProblem(model,varargin)
            [decision,parameters,defaults,evaluator,configuration]= ...
                parseInputs(varargin{:});
            obj@lmz.api.NonlinearEquationProblem(model,'n_stride_transition', ...
                'nonlinear_equation',decision,parameters,defaults,configuration);
            obj.NumberOfStrides=positiveInteger(configuration, ...
                'NumberOfStrides',1);
            obj.TimingMode=char(fieldOr(configuration,'TimingMode', ...
                'fixed_precompleted'));
            obj.StridePlan=fieldOr(configuration,'StridePlan',[]);
            obj.Evaluator=evaluator;
            obj.ExpectedDimension=nonnegativeInteger(configuration, ...
                'ExpectedLocalDimension',0);
            validateConfiguration(obj,configuration);
        end

        function evaluation=evaluate(obj,u,p,context,includeSimulation)
            if nargin<5
                includeSimulation=false;
            end
            context.check();
            obj.DecisionSchema.validateVector(u);
            obj.ParameterSchema.validateVector(p);
            contract=struct('NumberOfStrides',obj.NumberOfStrides, ...
                'StridePlan',obj.StridePlan,'TimingMode',obj.TimingMode, ...
                'IntermediatePeriodicityImposed',false, ...
                'HiddenTimingSolve',false);
            value=obj.Evaluator(u(:),p(:),context,includeSimulation,contract);
            [contacts,target]=validateEvaluation(value,obj.NumberOfStrides);
            blocks=lmz.data.ResidualBlock.empty(0,1);
            for stride=1:obj.NumberOfStrides
                name=sprintf('stride_%d_contact_constraints',stride);
                blocks(end+1,1)=lmz.data.ResidualBlock(name, ...
                    contacts{stride},ones(numel(contacts{stride}),1)); %#ok<AGROW>
            end
            blocks(end+1,1)=lmz.data.ResidualBlock( ...
                'final_target_constraint',target,ones(numel(target),1));
            feasibility=fieldOr(value,'Feasibility', ...
                struct('Valid',all(isfinite([vertcat(contacts{:});target]))));
            simulation=[];
            if includeSimulation
                simulation=fieldOr(value,'Simulation',[]);
            end
            diagnostics=fieldOr(value,'Diagnostics',struct());
            diagnostics.NumberOfStrides=obj.NumberOfStrides;
            diagnostics.IntermediatePeriodicityImposed=false;
            diagnostics.HiddenTimingSolve=false;
            evaluation=lmz.data.ProblemEvaluation(blocks, ...
                'Simulation',simulation,'Feasibility',feasibility, ...
                'PhysicalValidity',fieldOr(value,'PhysicalValidity', ...
                feasibility.Valid),'Diagnostics',diagnostics);
        end

        function value=expectedLocalDimension(obj)
            value=obj.ExpectedDimension;
        end
    end
end

function [decision,parameters,defaults,evaluator,configuration]=parseInputs(varargin)
if isscalar(varargin)&&isstruct(varargin{1})
    configuration=varargin{1};
    decision=requiredField(configuration,'DecisionSchema');
    evaluator=requiredField(configuration,'Evaluator');
    parameters=fieldOr(configuration,'ParameterSchema',emptySchema());
    defaults=fieldOr(configuration,'DefaultParameters',parameters.defaults());
elseif numel(varargin)==5
    decision=varargin{1};parameters=varargin{2};defaults=varargin{3};
    evaluator=varargin{4};configuration=varargin{5};
else
    error('lmz:MultiStride:TransitionConstructor', ...
        'Use configuration-only or explicit schema/evaluator construction.');
end
if ~isa(decision,'lmz.schema.VariableSchema')|| ...
        ~isa(parameters,'lmz.schema.VariableSchema')|| ...
        ~isa(evaluator,'function_handle')||~isstruct(configuration)
    error('lmz:MultiStride:TransitionContract', ...
        'Transition schemas, evaluator, or configuration are invalid.');
end
parameters.validateVector(defaults);defaults=defaults(:);
end

function validateConfiguration(obj,configuration)
if ~any(strcmp(obj.TimingMode,{'explicit_variables','fixed_precompleted'}))
    error('lmz:MultiStride:TimingMode', ...
        'Unsupported timing mode %s.',obj.TimingMode);
end
if strcmp(obj.TimingMode,'explicit_variables')
    return
end
evidence=isfield(configuration,'TimingDataPrecompleted')&& ...
    isequal(configuration.TimingDataPrecompleted,true);
if isa(obj.StridePlan,'lmz.multistride.StridePlan')
    evidence=obj.StridePlan.CompletedStrideCount==obj.NumberOfStrides&& ...
        obj.StridePlan.RequestedStrideCount==obj.NumberOfStrides;
end
if ~evidence
    error('lmz:MultiStride:TimingEvidence', ...
        'A transition problem with fixed timings requires completion evidence.');
end
end

function [contacts,target]=validateEvaluation(value,count)
if ~isstruct(value)||~isfield(value,'ContactResiduals')|| ...
        ~isfield(value,'FinalTargetResidual')||~iscell(value.ContactResiduals)|| ...
        numel(value.ContactResiduals)~=count
    error('lmz:MultiStride:TransitionEvaluation', ...
        'Transition evaluator must return one contact block per stride.');
end
if isfield(value,'Diagnostics')&&isfield(value.Diagnostics,'HiddenTimingSolve')&& ...
        logical(value.Diagnostics.HiddenTimingSolve)
    error('lmz:MultiStride:HiddenTimingSolve', ...
        'Transition evaluation cannot launch a hidden timing solve.');
end
contacts=value.ContactResiduals(:);
for index=1:count
    contacts{index}=realVector(contacts{index});
end
target=realVector(value.FinalTargetResidual);
end

function value=realVector(source)
if ~isnumeric(source)||~isreal(source)||~isvector(source)
    error('lmz:MultiStride:ResidualContract', ...
        'Transition residuals must be real vectors.');
end
value=source(:);
end

function value=positiveInteger(source,name,fallback)
value=fieldOr(source,name,fallback);
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)|| ...
        value<1||value~=fix(value)
    error('lmz:MultiStride:PositiveInteger','%s must be a positive integer.',name);
end
end

function value=nonnegativeInteger(source,name,fallback)
value=fieldOr(source,name,fallback);
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)|| ...
        value<0||value~=fix(value)
    error('lmz:MultiStride:NonnegativeInteger', ...
        '%s must be a nonnegative integer.',name);
end
end

function value=requiredField(source,name)
if ~isfield(source,name)
    error('lmz:MultiStride:MissingConfiguration','Missing configuration %s.',name);
end
value=source.(name);
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name)
    value=source.(name);
else
    value=fallback;
end
end

function value=emptySchema()
value=lmz.schema.VariableSchema(lmz.schema.VariableSpec.empty(0,1),'1.0.0');
end
