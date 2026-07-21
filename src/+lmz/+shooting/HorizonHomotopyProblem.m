classdef HorizonHomotopyProblem < lmz.api.NonlinearEquationProblem
    %HORIZONHOMOTOPYPROBLEM Blend an embedded anchor into a full horizon.
    %   At lambda=0 the embedded decision is an exact anchored root. At
    %   lambda=1 the residual is exactly the wrapped multiple-shooting
    %   residual. Intermediate results are never classified as physical
    %   horizon solutions.
    properties (SetAccess=private)
        BaseProblem
        AnchorDecision
        Lambda
        ResidualDimension
    end

    methods
        function obj=HorizonHomotopyProblem(baseProblem,anchor,lambda, ...
                residualDimension)
            if ~isa(baseProblem,'lmz.shooting.MultipleShootingProblem')
                error('lmz:Shooting:HomotopyProblem', ...
                    'Horizon homotopy requires a multiple-shooting problem.');
            end
            baseProblem.getDecisionSchema().validateVector(anchor);
            if ~isnumeric(lambda)||~isscalar(lambda)||~isfinite(lambda)|| ...
                    lambda<0||lambda>1
                error('lmz:Shooting:HomotopyLambda', ...
                    'Horizon homotopy lambda must lie in [0,1].');
            end
            if ~isnumeric(residualDimension)|| ...
                    ~isscalar(residualDimension)|| ...
                    residualDimension<0|| ...
                    residualDimension~=fix(residualDimension)
                error('lmz:Shooting:HomotopyResidualDimension', ...
                    'Homotopy residual dimension must be nonnegative.');
            end
            if residualDimension<numel(anchor)
                error('lmz:Shooting:HomotopyGaugeRequired', ...
                    ['Anchored point homotopy requires at least as many ' ...
                    'residual rows as unknowns. Add gauges or use an ' ...
                    'explicit family formulation.']);
            end
            configuration=baseProblem.Configuration;
            configuration.HorizonHomotopyLambda=lambda;
            configuration.HorizonHomotopyAnchor=anchor(:);
            obj@lmz.api.NonlinearEquationProblem(baseProblem.Model, ...
                baseProblem.Id,'nonlinear_equation', ...
                baseProblem.getDecisionSchema(), ...
                baseProblem.getParameterSchema(), ...
                baseProblem.DefaultParameters,configuration);
            obj.Version=baseProblem.Version;
            obj.BaseProblem=baseProblem;
            obj.AnchorDecision=anchor(:);
            obj.Lambda=lambda;
            obj.ResidualDimension=residualDimension;
        end

        function evaluation=evaluate(obj,u,p,context,includeSimulation)
            if nargin<5,includeSimulation=false;end
            obj.DecisionSchema.validateVector(u);
            obj.ParameterSchema.validateVector(p);
            base=obj.BaseProblem.evaluate(u,p,context,includeSimulation);
            full=base.ScaledResidual(:);
            if numel(full)~=obj.ResidualDimension
                error('lmz:Shooting:HomotopyResidualChanged', ...
                    'Wrapped horizon residual dimension changed.');
            end
            delta=obj.BaseProblem.difference(u,obj.AnchorDecision);
            scale=obj.BaseProblem.scale(obj.AnchorDecision);
            anchor=zeros(obj.ResidualDimension,1);
            anchor(1:numel(delta))=delta(:)./scale(:);
            blended=(1-obj.Lambda)*anchor+obj.Lambda*full;
            block=lmz.data.ResidualBlock( ...
                'horizon_homotopy_residual',blended, ...
                ones(size(blended)));
            feasibility=base.Feasibility;
            feasibility.HomotopyLambda=obj.Lambda;
            feasibility.HomotopyIntermediate=obj.Lambda<1;
            feasibility.FullProblemValid=logicalField( ...
                base.Feasibility,'Valid',false);
            feasibility.Valid=obj.Lambda==1&& ...
                feasibility.FullProblemValid;
            diagnostics=struct('Formulation','anchored-horizon-homotopy-v1', ...
                'Lambda',obj.Lambda,'AnchorDecision',obj.AnchorDecision, ...
                'AnchorResidualNorm',norm(anchor), ...
                'FullResidualNorm',norm(full), ...
                'BlendedResidualNorm',norm(blended), ...
                'FullProblemDiagnostics',base.Diagnostics, ...
                'FullResidualBlocks',{plainBlocks(base.ResidualBlocks)});
            evaluation=lmz.data.ProblemEvaluation(block, ...
                'Simulation',base.Simulation,'Feasibility',feasibility, ...
                'PhysicalValidity',base.PhysicalValidity, ...
                'Warnings',base.Warnings,'Diagnostics',diagnostics);
        end

        function value=expectedLocalDimension(obj)
            value=obj.BaseProblem.expectedLocalDimension();
        end
    end
end

function value=plainBlocks(blocks)
value=cell(numel(blocks),1);
for index=1:numel(blocks),value{index}=blocks(index).toStruct();end
end

function value=logicalField(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name)&&isscalar(source.(name))
    value=logical(source.(name));
end
end
