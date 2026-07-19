classdef PhysicalStateSchema
    methods (Static)
        function schema=create()
            quadruped=lmzmodels.slip_quad_load.QuadrupedStateSchema.create();
            loadSchema=lmzmodels.slip_quad_load.LoadStateSchema.create();
            schema=lmz.schema.VariableSchema([quadruped.Specs;loadSchema.Specs]);
        end
    end
end
