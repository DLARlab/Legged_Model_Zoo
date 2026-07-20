classdef TestHybridSimulator < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addFixturesToPath(testCase)
            fixturesRoot = fullfile(lmz.util.ProjectPaths.tests(), 'fixtures');
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(fixturesRoot));
        end
    end

    methods (Test)
        function scheduledEventsUseStablePostEventPolicy(testCase)
            first = lmz.simulation.HybridEvent('late_priority', 0.5, ...
                'Priority', 1, 'DeclarationOrder', 1, ...
                'ResetId', 'increment');
            second = lmz.simulation.HybridEvent('early_priority', 0.5, ...
                'Priority', 0, 'DeclarationOrder', 2, ...
                'ToMode', 'mode_b', 'ResetId', 'increment');
            policy = lmz.simulation.ScheduledEventPolicy([first; second]);
            system = lmztest.GenericHybridSystem(policy, 0);
            request = struct('TimeSpan', [0 1], ...
                'Parameters', struct('rate', 0, 'increment', 1));
            result = lmz.simulation.HybridSimulator().simulate(system, ...
                request, lmz.api.RunContext.synchronous(0), struct());
            testCase.verifyEqual({result.EventRecords.Id}, ...
                {'early_priority','late_priority'});
            testCase.verifyEqual(result.EventRecords(1).PreState, 0);
            testCase.verifyEqual(result.EventRecords(1).PostState, 1);
            testCase.verifyEqual(result.EventRecords(2).PreState, 1);
            testCase.verifyEqual(result.EventRecords(2).PostState, 2);
            eventIndex = find(abs(result.Time - 0.5) < 1e-12, 1);
            testCase.verifyNotEmpty(eventIndex);
            testCase.verifyEqual(result.States(eventIndex, 1), 2);
            testCase.verifyGreaterThan(min(diff(result.Time)), 0);
            testCase.verifyEqual(result.Modes{eventIndex}, 'mode_b');
        end

        function guardEventResetsAndTerminates(testCase)
            definition = struct('Id', 'zero_crossing', ...
                'GuardFcn', @(~, state, ~, ~) state(1), ...
                'Direction', -1, 'Terminal', true, 'Priority', 0, ...
                'FromMode', 'mode_a', 'ToMode', 'mode_b', ...
                'ResetId', 'guard_reset');
            system = lmztest.GenericHybridSystem( ...
                lmz.simulation.GuardEventPolicy(definition), 1);
            request = struct('TimeSpan', [0 2], ...
                'Parameters', struct('rate', -1, 'resetValue', 2));
            result = lmz.simulation.HybridSimulator().simulate( ...
                system, request, lmz.api.RunContext.synchronous(0), ...
                struct('MaximumStep', 0.05));
            testCase.verifyEqual(numel(result.EventRecords), 1);
            testCase.verifyEqual(result.EventRecords.PostState, 2, 'AbsTol', 1e-10);
            testCase.verifyEqual(result.Time(end), 1, 'AbsTol', 1e-8);
            testCase.verifyEqual(result.States(end, 1), 2, 'AbsTol', 1e-10);
        end

        function honorsCancellation(testCase)
            policy = lmz.simulation.ScheduledEventPolicy();
            context = lmz.api.RunContext.synchronous(0);
            context.Cancellation.cancel();
            system = lmztest.GenericHybridSystem(policy, 0);
            request = struct('TimeSpan', [0 1], ...
                'Parameters', struct('rate', 0));
            testCase.verifyError(@() lmz.simulation.HybridSimulator().simulate( ...
                system, request, context, struct()), 'lmz:Cancelled');
        end

        function honorsInFlightCancellation(testCase)
            policy = lmz.simulation.ScheduledEventPolicy();
            context = lmz.api.RunContext.synchronous(0);
            context.ProgressFcn = @(~,~) context.Cancellation.cancel();
            system = lmztest.GenericHybridSystem(policy, 0);
            request = struct('TimeSpan', [0 10], ...
                'Parameters', struct('rate', 1));
            testCase.verifyError(@() ...
                lmz.simulation.HybridSimulator().simulate( ...
                system, request, context, struct('MaximumStep', 0.01)), ...
                'lmz:Cancelled');
        end
    end
end
