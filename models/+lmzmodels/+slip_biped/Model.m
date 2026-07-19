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
            value={'periodic_apex','trajectory_fit','demo_stride'};
        end
        function problem=createProblem(obj,problemId,configuration)
            if nargin<3,configuration=struct();end
            switch problemId
                case 'periodic_apex'
                    problem=lmzmodels.slip_biped.PeriodicApexProblem(obj,configuration);
                case 'trajectory_fit'
                    problem=lmzmodels.slip_biped.TrajectoryFitProblem(obj,configuration);
                case 'demo_stride'
                    problem=lmz.api.SimulationProblem(obj,problemId,configuration);
                otherwise
                    error('lmz:slip_biped:UnknownProblem','Unknown problem: %s',problemId);
            end
        end
        function result=simulate(obj,request,context)
            switch request.ProblemId
                case 'periodic_apex'
                    problem=obj.createProblem('periodic_apex',struct());
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
            value=struct('id',{'trajectory','states','ground_reaction_force','footfall'}, ...
                'label',{'Body and legs','State trajectories','Ground reaction force', ...
                'Footfall phases'});
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
