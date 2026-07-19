classdef Model < lmz.api.LeggedModel
    %MODEL Scientific load-pulling model plus an explicit tutorial stride.
    methods
        function value=getManifest(~),value=struct('id','slip_quad_load','version','2.0.0');end
        function value=getCapabilities(~)
            value=struct('simulate',true,'solve',false,'continue',false, ...
                'optimize',true,'visualize',true,'animate',true, ...
                'parameterHomotopy',false,'branchFamilyScan',false);
        end
        function value=getProblemDescriptors(~)
            common=struct('simulate',true,'solve',false,'continue',false, ...
                'optimize',false,'visualize',true,'animate',true);
            fit=common;fit.optimize=true;
            value=[struct('id','demo_stride','maturity','tutorial', ...
                'validationStatus','tested','capabilities',common), ...
                struct('id','single_stride','maturity','validated', ...
                'validationStatus','source-equivalent','capabilities',common), ...
                struct('id','multi_stride_fit','maturity','validated', ...
                'validationStatus','source-equivalent','capabilities',fit)];
        end
        function schema=getPhysicalStateSchema(~),schema=lmzmodels.slip_quad_load.PhysicalStateSchema.create();end
        function schema=getParameterSchema(~)
            schema=lmz.schema.VariableSchema([lmz.schema.VariableSpec('speed','DefaultValue',.8); ...
                lmz.schema.VariableSpec('stride_period','DefaultValue',.9,'LowerBound',0,'Topology','positive'); ...
                lmz.schema.VariableSpec('rope_length','DefaultValue',.8,'LowerBound',0,'Topology','positive')]);
        end
        function value=listProblems(~),value={'demo_stride','single_stride','multi_stride_fit'};end
        function problem=createProblem(obj,problemId,configuration)
            if nargin<3,configuration=struct();end
            switch problemId
                case 'demo_stride',problem=lmz.api.SimulationProblem(obj,problemId,configuration);
                case 'single_stride',problem=lmzmodels.slip_quad_load.SingleStrideProblem(obj,configuration);
                case 'multi_stride_fit',problem=lmzmodels.slip_quad_load.MultiStrideFitProblem(obj,configuration);
                otherwise,error('lmz:slip_quad_load:UnknownProblem','Unknown problem: %s',problemId);
            end
        end
        function result=simulate(obj,request,context)
            context.check();
            if strcmp(request.ProblemId,'demo_stride'),result=obj.simulateTutorial(request,context);return,end
            problem=obj.createProblem(request.ProblemId,struct());options=request.Options;
            if isa(request.Solution,'lmz.data.Solution')
                decision=request.Solution.DecisionValues;
            elseif isfield(options,'XAccum')
                decision=options.XAccum(:);
            elseif isfield(options,'decision')
                decision=problem.getDecisionSchema().pack(options.decision);
            elseif isstruct(request.Solution)&&isfield(request.Solution,'DecisionValues')
                decision=request.Solution.DecisionValues(:);
            else
                decision=problem.getDecisionSchema().defaults();
            end
            result=problem.simulateDecision(decision,context);
        end
        function value=kinematics(~,frame)
            if isa(frame,'lmz.api.SimulationResult'),value=lmzmodels.slip_quad_load.KinematicsProvider.compute(frame);else,value=frame;end
        end
        function value=getPlotDescriptors(~)
            value=struct('id',{'animation','footfall','body_legs','load','grf','tugline','sensitivity','r2'}, ...
                'label',{'Quadruped and load','Footfall sequence','Body and leg states', ...
                'Load states','Ground reaction force','Tugline force','Sensitivity','R-squared'});
        end
    end
    methods (Access=private)
        function result=simulateTutorial(obj,request,context)
            options=request.Options;speed=fieldOr(options,'speed',.8);period=fieldOr(options,'stride_period',.9);rope=fieldOr(options,'rope_length',.8);
            if isfield(options,'decision'),speed=fieldOr(options.decision,'speed',speed);period=fieldOr(options.decision,'stride_period',period);rope=fieldOr(options.decision,'rope_length',rope);end
            time=linspace(0,period,241).';phase=2*pi*time/period;x=speed*time;y=.72+.035*cos(2*phase);pitch=.02*sin(phase);
            legAngles=[.8+.1*sin(phase),-.8+.1*sin(phase+pi/2),.9+.1*sin(phase+pi),-.9+.1*sin(phase+3*pi/2)];
            legRates=[.1*cos(phase),.1*cos(phase+pi/2),.1*cos(phase+pi),.1*cos(phase+3*pi/2)]*(2*pi/period);
            loadX=x-rope-.03*sin(phase);loadY=.25+0*time;
            states=[x,speed+0*time,y,-.07*(2*pi/period)*sin(2*phase),pitch,.02*(2*pi/period)*cos(phase), ...
                legAngles(:,1),legRates(:,1),legAngles(:,2),legRates(:,2), ...
                legAngles(:,3),legRates(:,3),legAngles(:,4),legRates(:,4),loadX,speed-.03*(2*pi/period)*cos(phase),loadY,0*time];
            modes=struct('back_left',sin(phase)>=0,'front_left',sin(phase+pi/2)>=0, ...
                'back_right',sin(phase+pi)>=0,'front_right',sin(phase+3*pi/2)>=0,'stride_index',ones(size(time)));
            tug=max(0,.8+.35*sin(phase));grf=zeros(numel(time),12);grf(:,1:4)=max(0,.4+.25*[sin(phase) sin(phase+pi/2) sin(phase+pi) sin(phase+3*pi/2)]);grf(:,9:12)=grf(:,1:4);
            observables=struct('tugline_force',tug,'vertical_grf',grf(:,9:12), ...
                'horizontal_grf',grf(:,5:8),'grf_magnitude',grf(:,1:4), ...
                'normalized_stride_time',time/period,'stride_count',1,'stride_durations',period);
            parameters=struct('stride_count',1,'per_stride_parameters',zeros(1,17), ...
                'quadruped',[8;20*ones(8,1);4;1;0;.5;1],'load',[.25;.5;.08;rope;8;0], ...
                'speed',speed,'stride_period',period,'rope_length',rope);
            interim=lmz.api.SimulationResult(time,obj.getPhysicalStateSchema(),states,modes,observables,parameters, ...
                struct('source','standalone-analytic-tutorial'),struct('modelId','slip_quad_load','problemId','demo_stride'), ...
                'GroundReactionForces',grf);kinematics=lmzmodels.slip_quad_load.KinematicsProvider.compute(interim);
            result=lmz.api.SimulationResult(time,interim.StateSchema,states,modes,observables,parameters, ...
                interim.Diagnostics,interim.Provenance,'GroundReactionForces',grf,'Kinematics',kinematics);
            context.progress(1,'SLIP quadruped-with-load tutorial simulated.');
        end
    end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
