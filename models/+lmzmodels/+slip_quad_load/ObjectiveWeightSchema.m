classdef ObjectiveWeightSchema
    methods (Static)
        function schema=create(weights)
            if nargin<1||isempty(weights),weights=struct();end
            values=[fieldOr(weights,'strideduration',10);fieldOr(weights,'ft',10);fieldOr(weights,'loadingforce',10)];
            names={'weight_stride_duration','weight_footfall_timing','weight_loading_force'};
            specs=lmz.schema.VariableSpec.empty(0,1);
            for index=1:3
                specs(index,1)=lmz.schema.VariableSpec(names{index},'Group','objective_weight', ...
                    'DefaultValue',values(index),'LowerBound',0,'Scale',max(1,values(index)), ...
                    'Topology','positive','Role','derived', ...
                    'EnergyEffect','invariant'); %#ok<AGROW>
            end
            schema=lmz.schema.VariableSchema(specs);
        end
    end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
