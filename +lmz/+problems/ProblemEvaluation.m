classdef ProblemEvaluation
    properties
        EqualityResidual double=[]; InequalityResidual double=[]; ObjectiveResidual double=[]; Objective double=0
        ResidualBlocks struct=struct([]); Simulation=[]; IsValid logical=true; IsPhysicallyValid logical=true
        Failure struct=struct('identifier','','message',''); Diagnostics struct=struct(); ElapsedSeconds double=0
    end
    methods
        function obj=ProblemEvaluation(varargin),if nargin>0,s=varargin{1};f=fieldnames(s);for i=1:numel(f),if isprop(obj,f{i}),obj.(f{i})=s.(f{i});end,end,end
        function r=scaledEquality(obj),if isempty(obj.ResidualBlocks),r=obj.EqualityResidual(:);else,r=[];for i=1:numel(obj.ResidualBlocks),if strcmp(obj.ResidualBlocks(i).kind,'equality'),r=[r;obj.ResidualBlocks(i).values(:)./obj.ResidualBlocks(i).scale(:)];end,end,end,end
    end
    methods (Static)
        function obj=failure(exception,n)
            if nargin<2,n=1;end;obj=lmz.problems.ProblemEvaluation();obj.EqualityResidual=1e6*ones(n,1);obj.IsValid=false;obj.IsPhysicallyValid=false;obj.Failure=struct('identifier',exception.identifier,'message',exception.message);
        end
    end
end
