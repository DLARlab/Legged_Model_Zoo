classdef Model < lmz.api.LeggedModel
    methods
        function value = getManifest(~)
            value = struct('id', 'analytic_hopper', 'version', '1.0.0');
        end
        function value = getCapabilities(~)
            value = struct('simulate', true, 'solve', true, ...
                'continue', true, 'optimize', false, 'visualize', true, ...
                'animate', true, 'parameterHomotopy', false, ...
                'branchFamilyScan', false);
        end
        function value = getPhysicalStateSchema(~)
            value = lmzplugins.analytic_hopper.PhysicalStateSchema.create();
        end
        function value = getParameterSchema(~)
            value = lmzplugins.analytic_hopper.ParameterSchema.create();
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
                    value = lmzplugins.analytic_hopper.PeriodicHopProblem( ...
                        obj, configuration);
                case 'demo_hop'
                    value = lmz.api.SimulationProblem(obj, id, configuration);
                otherwise
                    error('analytic_hopper:Problem', 'Unknown problem %s.', id);
            end
        end
        function result = simulate(obj, request, context)
            problem = obj.createProblem('periodic_hop', struct());
            u = problem.getDecisionSchema().defaults();
            p = problem.getParameterSchema().defaults();
            if isa(request.Solution, 'lmz.data.Solution')
                u = request.Solution.DecisionValues;
                p = request.Solution.ParameterValues;
            elseif isfield(request.Options, 'decision')
                u = problem.getDecisionSchema().pack(request.Options.decision);
            end
            result = problem.simulateDecision(u, p, context);
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
                value = [];
                return
            end
            value = lmzplugins.analytic_hopper.HopperPlotPlugin( ...
                fullfile(manifest.catalogDirectory, 'scene.lmz.json'));
        end
    end
end
