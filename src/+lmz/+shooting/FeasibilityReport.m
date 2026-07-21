classdef FeasibilityReport
    %FEASIBILITYREPORT Qualified local numerical and physical evidence.
    properties (SetAccess=private)
        Classification
        Success
        SolverTerminationAcceptable
        PhysicalConditionsValid
        ResidualTolerance
        ScaledResidualNorm
        MaximumScaledResidual
        ResidualDimension
        DecisionDimension
        JacobianRank
        Nullity
        SingularValues
        ConditionEstimate
        ActiveBounds
        FirstOrderOptimality
        ResidualBlocks
        TerminationReason
        Qualifications
        Provenance
    end
    methods
        function obj=FeasibilityReport(value)
            if nargin<1,value=struct();end
            classification=fieldOr(value,'Classification','best_known_residual');
            allowed={'root_found','least_squares_feasible', ...
                'best_known_residual','local_infeasibility_evidence', ...
                'numerical_failure','physical_validation_failure'};
            if ~ischar(classification)||~any(strcmp(classification,allowed))
                error('lmz:Shooting:FeasibilityClassification', ...
                    'Unknown feasibility classification.');
            end
            obj.Classification=classification;
            obj.Success=logical(fieldOr(value,'Success',false));
            obj.SolverTerminationAcceptable=logical(fieldOr(value, ...
                'SolverTerminationAcceptable',false));
            obj.PhysicalConditionsValid=logical(fieldOr(value, ...
                'PhysicalConditionsValid',false));
            obj.ResidualTolerance=finiteScalar(value,'ResidualTolerance',1e-7);
            obj.ScaledResidualNorm=finiteOrInf(value,'ScaledResidualNorm',Inf);
            obj.MaximumScaledResidual=finiteOrInf(value, ...
                'MaximumScaledResidual',Inf);
            obj.ResidualDimension=nonnegative(value,'ResidualDimension',0);
            obj.DecisionDimension=nonnegative(value,'DecisionDimension',0);
            obj.JacobianRank=nonnegative(value,'JacobianRank',0);
            obj.Nullity=nonnegative(value,'Nullity',0);
            obj.SingularValues=finiteVector(fieldOr(value,'SingularValues',[]));
            obj.ConditionEstimate=finiteOrInf(value,'ConditionEstimate',Inf);
            obj.ActiveBounds=fieldOr(value,'ActiveBounds',struct());
            obj.FirstOrderOptimality=finiteOrInf(value, ...
                'FirstOrderOptimality',Inf);
            obj.ResidualBlocks=fieldOr(value,'ResidualBlocks',{});
            obj.TerminationReason=fieldOr(value,'TerminationReason','not-run');
            obj.Qualifications=fieldOr(value,'Qualifications',{});
            obj.Provenance=fieldOr(value,'Provenance',struct());
        end

        function value=toStruct(obj)
            value=struct('Classification',obj.Classification, ...
                'Success',obj.Success, ...
                'SolverTerminationAcceptable',obj.SolverTerminationAcceptable, ...
                'PhysicalConditionsValid',obj.PhysicalConditionsValid, ...
                'ResidualTolerance',obj.ResidualTolerance, ...
                'ScaledResidualNorm',obj.ScaledResidualNorm, ...
                'MaximumScaledResidual',obj.MaximumScaledResidual, ...
                'ResidualDimension',obj.ResidualDimension, ...
                'DecisionDimension',obj.DecisionDimension, ...
                'JacobianRank',obj.JacobianRank,'Nullity',obj.Nullity, ...
                'SingularValues',obj.SingularValues, ...
                'ConditionEstimate',obj.ConditionEstimate, ...
                'ActiveBounds',obj.ActiveBounds, ...
                'FirstOrderOptimality',obj.FirstOrderOptimality, ...
                'ResidualBlocks',{obj.ResidualBlocks}, ...
                'TerminationReason',obj.TerminationReason, ...
                'Qualifications',{obj.Qualifications}, ...
                'Provenance',obj.Provenance);
        end
    end

    methods (Static)
        function obj=fromSolve(evaluation,diagnostics,exitFlag,tolerance)
            if nargin<4,tolerance=1e-7;end
            physical=evaluation.PhysicalValidity&&physicalConditions( ...
                evaluation.Feasibility);
            acceptable=exitFlag>0;
            maximum=maxOrZero(abs(evaluation.ScaledResidual));
            residualValid=maximum<=tolerance;
            m=numel(evaluation.ScaledResidual);
            n=fieldOr(diagnostics,'N',0);
            success=acceptable&&physical&&residualValid;
            if ~physical
                classification='physical_validation_failure';
            elseif ~acceptable
                classification='numerical_failure';
            elseif success&&m==n
                classification='root_found';
            elseif success
                classification='least_squares_feasible';
            else
                classification='best_known_residual';
            end
            blocks=cell(numel(evaluation.ResidualBlocks),1);
            for index=1:numel(blocks)
                blocks{index}=evaluation.ResidualBlocks(index).toStruct();
            end
            value=struct('Classification',classification,'Success',success, ...
                'SolverTerminationAcceptable',acceptable, ...
                'PhysicalConditionsValid',physical, ...
                'ResidualTolerance',tolerance, ...
                'ScaledResidualNorm',evaluation.ScaledResidualNorm, ...
                'MaximumScaledResidual',maximum,'ResidualDimension',m, ...
                'DecisionDimension',n,'JacobianRank', ...
                fieldOr(diagnostics,'Rank',0),'Nullity', ...
                fieldOr(diagnostics,'Nullity',0),'SingularValues', ...
                fieldOr(diagnostics,'SingularValues',[]), ...
                'ConditionEstimate',fieldOr(diagnostics, ...
                'ConditionEstimate',Inf),'ActiveBounds', ...
                fieldOr(diagnostics,'ActiveBounds',struct()), ...
                'FirstOrderOptimality',fieldOr(diagnostics, ...
                'FirstOrderOptimality',Inf),'ResidualBlocks',{blocks}, ...
                'TerminationReason',termination(exitFlag), ...
                'Qualifications',{{ ...
                'Local numerical evidence; not a global existence certificate.'}}, ...
                'Provenance',struct('RankDiagnostics',diagnostics));
            obj=lmz.shooting.FeasibilityReport(value);
        end
    end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=finiteScalar(source,name,fallback)
value=fieldOr(source,name,fallback);
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)||value<0
    error('lmz:Shooting:FeasibilityScalar','%s must be finite and nonnegative.',name);
end
end
function value=finiteOrInf(source,name,fallback)
value=fieldOr(source,name,fallback);
if ~isnumeric(value)||~isscalar(value)||isnan(value)
    error('lmz:Shooting:FeasibilityScalar','%s must be numeric and not NaN.',name);
end
end
function value=nonnegative(source,name,fallback)
value=fieldOr(source,name,fallback);
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)||value<0||value~=fix(value)
    error('lmz:Shooting:FeasibilityCount','%s must be a nonnegative integer.',name);
end
end
function value=finiteVector(source)
if ~isnumeric(source)||(~isempty(source)&&~isvector(source))|| ...
        any(~isfinite(source(:)))
    error('lmz:Shooting:FeasibilityVector','Singular values must be finite.');
end
value=source(:);
end
function value=maxOrZero(source)
if isempty(source),value=0;else,value=max(source);end
end
function value=termination(exitFlag)
if exitFlag>0
    value='acceptable-solver-termination';
elseif exitFlag==0
    value='iteration-or-evaluation-limit';
else
    value='solver-failure';
end
end

function value=physicalConditions(feasibility)
value=false;
if ~isstruct(feasibility)||~isscalar(feasibility),return,end
if isfield(feasibility,'PhysicalConditionsValid')
    value=logical(feasibility.PhysicalConditionsValid);
elseif isfield(feasibility,'PhysicalValidity')
    value=logical(feasibility.PhysicalValidity);
elseif isfield(feasibility,'Valid')
    value=logical(feasibility.Valid);
end
value=isscalar(value)&&value;
end
