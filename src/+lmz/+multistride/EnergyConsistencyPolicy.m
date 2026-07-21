classdef EnergyConsistencyPolicy
    %ENERGYCONSISTENCYPOLICY Explicit energy/work acceptance contract.
    properties (SetAccess=private)
        Id
        Tolerance
    end

    methods
        function obj=EnergyConsistencyPolicy(varargin)
            parser=inputParser;
            addParameter(parser,'Id','energy_neutral_only',@isTextScalar);
            addParameter(parser,'Tolerance',1e-10,@isPositiveScalar);
            parse(parser,varargin{:});values=parser.Results;id=char(values.Id);
            allowed={'energy_neutral_only','declared_work','allow_non_neutral'};
            if ~any(strcmp(id,allowed))
                error('lmz:MultiStride:EnergyPolicy','Unknown energy policy %s.',id);
            end
            obj.Id=id;obj.Tolerance=values.Tolerance;
        end

        function diagnostics=assess(obj,energyDelta,declaredWork,effectKnown)
            if nargin<3||isempty(declaredWork),declaredWork=0;end
            if nargin<4,effectKnown=true;end
            validateScalar(energyDelta,'energy delta');
            declaredWork=obj.declaredExternalWork(declaredWork);
            if ~effectKnown
                error('lmz:MultiStride:UnknownEnergyEffect', ...
                    'The parameter transition has an unknown energy effect.');
            end
            mismatch=energyDelta-declaredWork;
            accepted=strcmp(obj.Id,'allow_non_neutral')||abs(mismatch)<=obj.Tolerance;
            if ~accepted
                error('lmz:MultiStride:EnergyTransition', ...
                    ['Parameter transition energy %.17g differs from declared ' ...
                    'work %.17g by %.17g.'],energyDelta,declaredWork,mismatch);
            end
            diagnostics=struct('Policy',obj.Id,'EnergyDelta',energyDelta, ...
                'DeclaredWork',declaredWork,'Mismatch',mismatch, ...
                'Tolerance',obj.Tolerance,'EffectKnown',logical(effectKnown), ...
                'Accepted',true);
        end

        function value=declaredExternalWork(~,transitionSpec)
            if nargin<2||isempty(transitionSpec)
                value=0;return
            end
            if isnumeric(transitionSpec)
                value=transitionSpec;
            elseif isstruct(transitionSpec)&&isscalar(transitionSpec)&& ...
                    isfield(transitionSpec,'DeclaredExternalWork')
                value=transitionSpec.DeclaredExternalWork;
            elseif isstruct(transitionSpec)&&isscalar(transitionSpec)&& ...
                    isfield(transitionSpec,'DeclaredWork')
                value=transitionSpec.DeclaredWork;
            else
                error('lmz:MultiStride:DeclaredExternalWork', ...
                    ['Transition specification must provide finite scalar ' ...
                    'DeclaredExternalWork or DeclaredWork.']);
            end
            validateScalar(value,'declared external work');
        end

        function value=toStruct(obj)
            value=struct('Id',obj.Id,'Tolerance',obj.Tolerance);
        end
    end

    methods (Static)
        function obj=from(value)
            if isa(value,'lmz.multistride.EnergyConsistencyPolicy')
                obj=value;
            elseif isstruct(value)
                obj=lmz.multistride.EnergyConsistencyPolicy( ...
                    'Id',value.Id,'Tolerance',value.Tolerance);
            else
                obj=lmz.multistride.EnergyConsistencyPolicy('Id',value);
            end
        end
    end
end

function value=isTextScalar(source)
value=ischar(source)||(isstring(source)&&isscalar(source));
end
function value=isPositiveScalar(source)
value=isnumeric(source)&&isreal(source)&&isscalar(source)&&isfinite(source)&&source>0;
end
function validateScalar(value,label)
if ~isnumeric(value)||~isreal(value)||~isscalar(value)||~isfinite(value)
    error('lmz:MultiStride:EnergyValue','The %s must be finite and real.',label);
end
end
