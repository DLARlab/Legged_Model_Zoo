classdef LegacyMatAdapter
    methods (Static)
        function branch=quadrupedBranch(path)
            d=load(path,'results');if ~isfield(d,'results')||size(d.results,1)<29,error('lmz:LegacyFormat','Expected results with at least 29 rows.');end
            codec=lmz.models.slip_quadruped.LegacySLIPQuadrupedCodec();branch=lmz.core.SolutionBranch();branch.ModelId='slip_quadruped';branch.ProblemId='periodic_orbit';branch.Provenance=struct('legacy_path',path);
            for i=1:size(d.results,2),q=codec.decodeResultColumn(d.results(:,i));p=struct('id',sprintf('legacy-%d',i),'arclength',NaN,'decision',q.decision,'decoded',q,'tangent',[],'step_size',NaN,'residual_norm',NaN,'residual_blocks',struct([]),'solver_status','imported','iterations',NaN,'observables',struct('speed',q.initial.dx),'classification',struct(),'warnings',{{}},'provenance',branch.Provenance);branch.addPoint(p);end
        end
    end
end
