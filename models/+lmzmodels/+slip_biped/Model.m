classdef Model < lmz.api.LeggedModel
    %MODEL Scientific SLIP biped migration plus introductory demo.
    methods
        function value=getManifest(~)
            value=struct('id','slip_biped','version','2.0.0');
        end
        function value=getCapabilities(~)
            value=struct('simulate',true,'solve',true,'continue',true, ...
                'optimize',true,'visualize',true,'animate',true, ...
                'parameterHomotopy',false,'branchFamilyScan',false, ...
                'scientificGaitMap',true,'legacyResults14',true, ...
                'sourceEquivalentTrajectoryFit',true);
        end
        function schema=getPhysicalStateSchema(~)
            schema=lmzmodels.slip_biped.PhysicalStateSchema.create();
        end
        function schema=getParameterSchema(~)
            schema=lmzmodels.slip_biped.OffsetParameterSchema.create();
        end
        function value=listProblems(~)
            value={'periodic_apex','periodic_orbit','trajectory_fit','demo_stride', ...
                'section_return_timing','multiple_shooting','section_transition', ...
                'n_stride_simulation'};
        end
        function problem=createProblem(obj,problemId,configuration)
            if nargin<3,configuration=struct();end
            switch problemId
                case 'periodic_apex'
                    problem=lmzmodels.slip_biped.PeriodicApexProblem(obj,configuration);
                case 'periodic_orbit'
                    problem=lmzmodels.slip_biped.PeriodicOrbitProblem( ...
                        obj,configuration);
                case 'trajectory_fit'
                    problem=lmzmodels.slip_biped.TrajectoryFitProblem(obj,configuration);
                case 'demo_stride'
                    problem=lmz.api.SimulationProblem(obj,problemId,configuration);
                case 'section_return_timing'
                    problem=lmzmodels.slip_biped. ...
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
                    error('lmz:slip_biped:UnknownProblem','Unknown problem: %s',problemId);
            end
        end
        function result=simulate(obj,request,context)
            switch request.ProblemId
                case 'n_stride_simulation'
                    configuration=nStrideConfiguration(obj,request, ...
                        'periodic_apex');
                    outcome=obj.createProblem(request.ProblemId, ...
                        configuration).simulate(context);
                    result=outcome.Simulation;
                case {'periodic_apex','periodic_orbit'}
                    problem=obj.createProblem(request.ProblemId,request.Options);
                    [u,p]=lmzmodels.slip_biped.Model.requestValues(problem,request);
                    result=problem.evaluate(u,p,context,true).Simulation;
                    context.progress(1,'Scientific SLIP biped stride simulated.');
                case 'trajectory_fit'
                    problem=obj.createProblem('trajectory_fit',struct());
                    if isa(request.Solution,'lmz.data.Solution')
                        u=request.Solution.DecisionValues;
                    elseif isfield(request.Options,'decision')
                        u=problem.getDecisionSchema().pack(request.Options.decision);
                    else
                        u=problem.getDecisionSchema().defaults();
                    end
                    result=problem.simulateDecision(u,context);
                    context.progress(1,'SLIP biped trajectory-fit candidate simulated.');
                otherwise
                    result=obj.simulateDemo(request,context);
            end
        end
        function value=kinematics(~,frame),value=frame;end
        function value=getPlotDescriptors(~)
            value=struct('id',{'trajectory','states','ground_reaction_force', ...
                'footfall','energy_gait'}, ...
                'label',{'Body and legs','State trajectories','Ground reaction force', ...
                'Footfall phases','Energy and gait'});
        end
        function value=getMultiStrideProvider(~)
            value=lmzmodels.internal.BuiltInMultiStrideSimulationProvider();
        end
        function plotSimulation(~,axesMap,simulation,profile)
            %PLOTSIMULATION Route model-specific research plots without GUI
            % knowledge of the biped state or force channel ordering.
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotBody(axesMap.Torso,simulation,profile);
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotLegs(axesMap.Back,simulation,profile);
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotFootfall(axesMap.Front,simulation,profile);
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotGRF(axesMap.Forces,simulation,profile);
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotEnergyAndGait(axesMap.Auxiliary,simulation,profile);
        end
    end
    methods (Static, Access=private)
        function [u,p]=requestValues(problem,request)
            if isa(request.Solution,'lmz.data.Solution')
                u=request.Solution.DecisionValues;p=request.Solution.ParameterValues;return
            end
            u=problem.getDecisionSchema().defaults();p=problem.getParameterSchema().defaults();
            if isfield(request.Options,'decision')
                u=problem.getDecisionSchema().pack(request.Options.decision);
            end
            if isfield(request.Options,'parameters')
                p=problem.getParameterSchema().pack(request.Options.parameters);
            end
        end
    end
    methods (Access=private)
        function result=simulateDemo(~,request,context)
            context.check();speed=1;period=0.8;
            if isfield(request.Options,'speed'),speed=request.Options.speed;end
            if isfield(request.Options,'stride_period'),period=request.Options.stride_period;end
            time=linspace(0,period,241)';phase=2*pi*time/period;
            x=speed*time;dx=speed*ones(size(time));y=1+0.06*cos(2*phase);
            dy=-0.12*(2*pi/period)*sin(2*phase);
            alphaL=0.3*sin(phase);dalphaL=0.3*(2*pi/period)*cos(phase);
            alphaR=0.3*sin(phase+pi);dalphaR=0.3*(2*pi/period)*cos(phase+pi);
            states=[x,dx,y,dy,alphaL,dalphaL,alphaR,dalphaR];
            modes=struct('left',sin(phase)<=0,'right',sin(phase+pi)<=0,'period',period);
            result=lmz.api.SimulationResult(time, ...
                lmzmodels.slip_biped.PhysicalStateSchema.create(),states,modes, ...
                struct('forward_speed',speed,'stride_period',period), ...
                struct('offset_left',0,'offset_right',0), ...
                struct('source','standalone-analytic-demo'), ...
                struct('modelId','slip_biped','problemId','demo_stride'));
            kinematics=lmzmodels.slip_biped.KinematicsProvider.compute(result);
            result=lmz.api.SimulationResult(result.Time,result.StateSchema,result.States, ...
                result.Modes,result.Observables,result.Parameters,result.Diagnostics, ...
                result.Provenance,'Kinematics',kinematics);
            context.progress(1,'SLIP biped introductory demonstration simulated.');
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
