classdef TestNonpositivePeriodRejection < matlab.unittest.TestCase
    methods (Test)
        function rejectsZero(testCase)
            specs=[lmz.schema.VariableSpec('period','DefaultValue',1); lmz.schema.VariableSpec('event','Topology','cyclic_time','PeriodSource','period')];
            schema=lmz.schema.VariableSchema(specs);
            testCase.verifyError(@()schema.validateVector([0;0]),'lmz:InvalidPeriod');
        end
    end
end
