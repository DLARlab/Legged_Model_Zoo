classdef ContactTimingSequenceProblem < lmz.api.NonlinearEquationProblem
    %CONTACTTIMINGSEQUENCEPROBLEM Explicit schedules with fixed physics.
    properties (SetAccess=private)
        NumberOfStrides
        FixedInitialState
        FixedPhysicalParameters
        Evaluator
        ExpectedDimension
    end

    methods
        function obj=ContactTimingSequenceProblem(model,varargin)
            [decision,evaluator,state,parameters,configuration]= ...
                parseInputs(varargin{:});
            empty=emptySchema();
            obj@lmz.api.NonlinearEquationProblem(model, ...
                'contact_timing_sequence','nonlinear_equation',decision, ...
                empty,[],configuration);
            obj.NumberOfStrides=positiveInteger(configuration, ...
                'NumberOfStrides',1);
            obj.FixedInitialState=finiteVector(state,'fixed initial state');
            obj.FixedPhysicalParameters=finiteVector( ...
                parameters,'fixed physical parameters');
            obj.Evaluator=evaluator;
            obj.ExpectedDimension=nonnegativeInteger(configuration, ...
                'ExpectedLocalDimension',0);
        end

        function evaluation=evaluate(obj,u,p,context,includeSimulation) %#ok<INUSD>
            if nargin<5
                includeSimulation=false;
            end
            context.check();
            obj.DecisionSchema.validateVector(u);
            contract=struct('NumberOfStrides',obj.NumberOfStrides, ...
                'FixedInitialState',obj.FixedInitialState, ...
                'FixedPhysicalParameters',obj.FixedPhysicalParameters, ...
                'StatePeriodicityImposed',false,'HiddenTimingSolve',false);
            value=obj.Evaluator(u(:),obj.FixedInitialState, ...
                obj.FixedPhysicalParameters,context,includeSimulation,contract);
            [contacts,sections]=validateEvaluation(value,obj.NumberOfStrides);
            blocks=lmz.data.ResidualBlock.empty(0,1);
            for stride=1:obj.NumberOfStrides
                blocks(end+1,1)=lmz.data.ResidualBlock(sprintf( ...
                    'stride_%d_contact_constraints',stride), ...
                    contacts{stride},ones(numel(contacts{stride}),1)); %#ok<AGROW>
                blocks(end+1,1)=lmz.data.ResidualBlock(sprintf( ...
                    'stride_%d_section_return',stride),sections{stride}, ...
                    ones(numel(sections{stride}),1)); %#ok<AGROW>
            end
            residual=[vertcat(contacts{:});vertcat(sections{:})];
            feasibility=fieldOr(value,'Feasibility', ...
                struct('Valid',all(isfinite(residual))));
            simulation=[];
            if includeSimulation
                simulation=fieldOr(value,'Simulation',[]);
            end
            diagnostics=fieldOr(value,'Diagnostics',struct());
            diagnostics.NumberOfStrides=obj.NumberOfStrides;
            diagnostics.FixedInitialState=obj.FixedInitialState;
            diagnostics.FixedPhysicalParameters=obj.FixedPhysicalParameters;
            diagnostics.StatePeriodicityImposed=false;
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

function [decision,evaluator,state,parameters,configuration]=parseInputs(varargin)
if isscalar(varargin)&&isstruct(varargin{1})
    configuration=varargin{1};
    decision=requiredField(configuration,'DecisionSchema');
    evaluator=requiredField(configuration,'Evaluator');
    state=requiredField(configuration,'FixedInitialState');
    parameters=requiredField(configuration,'FixedPhysicalParameters');
elseif numel(varargin)==5
    decision=varargin{1};evaluator=varargin{2};state=varargin{3};
    parameters=varargin{4};configuration=varargin{5};
else
    error('lmz:MultiStride:TimingSequenceConstructor', ...
        'Use configuration-only or explicit timing-sequence construction.');
end
if ~isa(decision,'lmz.schema.VariableSchema')|| ...
        ~isa(evaluator,'function_handle')||~isstruct(configuration)
    error('lmz:MultiStride:TimingSequenceContract', ...
        'Timing-sequence schema, evaluator, or configuration is invalid.');
end
end

function [contacts,sections]=validateEvaluation(value,count)
if ~isstruct(value)||~isfield(value,'ContactResiduals')|| ...
        ~isfield(value,'SectionResiduals')|| ...
        ~iscell(value.ContactResiduals)||~iscell(value.SectionResiduals)|| ...
        numel(value.ContactResiduals)~=count|| ...
        numel(value.SectionResiduals)~=count
    error('lmz:MultiStride:TimingSequenceEvaluation', ...
        'Timing evaluator must return contact and section blocks per stride.');
end
if isfield(value,'Diagnostics')&&isfield(value.Diagnostics,'HiddenTimingSolve')&& ...
        logical(value.Diagnostics.HiddenTimingSolve)
    error('lmz:MultiStride:HiddenTimingSolve', ...
        'Timing-sequence residual evaluation cannot launch a nested solve.');
end
contacts=value.ContactResiduals(:);sections=value.SectionResiduals(:);
for index=1:count
    contacts{index}=realVector(contacts{index});
    sections{index}=realVector(sections{index});
end
end

function value=finiteVector(source,label)
value=realVector(source);
if any(~isfinite(value))
    error('lmz:MultiStride:FixedData','%s must be finite.',label);
end
end

function value=realVector(source)
if ~isnumeric(source)||~isreal(source)||~isvector(source)
    error('lmz:MultiStride:ResidualContract','Expected a real numeric vector.');
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
