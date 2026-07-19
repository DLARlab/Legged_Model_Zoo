classdef Model < lmz.api.LeggedModel
    %MODEL Standalone analytic load-pulling quadruped demonstration.
    methods
        function value=getManifest(~), value=struct('id','slip_quad_load','version','1.0.0'); end
        function value=getCapabilities(~)
            value=struct('simulate',true,'solve',false,'continue',false, ...
                'optimize',false,'visualize',true,'animate',true, ...
                'parameterHomotopy',false,'branchFamilyScan',false);
        end
        function schema=getPhysicalStateSchema(~)
            names={'quad_x','quad_y','body_pitch','load_x','load_y'};
            specs=lmz.schema.VariableSpec.empty(0,1);
            for index=1:numel(names), specs(index,1)=lmz.schema.VariableSpec(names{index}); end
            schema=lmz.schema.VariableSchema(specs);
        end
        function schema=getParameterSchema(~)
            schema=lmz.schema.VariableSchema([lmz.schema.VariableSpec('speed','DefaultValue',0.8); ...
                lmz.schema.VariableSpec('stride_period','DefaultValue',0.9,'LowerBound',0,'Topology','positive'); ...
                lmz.schema.VariableSpec('rope_length','DefaultValue',0.8,'LowerBound',0,'Topology','positive')]);
        end
        function value=listProblems(~), value={'demo_stride'}; end
        function problem=createProblem(obj,problemId,configuration)
            if ~strcmp(problemId,'demo_stride'), error('lmz:slip_quad_load:UnknownProblem','Unknown problem: %s',problemId); end
            problem=lmz.api.SimulationProblem(obj,problemId,configuration);
        end
        function result=simulate(obj,request,context)
            context.check(); options=request.Options; speed=0.8; period=0.9; rope=0.8;
            if isfield(options,'speed'), speed=options.speed; end
            if isfield(options,'stride_period'), period=options.stride_period; end
            if isfield(options,'rope_length'), rope=options.rope_length; end
            time=linspace(0,period,241)'; phase=2*pi*time/period; x=speed*time;
            quadY=0.72+0.035*cos(2*phase); pitch=0.02*sin(phase);
            loadX=x-rope-0.03*sin(phase); loadY=0.25+0*time;
            states=[x,quadY,pitch,loadX,loadY];
            observables=struct('tugline_force',max(0,0.8+0.35*sin(phase)), ...
                'vertical_grf',max(0,1.5+0.7*cos(2*phase)));
            parameters=struct('speed',speed,'stride_period',period,'rope_length',rope);
            result=lmz.api.SimulationResult(time,obj.getPhysicalStateSchema(),states,struct(), ...
                observables,parameters,struct('source','standalone-analytic-demo'), ...
                struct('modelId','slip_quad_load','problemId',request.ProblemId));
            context.progress(1,'SLIP quadruped-with-load demonstration simulated.');
        end
        function value=kinematics(~,frame), value=frame; end
        function value=getPlotDescriptors(~)
            value=struct('id',{'trajectory','tugline_force'},'label',{'Quadruped and load','Tugline force'});
        end
    end
end
