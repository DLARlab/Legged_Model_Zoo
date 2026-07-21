classdef ShootingInitializer
    %SHOOTINGINITIALIZER Ordered, recorded shooting initialization strategy.
    methods
        function [candidates,history]=initialize(~,shootingSchema,templates,options)
            if nargin<4,options=struct();end
            if ~isa(shootingSchema,'lmz.shooting.ShootingDecisionSchema')
                error('lmz:Shooting:InitializerSchema', ...
                    'ShootingInitializer requires a ShootingDecisionSchema.');
            end
            if isempty(templates),templates={};elseif isstruct(templates),templates=num2cell(templates);end
            if ~iscell(templates)
                error('lmz:Shooting:InitializerTemplates','Templates must be a cell array.');
            end
            defaults=shootingSchema.defaults();candidates={};history={};
            labels={'exact_source_horizon','nearest_compatible_template', ...
                'phase_compatible_repeat','section_state_interpolation', ...
                'schema_scaled_secant'};
            for index=1:numel(labels)
                [candidate,source,score]=candidateFor(labels{index},templates, ...
                    defaults,shootingSchema,options);
                accepted=~isempty(candidate);
                history{end+1,1}=struct('Strategy',labels{index}, ...
                    'Accepted',accepted,'Source',source,'Score',score); %#ok<AGROW>
                if accepted,candidates{end+1,1}=candidate(:);end %#ok<AGROW>
            end
            count=fieldOr(options,'MultistartCount',0);
            scale=fieldOr(options,'MultistartScale',0.01);
            seed=fieldOr(options,'RandomSeed',0);
            if ~isnumeric(count)||~isscalar(count)||~isfinite(count)|| ...
                    count<0||count~=fix(count)
                error('lmz:Shooting:InitializerMultistartCount', ...
                    'MultistartCount must be a nonnegative integer.');
            end
            if ~isnumeric(scale)||~isscalar(scale)||~isfinite(scale)||scale<0
                error('lmz:Shooting:InitializerMultistartScale', ...
                    'MultistartScale must be finite and nonnegative.');
            end
            if ~isnumeric(seed)||~isscalar(seed)||~isfinite(seed)|| ...
                    seed<0||seed~=fix(seed)
                error('lmz:Shooting:InitializerRandomSeed', ...
                    'RandomSeed must be a nonnegative integer.');
            end
            if count>0
                stream=RandStream('mt19937ar','Seed',seed);
                variableScale=arrayfun(@(item)item.Scale, ...
                    shootingSchema.VariableSchema.Specs(:));
                base=defaults;
                if ~isempty(candidates),base=candidates{1};end
                for index=1:count
                    candidate=base+scale*variableScale.*randn(stream,numel(base),1);
                    candidate=clip(candidate,shootingSchema.VariableSchema);
                    candidates{end+1,1}=candidate; %#ok<AGROW>
                    history{end+1,1}=struct('Strategy','reproducible_multistart', ...
                        'Accepted',true,'Source',index,'Score',NaN, ...
                        'RandomSeed',seed); %#ok<AGROW>
                end
            end
            if isempty(candidates)
                candidates={defaults};
                history{end+1,1}=struct('Strategy','schema_defaults', ...
                    'Accepted',true,'Source','decision-schema','Score',0);
            end
        end
    end
end

function [candidate,source,score]=candidateFor(label,templates,defaults,schema,options)
candidate=[];source='';score=Inf;
for index=1:numel(templates)
    item=templates{index};
    if ~isstruct(item)||~isscalar(item),continue,end
    proposed=initializerCandidate(label,item,schema,options);
    if isempty(proposed),continue,end
    itemScore=templateScore(item,proposed,defaults,schema,options);
    if itemScore<score
        candidate=proposed(:);source=fieldOr(item,'Id',index);score=itemScore;
    end
end
end

function value=initializerCandidate(label,item,schema,options)
value=[];
switch label
    case 'exact_source_horizon'
        if fieldOr(item,'ExactHorizon',false)&&isfield(item,'Decision')
            value=item.Decision;
        end
    case 'nearest_compatible_template'
        if fieldOr(item,'Compatible',false)&&isfield(item,'Decision')
            value=item.Decision;
        end
    case 'phase_compatible_repeat'
        if fieldOr(item,'PhaseCompatible',false)
            value=fieldOr(item,'RepeatedDecision', ...
                fieldOr(item,'Decision',[]));
        end
    case 'section_state_interpolation'
        value=fieldOr(item,'InterpolatedDecision',[]);
    case 'schema_scaled_secant'
        value=fieldOr(item,'SecantDecision',[]);
        if isempty(value)&&isfield(item,'DecisionPair')&& ...
                isnumeric(item.DecisionPair)&& ...
                isequal(size(item.DecisionPair),[schema.count() 2])
            factor=fieldOr(options,'SecantFactor',1);
            value=item.DecisionPair(:,2)+factor*( ...
                item.DecisionPair(:,2)-item.DecisionPair(:,1));
        end
end
if ~isnumeric(value)||~isreal(value)||numel(value)~=schema.count()|| ...
        any(~isfinite(value(:)))
    value=[];return
end
value=clip(value,schema.VariableSchema);
end

function value=templateScore(item,candidate,defaults,schema,options)
scale=arrayfun(@(spec)spec.Scale,schema.VariableSchema.Specs(:));
weights=fieldOr(options,'TemplateWeights',ones(numel(defaults),1));
if isscalar(weights),weights=repmat(weights,numel(defaults),1);end
if numel(weights)~=numel(defaults)||any(~isfinite(weights(:)))
    error('lmz:Shooting:InitializerWeights', ...
        'TemplateWeights must cover every decision variable.');
end
value=norm(weights(:).*(candidate(:)-defaults)./scale);
if isfield(item,'ContactResidualNorm'),value=value+item.ContactResidualNorm;end
end
function value=clip(source,schema)
value=source(:);
for index=1:schema.count()
    value(index)=min(schema.Specs(index).UpperBound, ...
        max(schema.Specs(index).LowerBound,value(index)));
end
value=lmz.schema.VariableChart(schema).canonicalize(value);
end
function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
