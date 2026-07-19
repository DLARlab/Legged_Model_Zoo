classdef CompositeObjective
    methods (Static)
        function [value,diagnostics]=compute(terms)
            values=[terms.StrideDuration.Value terms.FootfallTiming.Value terms.LoadingForce.Value];
            weights=[terms.StrideDuration.Weight terms.FootfallTiming.Weight terms.LoadingForce.Weight];
            value=sum(values.*weights);diagnostics=struct('UnweightedValues',values, ...
                'Weights',weights,'WeightedValues',values.*weights,'Formula','sum(weight .* source_L2_norm)');
        end
    end
end
