classdef ContactTimingSequenceFactory
    %CONTACTTIMINGSEQUENCEFACTORY Repeat a model timing chart over N strides.
    methods (Static)
        function problem=create(model,configuration)
            if nargin<2,configuration=struct();end
            if ~isa(model,'lmz.api.LeggedModel')||~isstruct(configuration)|| ...
                    ~isscalar(configuration)
                error('lmz:MultiStride:TimingSequenceConfiguration', ...
                    'Timing-sequence creation requires a model and scalar configuration.');
            end
            count=fieldOr(configuration,'NumberOfStrides',1);
            validateCount(count);
            localConfiguration=configuration;
            if isfield(localConfiguration,'NumberOfStrides')
                localConfiguration=rmfield(localConfiguration,'NumberOfStrides');
            end
            if isfield(localConfiguration,'StrideCount')
                localConfiguration=rmfield(localConfiguration,'StrideCount');
            end
            localProblem=model.createProblem( ...
                'section_return_timing',localConfiguration);
            if ~isa(localProblem,'lmz.schedule.SectionReturnTimingProblem')
                error('lmz:MultiStride:TimingSequenceProvider', ...
                    ['The model section_return_timing problem must implement ' ...
                    'SectionReturnTimingProblem.']);
            end
            localSchema=localProblem.getDecisionSchema();
            decision=repeatSchema(localSchema,count);
            evaluator=lmz.multistride.ContactTimingSequenceEvaluator( ...
                localProblem.Provider,localProblem.ScheduleChart,count);
            configuration.NumberOfStrides=count;
            configuration.DecisionSchema=decision;
            configuration.Evaluator=@evaluator.evaluate;
            configuration.FixedInitialState=localProblem.FixedInitialState;
            configuration.FixedPhysicalParameters= ...
                localProblem.FixedPhysicalParameters;
            configuration.ExpectedLocalDimension=0;
            configuration.SequenceConstruction=struct( ...
                'SourceProblemId','section_return_timing', ...
                'LocalUnknownCount',localSchema.count(), ...
                'ScheduleReuse','same_chart_per_stride', ...
                'StatePropagation','previous_terminal_state', ...
                'PhysicalParametersFixed',true, ...
                'StatePeriodicityImposed',false, ...
                'HiddenTimingSolve',false);
            problem=lmz.multistride.ContactTimingSequenceProblem( ...
                model,configuration);
        end
    end
end

function value=repeatSchema(local,count)
specs=lmz.schema.VariableSpec.empty(0,1);
cursor=0;
for stride=1:count
    prefix=sprintf('stride_%d_',stride);
    for index=1:local.count()
        data=local.Specs(index).toStruct();
        data.Name=[prefix data.Name];
        data.Label=sprintf('Stride %d: %s',stride,data.Label);
        data.LatexLabel=sprintf('%s_{%d}',data.LatexLabel,stride);
        data.Group=sprintf('stride_%d_event_schedule',stride);
        if ~isempty(data.PeriodSource)
            data.PeriodSource=[prefix data.PeriodSource];
        end
        cursor=cursor+1;
        specs(cursor,1)=lmz.schema.VariableSpec.fromStruct(data);
    end
end
value=lmz.schema.VariableSchema(specs,local.Version);
end

function validateCount(value)
if ~isnumeric(value)||~isreal(value)||~isscalar(value)|| ...
        ~isfinite(value)||value<1||value~=fix(value)
    error('lmz:MultiStride:StrideCount', ...
        'NumberOfStrides must be a positive integer.');
end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
