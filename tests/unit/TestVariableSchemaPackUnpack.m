classdef TestVariableSchemaPackUnpack < matlab.unittest.TestCase
    methods (Test)
        function roundTrip(testCase)
            specs=[lmz.schema.VariableSpec('x','DefaultValue',2); lmz.schema.VariableSpec('y','DefaultValue',3,'Scale',2)];
            schema=lmz.schema.VariableSchema(specs); values=schema.unpack([4;5]);
            testCase.verifyEqual(schema.pack(values),[4;5]); testCase.verifyEqual(schema.names(),{'x';'y'});
        end
        function rejectsDuplicate(testCase)
            specs=[lmz.schema.VariableSpec('x');lmz.schema.VariableSpec('x')];
            testCase.verifyError(@()lmz.schema.VariableSchema(specs), ...
                'lmz:Schema:DuplicateVariable');
        end
    end
end
