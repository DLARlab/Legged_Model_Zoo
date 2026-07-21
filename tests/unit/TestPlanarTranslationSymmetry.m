classdef TestPlanarTranslationSymmetry < matlab.unittest.TestCase
    methods (Test)
        function appliesInvertsAndAlignsSinglePosition(testCase)
            schema = localSchema({'x','vx','y'});
            symmetry = lmz.poincare.PlanarTranslationSymmetry( ...
                'planar_translation', {'x'});
            state = [1;2;3];

            shifted = symmetry.apply(state, 4, schema);
            testCase.verifyEqual(shifted, [5;2;3]);
            testCase.verifyEqual(symmetry.inverse(shifted, 4, schema), ...
                state);
            testCase.verifyEqual(symmetry.displacement( ...
                shifted, state, schema), 4);
            testCase.verifyEqual(symmetry.align(shifted, state, schema), ...
                state);
        end

        function coupledPositionsShareOneTranslation(testCase)
            schema = localSchema({'quad_x','load_x','speed'});
            symmetry = lmz.poincare.PlanarTranslationSymmetry( ...
                'planar_translation', {'quad_x','load_x'});
            reference = [1;4;2];
            returned = [5;8;2];

            testCase.verifyEqual(symmetry.displacement( ...
                returned, reference, schema), 4);
            testCase.verifyEqual(symmetry.align( ...
                returned, reference, schema), reference);
        end
    end
end

function value = localSchema(names)
specs = lmz.schema.VariableSpec.empty(0, 1);
for index = 1:numel(names)
    specs(index, 1) = lmz.schema.VariableSpec(names{index}); %#ok<AGROW>
end
value = lmz.schema.VariableSchema(specs);
end
