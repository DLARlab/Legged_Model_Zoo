classdef MultiStrideRequest
    %MULTISTRIDEREQUEST Explicit requested count and completion configuration.
    properties (SetAccess=private)
        NumberOfStrides
        InitialDecision
        StridePlan
        CompletionPolicy
        EnergyPolicy
        EnergyNeutralOnly
        FailurePolicy
        StartSectionId
        StopSectionId
        ProviderCallback
        ParameterOverrides
        DeclaredWork
        MaximumStrides
        Provenance
    end

    methods
        function obj=MultiStrideRequest(varargin)
            parser=inputParser;
            addParameter(parser,'NumberOfStrides',1,@isPositiveInteger);
            addParameter(parser,'InitialDecision',zeros(0,1),@isFiniteNumeric);
            addParameter(parser,'StridePlan',[],@isPlanOrEmpty);
            addParameter(parser,'CompletionPolicy','error_if_missing');
            addParameter(parser,'EnergyPolicy', ...
                lmz.multistride.EnergyConsistencyPolicy());
            addParameter(parser,'EnergyNeutralOnly',true,@isLogicalScalar);
            addParameter(parser,'FailurePolicy','return_partial',@isFailurePolicy);
            addParameter(parser,'StartSectionId','apex',@isIdentifier);
            addParameter(parser,'StopSectionId','apex',@isIdentifier);
            addParameter(parser,'ProviderCallback',[],@isCallback);
            addParameter(parser,'ParameterOverrides',struct(),@isOverrideData);
            addParameter(parser,'DeclaredWork',0,@isFiniteNumeric);
            addParameter(parser,'MaximumStrides',100,@isPositiveInteger);
            addParameter(parser,'Provenance',struct(),@isstruct);
            parse(parser,varargin{:});values=parser.Results;
            if values.NumberOfStrides>values.MaximumStrides
                error('lmz:MultiStride:SafetyLimit', ...
                    'Requested stride count exceeds the configured safety limit.');
            end
            if ~isempty(values.InitialDecision)&&~isempty(values.StridePlan)
                error('lmz:MultiStride:AmbiguousInput', ...
                    'Specify InitialDecision or StridePlan, not both.');
            end
            obj.NumberOfStrides=values.NumberOfStrides;
            obj.InitialDecision=values.InitialDecision(:);
            obj.StridePlan=values.StridePlan;
            obj.CompletionPolicy=lmz.multistride.MissingStridePolicy.from( ...
                values.CompletionPolicy);
            obj.EnergyPolicy=lmz.multistride.EnergyConsistencyPolicy.from( ...
                values.EnergyPolicy);
            obj.EnergyNeutralOnly=logical(values.EnergyNeutralOnly);
            if obj.EnergyNeutralOnly&&strcmp(obj.EnergyPolicy.Id,'allow_non_neutral')
                error('lmz:MultiStride:EnergyPolicyConflict', ...
                    'EnergyNeutralOnly conflicts with allow_non_neutral.');
            end
            obj.FailurePolicy=char(values.FailurePolicy);
            obj.StartSectionId=char(values.StartSectionId);
            obj.StopSectionId=char(values.StopSectionId);
            obj.ProviderCallback=values.ProviderCallback;
            obj.ParameterOverrides=values.ParameterOverrides;
            obj.DeclaredWork=values.DeclaredWork;
            obj.MaximumStrides=values.MaximumStrides;
            obj.Provenance=values.Provenance;
        end

        function value=toStruct(obj)
            plan=[];if ~isempty(obj.StridePlan),plan=obj.StridePlan.toStruct();end
            value=struct('NumberOfStrides',obj.NumberOfStrides, ...
                'InitialDecision',obj.InitialDecision,'StridePlan',plan, ...
                'CompletionPolicy',obj.CompletionPolicy.toStruct(), ...
                'EnergyPolicy',obj.EnergyPolicy.toStruct(), ...
                'EnergyNeutralOnly',obj.EnergyNeutralOnly, ...
                'FailurePolicy',obj.FailurePolicy, ...
                'StartSectionId',obj.StartSectionId, ...
                'StopSectionId',obj.StopSectionId, ...
                'ProviderCallbackConfigured',~isempty(obj.ProviderCallback), ...
                'ParameterOverrides',obj.ParameterOverrides, ...
                'DeclaredWork',obj.DeclaredWork, ...
                'MaximumStrides',obj.MaximumStrides,'Provenance',obj.Provenance);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            required={'NumberOfStrides','InitialDecision','StridePlan', ...
                'CompletionPolicy','EnergyPolicy','EnergyNeutralOnly', ...
                'FailurePolicy','StartSectionId','StopSectionId', ...
                'ProviderCallbackConfigured','ParameterOverrides', ...
                'DeclaredWork','MaximumStrides','Provenance'};
            if ~isstruct(value)||~isscalar(value)|| ...
                    ~all(isfield(value,required))
                error('lmz:MultiStride:StoredRequest', ...
                    'Stored multi-stride request is incomplete.');
            end
            if logical(value.ProviderCallbackConfigured)
                error('lmz:MultiStride:ExecutableRequest', ...
                    ['Provider callbacks are intentionally not deserialized; ' ...
                    'supply a new trusted callback explicitly.']);
            end
            plan=[];
            if ~isempty(value.StridePlan)
                plan=lmz.multistride.StridePlan.fromStruct(value.StridePlan);
            end
            pairs={'NumberOfStrides',value.NumberOfStrides, ...
                'CompletionPolicy',value.CompletionPolicy, ...
                'EnergyPolicy',value.EnergyPolicy, ...
                'EnergyNeutralOnly',logical(value.EnergyNeutralOnly), ...
                'FailurePolicy',value.FailurePolicy, ...
                'StartSectionId',value.StartSectionId, ...
                'StopSectionId',value.StopSectionId, ...
                'ParameterOverrides',value.ParameterOverrides, ...
                'DeclaredWork',value.DeclaredWork, ...
                'MaximumStrides',value.MaximumStrides, ...
                'Provenance',value.Provenance};
            if isempty(plan)
                pairs=[pairs {'InitialDecision',value.InitialDecision}];
            else
                pairs=[pairs {'StridePlan',plan}];
            end
            obj=lmz.multistride.MultiStrideRequest(pairs{:});
        end
    end
end

function value=isPositiveInteger(source)
value=isnumeric(source)&&isreal(source)&&isscalar(source)&&isfinite(source)&& ...
    source>=1&&source==fix(source);
end
function value=isFiniteNumeric(source)
value=isnumeric(source)&&isreal(source)&&all(isfinite(source(:)));
end
function value=isPlanOrEmpty(source)
value=isempty(source)||(isa(source,'lmz.multistride.StridePlan')&&isscalar(source));
end
function value=isLogicalScalar(source)
value=(islogical(source)||isnumeric(source))&&isscalar(source)&&isfinite(source)&& ...
    (source==0||source==1);
end
function value=isFailurePolicy(source)
value=(ischar(source)||(isstring(source)&&isscalar(source)))&& ...
    any(strcmp(char(source),{'return_partial','error'}));
end
function value=isIdentifier(source)
value=(ischar(source)||(isstring(source)&&isscalar(source)))&& ...
    ~isempty(regexp(char(source),'^[A-Za-z][A-Za-z0-9_]*$','once'));
end
function value=isCallback(source)
value=isempty(source)||isa(source,'function_handle');
end
function value=isOverrideData(source)
value=isstruct(source)||iscell(source);
end
