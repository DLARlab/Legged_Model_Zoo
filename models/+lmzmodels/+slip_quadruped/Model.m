classdef Model < lmz.api.LeggedModel
    %MODEL Standalone analytic SLIP quadruped demonstration model.
    methods
        function value = getManifest(~)
            value = struct('id', 'slip_quadruped', 'version', '1.0.0');
        end
        function value = getCapabilities(~)
            value = struct('simulate', true, 'solve', false, ...
                'continue', false, 'optimize', false, 'visualize', true, ...
                'animate', true, 'parameterHomotopy', false, ...
                'branchFamilyScan', false);
        end
        function schema = getPhysicalStateSchema(~)
            names = {'x','y','body_pitch','foot_bl_x','foot_bl_y', ...
                'foot_fl_x','foot_fl_y','foot_br_x','foot_br_y', ...
                'foot_fr_x','foot_fr_y'};
            specs = lmz.schema.VariableSpec.empty(0, 1);
            for index = 1:numel(names)
                specs(index, 1) = lmz.schema.VariableSpec(names{index}); %#ok<AGROW>
            end
            schema = lmz.schema.VariableSchema(specs);
        end
        function schema = getParameterSchema(~)
            schema = lmz.schema.VariableSchema([ ...
                lmz.schema.VariableSpec('speed','DefaultValue',1.3); ...
                lmz.schema.VariableSpec('stride_period','DefaultValue',0.7, ...
                    'LowerBound',0,'Topology','positive')]);
        end
        function value = listProblems(~), value = {'demo_stride'}; end
        function problem = createProblem(obj, problemId, configuration)
            if ~strcmp(problemId,'demo_stride')
                error('lmz:slip_quadruped:UnknownProblem','Unknown problem: %s',problemId);
            end
            problem = lmz.api.SimulationProblem(obj, problemId, configuration);
        end
        function result = simulate(obj, request, context)
            context.check(); options=request.Options;
            speed=1.3; period=0.7;
            if isfield(options,'speed'), speed=options.speed; end
            if isfield(options,'stride_period'), period=options.stride_period; end
            time=linspace(0,period,241)'; phase=2*pi*time/period; x=speed*time;
            y=0.75+0.04*cos(2*phase); pitch=0.025*sin(phase);
            offsets=[-0.38,0.38,-0.38,0.38]; phases=[0,pi,pi,0]; feet=zeros(numel(time),8);
            for leg=1:4
                legPhase=phase+phases(leg); feet(:,2*leg-1)=x+offsets(leg)-0.18*cos(legPhase);
                feet(:,2*leg)=max(0,0.09*sin(legPhase));
            end
            states=[x,y,pitch,feet]; contacts=struct('back_left',feet(:,2)==0, ...
                'front_left',feet(:,4)==0,'back_right',feet(:,6)==0,'front_right',feet(:,8)==0);
            observables=struct('vertical_grf',max(0,1.2+0.8*cos(2*phase)));
            parameters=struct('speed',speed,'stride_period',period);
            result=lmz.api.SimulationResult(time,obj.getPhysicalStateSchema(),states,contacts, ...
                observables,parameters,struct('source','standalone-analytic-demo'), ...
                struct('modelId','slip_quadruped','problemId',request.ProblemId));
            context.progress(1,'SLIP quadruped demonstration simulated.');
        end
        function value=kinematics(~,frame), value=frame; end
        function value=getPlotDescriptors(~)
            value=struct('id',{'trajectory','vertical_grf'},'label',{'Body and feet','Vertical GRF'});
        end
    end
end
