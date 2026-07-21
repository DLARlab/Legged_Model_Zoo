classdef LoadParameterSchema
    methods (Static)
        function schema=create(defaults)
            if nargin<1,defaults=[0.8;0.5;0.08;2.4;8;0];end
            names={'load_height','load_mass','load_friction','tugline_rest_length', ...
                'tugline_stiffness','slope_angle'};defaults=defaults(:);
            specs=lmz.schema.VariableSpec.empty(0,1);
            for index=1:numel(names)
                specs(index,1)=lmz.schema.VariableSpec(names{index},'Group','load_parameter', ...
                    'DefaultValue',defaults(index),'Scale',max(1,abs(defaults(index))), ...
                    'Unit','normalized','Role','physical', ...
                    'EnergyEffect','state_dependent'); %#ok<AGROW>
            end
            schema=lmz.schema.VariableSchema(specs);
        end
    end
end
