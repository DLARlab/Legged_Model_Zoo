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
            value = {'periodic_hop','demo_hop','section_return_timing', ...
                'periodic_orbit','n_stride_simulation', ...
                'contact_timing_sequence','multiple_shooting'};
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
                case 'section_return_timing'
                    value = lmzmodels.tutorial_hopper. ...
                        ContactConstraintProvider.createProblem(obj,configuration);
                case 'periodic_orbit'
                    value=lmzmodels.tutorial_hopper.PeriodicOrbitProblem( ...
                        obj,configuration);
                case 'n_stride_simulation'
                    value=lmz.multistride.NStrideSimulationProblem( ...
                        obj,configuration);
                case 'contact_timing_sequence'
                    value=lmz.multistride.ContactTimingSequenceFactory. ...
                        create(obj,configuration);
                case 'multiple_shooting'
                    value=lmzmodels.tutorial_hopper. ...
                        MultipleShootingFactory.create(obj,configuration);
                otherwise
                    error('lmz:tutorial_hopper:Problem', ...
                        'Unknown problem %s.', id);
            end
        end

        function result = simulate(obj, request, context)
            if strcmp(request.ProblemId,'n_stride_simulation')
                configuration=nStrideConfiguration(obj,request);
                outcome=obj.createProblem(request.ProblemId, ...
                    configuration).simulate(context);
                result=outcome.Simulation;
                return
            end
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

        function value=getMultiStrideProvider(~)
            value=lmzmodels.internal.BuiltInMultiStrideSimulationProvider();
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

function value=nStrideConfiguration(model,request)
value=request.Options;
problem=model.createProblem('periodic_hop',struct());
if isa(request.Solution,'lmz.data.Solution')
    value.InitialDecision=request.Solution.DecisionValues;
elseif isfield(value,'decision')
    value.InitialDecision=problem.getDecisionSchema().pack(value.decision);
    value=rmfield(value,'decision');
end
if isfield(value,'parameters')
    error('lmz:MultiStride:FixedSourceParameters', ...
        'Tutorial N-stride simulation currently fixes physical parameters.');
end
end
