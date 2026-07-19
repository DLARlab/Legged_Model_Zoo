classdef PhysicalStateSchema
    %PHYSICALSTATESCHEMA Named 14-entry integrated quadruped state.
    methods (Static)
        function schema = create()
            names = {'x','dx','y','dy','phi','dphi', ...
                'alphaBL','dalphaBL','alphaFL','dalphaFL', ...
                'alphaBR','dalphaBR','alphaFR','dalphaFR'};
            units = {'m','m/s','m','m/s','rad','rad/s', ...
                'rad','rad/s','rad','rad/s','rad','rad/s','rad','rad/s'};
            specs = lmz.schema.VariableSpec.empty(0,1);
            for index = 1:numel(names)
                specs(end+1,1) = lmz.schema.VariableSpec(names{index}, ... %#ok<AGROW>
                    'Group','physical_state','Unit',units{index});
            end
            schema = lmz.schema.VariableSchema(specs,'1.0.0');
        end
    end
end
