classdef TestProductChart < matlab.unittest.TestCase
    methods (Test)
        function centeredAngleDifference(testCase)
            schema=lmz.schema.VariableSchema(lmz.schema.VariableSpec('phase','Topology','angle','LowerBound',-Inf,'UpperBound',Inf));
            chart=lmz.schema.VariableChart(schema);
            testCase.verifyEqual(chart.difference(0.1,2*pi-0.1),0.2,'AbsTol',1e-12);
        end
    end
end
