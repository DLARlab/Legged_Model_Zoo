classdef ProblemEvaluation
    properties (SetAccess=private)
        ResidualBlocks; Residual; ScaledResidual; ResidualNorm; ScaledResidualNorm
        Simulation; Feasibility; PhysicalValidity; Warnings; Diagnostics
    end
    methods
        function obj=ProblemEvaluation(blocks,varargin)
            parser=inputParser; addParameter(parser,'Simulation',[]); addParameter(parser,'Feasibility',struct('Valid',true));
            addParameter(parser,'PhysicalValidity',true); addParameter(parser,'Warnings',{}); addParameter(parser,'Diagnostics',struct()); parse(parser,varargin{:});
            obj.ResidualBlocks=blocks(:); raw=[]; scaled=[];
            for index=1:numel(blocks), raw=[raw;blocks(index).Values]; scaled=[scaled;blocks(index).scaled()]; end %#ok<AGROW>
            obj.Residual=raw; obj.ScaledResidual=scaled; obj.ResidualNorm=norm(raw); obj.ScaledResidualNorm=norm(scaled);
            obj.Simulation=parser.Results.Simulation; obj.Feasibility=parser.Results.Feasibility; obj.PhysicalValidity=parser.Results.PhysicalValidity;
            obj.Warnings=parser.Results.Warnings; obj.Diagnostics=parser.Results.Diagnostics;
        end
    end
end
