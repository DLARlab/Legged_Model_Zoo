classdef SimulationService
    %SIMULATIONSERVICE Generic synchronous simulation orchestration.
    methods
        function result = simulate(~, problem, solution, options, context)
            if ~isa(problem, 'lmz.api.SimulationProblem')
                error('lmz:Services:InvalidSimulationProblem', ...
                    'SimulationService requires a SimulationProblem.');
            end
            capabilities = problem.Model.getCapabilities();
            if ~capabilities.simulate
                error('lmz:Services:UnsupportedCapability', ...
                    'Model does not support simulation.');
            end
            context.check();
            descriptor = problem.getDescriptor();
            request = lmz.api.SimulationRequest(descriptor.modelId, ...
                problem.Id, solution, options);
            context.log('info', ['Simulating ' descriptor.modelId '.']);
            result = problem.Model.simulate(request, context);
            if ~isa(result, 'lmz.api.SimulationResult')
                error('lmz:Services:InvalidSimulationResult', ...
                    'Model returned an invalid simulation result.');
            end
        end
    end
end
