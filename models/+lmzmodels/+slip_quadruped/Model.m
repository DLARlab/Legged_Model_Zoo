classdef Model < lmz.api.LeggedModel
    %MODEL Standalone scientific SLIP quadruped plus introductory demo.
    methods
        function value = getManifest(~)
            value = struct('id','slip_quadruped','version','2.0.0');
        end
        function value = getCapabilities(~)
            value = struct('simulate',true,'solve',true,'continue',true, ...
                'optimize',false,'visualize',true,'animate',true, ...
                'parameterHomotopy',true,'branchFamilyScan',true, ...
                'scientificRoadMap',true,'legacyResults29',true);
        end
        function schema = getPhysicalStateSchema(~)
            schema = lmzmodels.slip_quadruped.PhysicalStateSchema.create();
        end
        function schema = getParameterSchema(~)
            schema = lmzmodels.slip_quadruped.ParameterSchema.create();
        end
        function value = listProblems(~)
            value = {'periodic_apex','periodic_orbit','demo_stride', ...
                'section_return_timing','multiple_shooting','section_transition', ...
                'n_stride_simulation'};
        end
        function problem = createProblem(obj,problemId,configuration)
            switch problemId
                case 'demo_stride'
                    problem = lmz.api.SimulationProblem(obj,problemId,configuration);
                case 'periodic_apex'
                    problem = lmzmodels.slip_quadruped.PeriodicApexProblem(obj,configuration);
                case 'periodic_orbit'
                    problem = lmzmodels.slip_quadruped.PeriodicOrbitProblem( ...
                        obj, configuration);
                case 'section_return_timing'
                    problem = lmzmodels.slip_quadruped. ...
                        ContactConstraintProvider.createProblem(obj,configuration);
                case 'multiple_shooting'
                    problem=lmz.shooting. ...
                        ScientificHomogeneousMultipleShootingFactory. ...
                        create(obj,configuration);
                case 'section_transition'
                    problem=lmz.shooting. ...
                        ScientificSectionTransitionFactory.create( ...
                        obj,configuration);
                case 'n_stride_simulation'
                    problem=lmz.multistride.NStrideSimulationProblem( ...
                        obj,configuration);
                otherwise
                    error('lmz:slip_quadruped:UnknownProblem','Unknown problem: %s',problemId);
            end
        end
        function result = simulate(obj,request,context)
            switch request.ProblemId
                case 'n_stride_simulation'
                    configuration=nStrideConfiguration(obj,request, ...
                        'periodic_apex');
                    outcome=obj.createProblem(request.ProblemId, ...
                        configuration).simulate(context);
                    result=outcome.Simulation;
                case {'periodic_apex','periodic_orbit'}
                    problem = obj.createProblem(request.ProblemId, ...
                        request.Options);
                    if isa(request.Solution,'lmz.data.Solution')
                        u = request.Solution.DecisionValues;
                        p = request.Solution.ParameterValues;
                    else
                        u = problem.getDecisionSchema().defaults();
                        p = problem.getParameterSchema().defaults();
                        if isfield(request.Options,'decision')
                            u = problem.getDecisionSchema().pack(request.Options.decision);
                        end
                        if isfield(request.Options,'parameters')
                            p = problem.getParameterSchema().pack(request.Options.parameters);
                        end
                    end
                    result = problem.evaluate(u,p,context,true).Simulation;
                    context.progress(1,'Scientific SLIP quadruped stride simulated.');
                otherwise
                    result = obj.simulateDemo(request,context);
            end
        end
        function value = kinematics(~,frame), value = frame; end
        function value = getPlotDescriptors(~)
            value = struct('id',{'trajectory','vertical_grf','horizontal_grf', ...
                'oscillator'},'label',{'Torso and legs','Vertical GRF', ...
                'Horizontal GRF','Footfall phases'});
        end
        function plotSimulation(~,axesMap,simulation,profile)
            %PLOTSIMULATION Populate the five GUI analysis axes through the
            % model-owned source plot provider.  Keeping this dispatch here
            % prevents the generic GUI from knowing model-specific channels.
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotTorso(axesMap.Torso,simulation,profile);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotBackLegs(axesMap.Back,simulation,profile);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotFrontLegs(axesMap.Front,simulation,profile);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotGRF(axesMap.Forces,simulation,profile);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotOscillator(axesMap.Auxiliary,simulation,profile);
        end
        function value = getVisualizationPlugin(obj)
            manifest = obj.registeredManifest();
            if isempty(manifest)
                value = [];
            else
                value = lmzmodels.slip_quadruped.QuadrupedScenePlugin( ...
                    fullfile(manifest.catalogDirectory, 'scene.lmz.json'));
            end
        end
        function value=getMultiStrideProvider(~)
            value=lmzmodels.internal.BuiltInMultiStrideSimulationProvider();
        end
    end
    methods (Access=private)
        function result = simulateDemo(~,request,context)
            context.check(); options = request.Options; speed = 1.3; period = 0.7;
            if isfield(options,'speed'), speed = options.speed; end
            if isfield(options,'stride_period'), period = options.stride_period; end
            time = linspace(0,period,241)'; phase = 2*pi*time/period; x = speed*time;
            y = 0.75+0.04*cos(2*phase); pitch = 0.025*sin(phase);
            offsets = [-0.38,0.38,-0.38,0.38]; phases = [0,pi,pi,0];
            feet = zeros(numel(time),8);
            for leg = 1:4
                legPhase = phase+phases(leg);
                feet(:,2*leg-1) = x+offsets(leg)-0.18*cos(legPhase);
                feet(:,2*leg) = max(0,0.09*sin(legPhase));
            end
            names = {'x','y','body_pitch','foot_bl_x','foot_bl_y', ...
                'foot_fl_x','foot_fl_y','foot_br_x','foot_br_y', ...
                'foot_fr_x','foot_fr_y'};
            specs = lmz.schema.VariableSpec.empty(0,1);
            for index = 1:numel(names), specs(index,1)=lmz.schema.VariableSpec(names{index}); end
            schema = lmz.schema.VariableSchema(specs);
            states = [x,y,pitch,feet];
            contacts = struct('back_left',feet(:,2)==0,'front_left',feet(:,4)==0, ...
                'back_right',feet(:,6)==0,'front_right',feet(:,8)==0);
            observables = struct('vertical_grf',max(0,1.2+0.8*cos(2*phase)));
            result = lmz.api.SimulationResult(time,schema,states,contacts, ...
                observables,struct('speed',speed,'stride_period',period), ...
                struct('source','standalone-analytic-demo'), ...
                struct('modelId','slip_quadruped','problemId','demo_stride'));
            context.progress(1,'SLIP quadruped introductory demonstration simulated.');
        end
    end
end

function value=nStrideConfiguration(model,request,sourceProblemId)
value=request.Options;
problem=model.createProblem(sourceProblemId,struct());
if isa(request.Solution,'lmz.data.Solution')
    value.InitialDecision=request.Solution.DecisionValues;
elseif isfield(value,'decision')
    value.InitialDecision=problem.getDecisionSchema().pack(value.decision);
    value=rmfield(value,'decision');
end
if isfield(value,'parameters')
    error('lmz:MultiStride:FixedSourceParameters', ...
        ['Source-periodic N-stride repetition currently fixes the registered ' ...
        'physical parameters.']);
end
end
