classdef QuadrupedParameterSchema
    methods (Static)
        function schema=create(defaults)
            if nargin<1,defaults=[8;20*ones(8,1);4;1;0;0.5;1];end
            names={'leg_stiffness','swing_pre_BL','swing_pre_FL','swing_pre_BR','swing_pre_FR', ...
                'swing_post_BL','swing_post_FL','swing_post_BR','swing_post_FR', ...
                'torso_inertia','leg_length','swing_neutral_angle', ...
                'back_attachment_ratio','back_front_stiffness_ratio'};
            roles=[{'physical'},repmat({'control'},1,8),repmat({'physical'},1,5)];
            specs=lmz.schema.VariableSpec.empty(0,1);defaults=defaults(:);
            for index=1:numel(names)
                specs(index,1)=lmz.schema.VariableSpec(names{index},'Group','quadruped_parameter', ...
                    'DefaultValue',defaults(index),'Scale',max(1,abs(defaults(index))), ...
                    'Unit','normalized','Role',roles{index}, ...
                    'EnergyEffect','state_dependent'); %#ok<AGROW>
            end
            schema=lmz.schema.VariableSchema(specs);
        end
    end
end
