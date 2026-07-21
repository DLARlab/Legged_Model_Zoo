classdef ShootingResidual
    %SHOOTINGRESIDUAL Named multiple-shooting residual and cached segments.
    properties (SetAccess=private)
        Blocks
        SegmentResults
        InterfaceDefects
        Feasibility
        Diagnostics
    end
    methods
        function obj=ShootingResidual(blocks,segmentResults,defects, ...
                feasibility,diagnostics)
            if isempty(blocks),blocks=lmz.data.ResidualBlock.empty(0,1);end
            if ~all(arrayfun(@(item)isa(item,'lmz.data.ResidualBlock'),blocks))
                error('lmz:Shooting:ResidualBlocks','Shooting residual blocks are invalid.');
            end
            if nargin<2,segmentResults={};end
            if nargin<3,defects=lmz.shooting.InterfaceDefect.empty(0,1);end
            if nargin<4,feasibility=struct('Valid',true);end
            if nargin<5,diagnostics=struct();end
            obj.Blocks=blocks(:);obj.SegmentResults=segmentResults;
            obj.InterfaceDefects=defects(:);obj.Feasibility=feasibility;
            obj.Diagnostics=diagnostics;
        end
        function value=unscaled(obj)
            value=[];
            for index=1:numel(obj.Blocks),value=[value;obj.Blocks(index).Values];end %#ok<AGROW>
        end
        function value=scaled(obj)
            value=[];
            for index=1:numel(obj.Blocks),value=[value;obj.Blocks(index).scaled()];end %#ok<AGROW>
        end
        function value=toEvaluation(obj,includeSimulation)
            if nargin<2,includeSimulation=false;end
            simulation=[];
            if includeSimulation
                simulations=cellfun(@(item)item.Simulation, ...
                    obj.SegmentResults,'UniformOutput',false);
                simulation=simulations;
            end
            value=lmz.data.ProblemEvaluation(obj.Blocks, ...
                'Simulation',simulation,'Feasibility',obj.Feasibility, ...
                'PhysicalValidity',physicalValidity(obj.Feasibility), ...
                'Diagnostics',obj.Diagnostics);
        end
    end
end

function value=physicalValidity(feasibility)
if isstruct(feasibility)&&isfield(feasibility,'PhysicalValidity')
    value=logical(feasibility.PhysicalValidity);
elseif isstruct(feasibility)&&isfield(feasibility,'Valid')
    value=logical(feasibility.Valid);
else
    value=false;
end
end
