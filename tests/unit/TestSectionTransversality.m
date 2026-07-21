classdef TestSectionTransversality < matlab.unittest.TestCase
    methods (Test)
        function statePlaneReportsDirectionalDerivative(testCase)
            schema = localSchema();
            section = lmz.poincare.StateFunctionSection( ...
                localDescriptor(), schema);
            crossing = section.crossingAt(0.5, [2;0], [1;-2]);

            testCase.verifyEqual(crossing.Value, 0);
            testCase.verifyEqual(crossing.DirectionalDerivative, -2);
            testCase.verifyEqual(crossing.CrossingDirection, -1);
            testCase.verifyFalse(crossing.Grazing);
            testCase.verifyTrue(crossing.Accepted);
            testCase.verifyEqual( ...
                crossing.Metadata.TransversalityStatus, 'transverse');
        end
    end
end

function value = localDescriptor()
value = lmz.poincare.PoincareSectionDescriptor(struct( ...
    'id', 'plane', 'label', 'Plane', 'kind', 'state_plane', ...
    'stateName', 'y', 'threshold', 0, 'crossingDirection', -1, ...
    'stateSide', 'post', 'minimumReturnTime', 0, ...
    'requiredEventSequence', {{}}, 'returnOccurrence', 1, ...
    'coordinateNames', {{'x'}}, ...
    'symmetryClass', 'lmz.poincare.IdentitySymmetry', ...
    'maturities', {{'experimental'}}, 'validationStatus', 'tested'));
end

function value = localSchema()
value = lmz.schema.VariableSchema([ ...
    lmz.schema.VariableSpec('x'); lmz.schema.VariableSpec('y')]);
end
