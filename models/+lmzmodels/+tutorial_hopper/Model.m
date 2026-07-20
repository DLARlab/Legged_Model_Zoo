classdef Model < lmz.api.LeggedModel
    %MODEL Built-in analytic hybrid hopper tutorial.
    methods
        function value = getManifest(~)
            value = struct('id', 'tutorial_hopper', 'version', '1.0.0');
        end

        function value = getCapabilities(~)
            value = struct('simulate', true, 'solve', true, ...
                'continue', true, 'optimize', false, 'visualize', true, ...
                'animate', true, 'parameterHomotopy', false, ...
                'branchFamilyScan', false);
        end

        function value = getPhysicalStateSchema(~)
            value = lmzmodels.tutorial_hopper.PhysicalStateSchema.create();
        end

        function value = getParameterSchema(~)
            value = lmzmodels.tutorial_hopper.ParameterSchema.create();
        end

        function value = listProblems(~)
            value = {'periodic_hop','demo_hop'};
        end

        function value = createProblem(obj, id, configuration)
            if nargin < 3
                configuration = struct();
            end
            switch id
                case 'periodic_hop'
                    value = ...
                        lmzmodels.tutorial_hopper.PeriodicHopProblem( ...
                        obj, configuration);
                case 'demo_hop'
                    value = lmz.api.SimulationProblem( ...
                        obj, id, configuration);
                otherwise
                    error('lmz:tutorial_hopper:Problem', ...
                        'Unknown problem %s.', id);
            end
        end

        function result = simulate(obj, request, context)
            problem = obj.createProblem('periodic_hop', struct());
            decision = problem.getDecisionSchema().defaults();
            parameters = problem.getParameterSchema().defaults();
            if isa(request.Solution, 'lmz.data.Solution')
                decision = request.Solution.DecisionValues;
                parameters = request.Solution.ParameterValues;
            else
                if isfield(request.Options, 'decision')
                    decision = problem.getDecisionSchema().pack( ...
                        request.Options.decision);
                end
                if isfield(request.Options, 'parameters')
                    parameters = problem.getParameterSchema().pack( ...
                        request.Options.parameters);
                end
            end
            result = problem.simulateDecision( ...
                decision, parameters, context, request.ProblemId);
        end

        function value = kinematics(~, frame)
            value = frame;
        end

        function value = getPlotDescriptors(~)
            value = struct('id', {'trajectory','states'}, ...
                'label', {'Hopper trajectory','Hopper states'});
        end

        function value = getVisualizationPlugin(obj)
            manifest = obj.registeredManifest();
            if isempty(manifest)
                scenePath = fullfile(lmz.util.ProjectPaths.catalog(), ...
                    'tutorial_hopper', 'scene.lmz.json');
            else
                scenePath = fullfile( ...
                    manifest.catalogDirectory, 'scene.lmz.json');
            end
            value = lmzmodels.tutorial_hopper.HopperPlotPlugin(scenePath);
        end
    end
end
