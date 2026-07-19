classdef LoadStateSchema
    methods (Static)
        function schema=create()
            names={'load_x','load_dx','load_y','load_dy'};specs=lmz.schema.VariableSpec.empty(0,1);
            for index=1:numel(names),specs(index,1)=lmz.schema.VariableSpec(names{index},'Group','load_state','Unit','normalized');end
            schema=lmz.schema.VariableSchema(specs);
        end
    end
end
