classdef QuadrupedStateSchema
    methods (Static)
        function schema=create()
            names={'quad_x','quad_dx','quad_y','quad_dy','quad_phi','quad_dphi', ...
                'alphaBL','dalphaBL','alphaFL','dalphaFL', ...
                'alphaBR','dalphaBR','alphaFR','dalphaFR'};
            specs=lmz.schema.VariableSpec.empty(0,1);
            for index=1:numel(names)
                unit='normalized';if ~isempty(strfind(names{index},'phi'))||~isempty(strfind(names{index},'alpha')),unit='rad';end
                specs(index,1)=lmz.schema.VariableSpec(names{index},'Group','quadruped_state','Unit',unit); %#ok<AGROW>
            end
            schema=lmz.schema.VariableSchema(specs);
        end
    end
end
