classdef SecantPredictor
    methods (Static)
        function [prediction,tangent]=predict(problem,previous,current,step)
            delta=problem.difference(current,previous); scale=problem.scale(current,previous); metric=lmz.schema.DiagonalMetric(scale); length=metric.norm(delta);
            if length<=eps,error('lmz:Continuation:DuplicateSeeds','Seed points are duplicate.');end
            tangent=delta/length; prediction=problem.retract(current,step*tangent);
        end
    end
end
