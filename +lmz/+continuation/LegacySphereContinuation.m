classdef LegacySphereContinuation
    methods, function branch=run(~,problem,seed1,seed2,options),warning('lmz:LegacyContinuation','Legacy sphere continuation is comparison-only; use PseudoArclengthContinuation.');branch=lmz.continuation.PseudoArclengthContinuation().run(problem,seed1,seed2,options);branch.Metadata.algorithm='legacy-sphere-compatible-adapter';end,end
end
