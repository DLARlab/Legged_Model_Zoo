classdef TestContactTimingReproducibleMultistart < matlab.unittest.TestCase
    methods (Test)
        function sameSeedProducesSameSchedule(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            problem=registry.createModel('tutorial_hopper').createProblem( ...
                'section_return_timing',struct());seed=problem.getDecisionSchema().defaults();
            options=struct('MultistartCount',2,'MultistartScale',.01);
            first=lmz.services.ContactTimingService().solve(problem,seed,options, ...
                lmz.api.RunContext.synchronous(908));
            second=lmz.services.ContactTimingService().solve(problem,seed,options, ...
                lmz.api.RunContext.synchronous(908));
            testCase.verifyEqual(first.SolvedSchedule.times(), ...
                second.SolvedSchedule.times(),'AbsTol',0);
            testCase.verifyEqual(first.SolvedSchedule.ReturnTime, ...
                second.SolvedSchedule.ReturnTime,'AbsTol',0);
        end
    end
end
