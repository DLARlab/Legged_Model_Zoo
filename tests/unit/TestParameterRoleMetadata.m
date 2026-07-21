classdef TestParameterRoleMetadata < matlab.unittest.TestCase
    methods (Test)
        function defaultsAreConservativeAndEnumsAreValidated(testCase)
            spec=lmz.schema.VariableSpec('x');
            testCase.verifyEqual(spec.Role,'physical');
            testCase.verifyEqual(spec.EnergyEffect,'unknown');
            testCase.verifyError(@()lmz.schema.VariableSpec( ...
                'x','Role','actuator'),'lmz:Schema:InvalidRole');
            testCase.verifyError(@()lmz.schema.VariableSpec( ...
                'x','EnergyEffect','neutral'), ...
                'lmz:Schema:InvalidEnergyEffect');
        end

        function structRoundTripAndLegacyFallback(testCase)
            source=lmz.schema.VariableSpec('impulse','Role','control', ...
                'EnergyEffect','work_input');
            stored=source.toStruct();
            restored=lmz.schema.VariableSpec.fromStruct(stored);
            testCase.verifyEqual(restored.Role,'control');
            testCase.verifyEqual(restored.EnergyEffect,'work_input');

            legacy=rmfield(stored,{'Role','EnergyEffect'});
            restored=lmz.schema.VariableSpec.fromStruct(legacy);
            testCase.verifyEqual(restored.Role,'physical');
            testCase.verifyEqual(restored.EnergyEffect,'unknown');
        end

        function tutorialMetadataDistinguishesControlAndSchedule(testCase)
            parameters=lmzmodels.tutorial_hopper.ParameterSchema.create();
            verifyMetadata(testCase,parameters,'gravity', ...
                'physical','state_dependent');
            problem=lmzmodels.tutorial_hopper.Model().createProblem( ...
                'periodic_hop',struct());
            decision=problem.getDecisionSchema();
            verifyMetadata(testCase,decision,'stride_period', ...
                'schedule','invariant');
            verifyMetadata(testCase,decision,'impulse', ...
                'control','work_input');
            verifyMetadata(testCase,decision,'stride_length', ...
                'derived','invariant');
        end

        function quadrupedAndBipedMetadataIsExplicit(testCase)
            quadruped=lmzmodels.slip_quadruped.ParameterSchema.create();
            verifyMetadata(testCase,quadruped,'k_leg', ...
                'physical','state_dependent');
            verifyMetadata(testCase,quadruped,'phi_neutral', ...
                'physical','unknown');
            quadrupedDecision= ...
                lmzmodels.slip_quadruped.PeriodicDecisionSchema.create();
            verifyMetadata(testCase,quadrupedDecision,'dx', ...
                'physical','unknown');
            verifyMetadata(testCase,quadrupedDecision,'tBL_TD', ...
                'schedule','invariant');

            biped=lmzmodels.slip_biped.OffsetParameterSchema.create();
            verifyMetadata(testCase,biped,'offset_left', ...
                'control','unknown');
            fit=lmzmodels.slip_biped.TrajectoryFitDecisionSchema.create();
            verifyMetadata(testCase,fit,'tAPEX','schedule','invariant');
            verifyMetadata(testCase,fit,'k_leg', ...
                'physical','state_dependent');
            verifyMetadata(testCase,fit,'omega_swing', ...
                'control','unknown');
        end

        function quadLoadMetadataFollowsDecisionGroups(testCase)
            parameters= ...
                lmzmodels.slip_quad_load.QuadrupedParameterSchema.create();
            verifyMetadata(testCase,parameters,'leg_stiffness', ...
                'physical','state_dependent');
            verifyMetadata(testCase,parameters,'swing_pre_BL', ...
                'control','state_dependent');
            weights=lmzmodels.slip_quad_load.ObjectiveWeightSchema.create();
            verifyMetadata(testCase,weights,'weight_stride_duration', ...
                'derived','invariant');

            decision= ...
                lmzmodels.slip_quad_load.MultiStrideDecisionSchema.create(2);
            verifyMetadata(testCase,decision,'quad_dx', ...
                'physical','unknown');
            verifyMetadata(testCase,decision,'tBL_TD', ...
                'schedule','invariant');
            verifyMetadata(testCase,decision,'swing_post_BL', ...
                'control','state_dependent');
            verifyMetadata(testCase,decision,'stride2_tAPEX', ...
                'schedule','invariant');
            verifyMetadata(testCase,decision,'stride2_swing_post_BL', ...
                'control','state_dependent');
            verifyMetadata(testCase,decision,'load_mass', ...
                'physical','state_dependent');
        end
    end
end

function verifyMetadata(testCase,schema,name,role,energyEffect)
spec=schema.Specs(schema.indexOf(name));
testCase.verifyEqual(spec.Role,role,name);
testCase.verifyEqual(spec.EnergyEffect,energyEffect,name);
end
