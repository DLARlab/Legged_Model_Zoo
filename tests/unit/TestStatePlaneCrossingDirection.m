classdef TestStatePlaneCrossingDirection < matlab.unittest.TestCase
    methods (Test)
        function detectsOnlyRequestedDirection(testCase)
            schema = localSchema({'x','y'});
            descriptor = localPlaneDescriptor(-1);
            section = lmz.poincare.StateFunctionSection( ...
                descriptor, schema);

            [detected, crossing] = section.detectCrossing( ...
                0, [0;1], 1, [1;-1]);
            testCase.verifyTrue(detected);
            testCase.verifyTrue(crossing.Accepted);
            testCase.verifyEqual(crossing.Time, 0.5, ...
                'AbsTol', 10 * eps);
            testCase.verifyEqual(crossing.State, [0.5;0], ...
                'AbsTol', 10 * eps);
            testCase.verifyEqual(crossing.CrossingDirection, -1);

            [detected, crossing] = section.detectCrossing( ...
                0, [0;-1], 1, [1;1]);
            testCase.verifyFalse(detected);
            testCase.verifyEmpty(crossing);
        end
    end
end

function value = localPlaneDescriptor(direction)
value = lmz.poincare.PoincareSectionDescriptor(struct( ...
    'id', 'height', 'label', 'Height', 'kind', 'state_plane', ...
    'stateName', 'y', 'threshold', 0, ...
    'crossingDirection', direction, 'stateSide', 'post', ...
    'minimumReturnTime', 0, 'requiredEventSequence', {{}}, ...
    'returnOccurrence', 1, 'coordinateNames', {{'x'}}, ...
    'symmetryClass', 'lmz.poincare.IdentitySymmetry', ...
    'maturities', {{'tutorial'}}, 'validationStatus', 'tested'));
end

function value = localSchema(names)
specs = lmz.schema.VariableSpec.empty(0, 1);
for index = 1:numel(names)
    specs(index, 1) = lmz.schema.VariableSpec(names{index}); %#ok<AGROW>
end
value = lmz.schema.VariableSchema(specs);
end
