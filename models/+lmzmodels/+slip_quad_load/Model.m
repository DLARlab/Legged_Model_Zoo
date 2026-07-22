classdef Model < lmz.api.LeggedModel
    %MODEL Scientific load-pulling model plus an explicit tutorial stride.
    methods
        function value=getManifest(~),value=struct('id','slip_quad_load','version','2.0.0');end
        function value=getCapabilities(~)
            value=struct('simulate',true,'solve',true,'continue',true, ...
                'optimize',true,'visualize',true,'animate',true, ...
                'parameterHomotopy',false,'branchFamilyScan',false);
        end
        function value=getProblemDescriptors(~)
            common=struct('simulate',true,'solve',false,'continue',false, ...
                'optimize',false,'visualize',true,'animate',true);
            fit=common;fit.optimize=true;
            periodic=common;periodic.solve=true;
            shooting=periodic;shooting.continue=true;
            value=[struct('id','demo_stride','maturity','tutorial', ...
                'validationStatus','tested','capabilities',common), ...
                struct('id','single_stride','maturity','validated', ...
                'validationStatus','source-equivalent','capabilities',common), ...
                struct('id','multi_stride_fit','maturity','validated', ...
                'validationStatus','source-equivalent','capabilities',fit), ...
                struct('id','n_stride_fit','maturity','experimental', ...
                'validationStatus','tested','capabilities',fit), ...
                struct('id','n_stride_simulation','maturity','validated', ...
                'validationStatus','tested','capabilities',common), ...
                struct('id','n_stride_periodic','maturity','experimental', ...
                'validationStatus','tested','capabilities',periodic), ...
                struct('id','multiple_shooting_horizon', ...
                'maturity','experimental','validationStatus','tested', ...
                'capabilities',shooting)];
        end
        function schema=getPhysicalStateSchema(~),schema=lmzmodels.slip_quad_load.PhysicalStateSchema.create();end
        function schema=getParameterSchema(~)
            schema=lmz.schema.VariableSchema([ ...
                lmz.schema.VariableSpec('speed','DefaultValue',.8, ...
                    'Role','control','EnergyEffect','unknown'); ...
                lmz.schema.VariableSpec('stride_period','DefaultValue',.9, ...
                    'LowerBound',0,'Topology','positive','Role','schedule', ...
                    'EnergyEffect','invariant'); ...
                lmz.schema.VariableSpec('rope_length','DefaultValue',.8, ...
                    'LowerBound',0,'Topology','positive','Role','physical', ...
                    'EnergyEffect','state_dependent')]);
        end
        function value=listProblems(~),value={'demo_stride','single_stride', ...
                'multi_stride_fit','section_return_timing', ...
                'n_stride_simulation','n_stride_fit','n_stride_periodic', ...
                'multiple_shooting_horizon'};end
        function problem=createProblem(obj,problemId,configuration)
            if nargin<3,configuration=struct();end
            switch problemId
                case 'demo_stride',problem=lmz.api.SimulationProblem(obj,problemId,configuration);
                case 'single_stride',problem=createSingleStrideProblem(obj,configuration);
                case 'multi_stride_fit',problem=createMultiStrideFitProblem(obj,configuration);
                case 'n_stride_fit'
                    configuration.ProblemId='n_stride_fit';
                    configuration.ObjectiveTimingMode='fixed_precompleted';
                    problem=lmzmodels.slip_quad_load.MultiStrideFitProblem( ...
                        obj,configuration);
                case 'section_return_timing',problem=lmzmodels.slip_quad_load. ...
                        ContactConstraintProvider.createProblem(obj,configuration);
                case 'n_stride_simulation'
                    problem=lmz.multistride.NStrideSimulationProblem( ...
                        obj,multiStrideConfiguration(configuration));
                case 'n_stride_periodic'
                    problem=lmzmodels.slip_quad_load.NStridePeriodicFactory. ...
                        create(obj,configuration);
                case 'multiple_shooting_horizon'
                    configuration.ProblemId=problemId;
                    problem=lmzmodels.slip_quad_load. ...
                        QuadLoadMultipleShootingProblem(obj,configuration);
                otherwise,error('lmz:slip_quad_load:UnknownProblem','Unknown problem: %s',problemId);
            end
        end
        function result=simulate(obj,request,context)
            context.check();
            if strcmp(request.ProblemId,'demo_stride'),result=obj.simulateTutorial(request,context);return,end
            if strcmp(request.ProblemId,'n_stride_simulation')
                configuration=request.Options;
                if isa(request.Solution,'lmz.data.Solution')
                    configuration.InitialDecision=request.Solution.DecisionValues;
                elseif isfield(configuration,'XAccum')
                    configuration.InitialDecision=configuration.XAccum(:);
                    configuration=rmfield(configuration,'XAccum');
                end
                outcome=obj.createProblem(request.ProblemId, ...
                    configuration).simulate(context);
                result=outcome.Simulation;return
            end
            if strcmp(request.ProblemId,'n_stride_periodic')
                problem=obj.createProblem(request.ProblemId,request.Options);
                decision=problem.getDecisionSchema().defaults();
                parameters=problem.getParameterSchema().defaults();
                if isa(request.Solution,'lmz.data.Solution')
                    decision=request.Solution.DecisionValues;
                    parameters=request.Solution.ParameterValues;
                elseif isfield(request.Options,'decision')
                    decision=problem.getDecisionSchema().pack( ...
                        request.Options.decision);
                    if isfield(request.Options,'parameters')
                        parameters=problem.getParameterSchema().pack( ...
                            request.Options.parameters);
                    end
                end
                result=problem.evaluate(decision,parameters,context,true).Simulation;
                return
            end
            if strcmp(request.ProblemId,'single_stride')&& ...
                    hasStrideRoutingFields(request.Options)
                configuration=request.Options;
                if isfield(configuration,'XAccum')
                    configuration.InitialDecision=configuration.XAccum(:);
                    configuration=rmfield(configuration,'XAccum');
                elseif isa(request.Solution,'lmz.data.Solution')
                    configuration.InitialDecision= ...
                        request.Solution.DecisionValues;
                end
                problem=obj.createProblem('single_stride',configuration);
                if isa(problem,'lmz.multistride.NStrideSimulationProblem')
                    outcome=problem.simulate(context);result=outcome.Simulation;
                else
                    result=problem.simulateDecision( ...
                        problem.getDecisionSchema().defaults(),context);
                end
                return
            end
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
        function value=getMultiStrideProvider(~)
            value=lmzmodels.internal.BuiltInMultiStrideSimulationProvider();
        end
        function value=getShootingInitializerDescriptors(~,problemId)
            if ~strcmp(problemId,'multiple_shooting_horizon')
                value=struct('Id','schema_defaults', ...
                    'Label','Schema defaults','IsDefault',true);
                return
            end
            value=struct( ...
                'Id',{'individual_1_tr_to_rl', ...
                    'individual_1_identical_tr_to_rl', ...
                    'individual_1_tr_to_tl','individual_1_tr_single'}, ...
                'Label',{'TR to RL source horizon', ...
                    'Identical TR to RL source horizon', ...
                    'TR to TL source horizon','Single-stride TR source'}, ...
                'IsDefault',{true,false,false,false});
        end
        function rendered=renderOptimizationDiagnostics(obj, ...
                sensitivityAxes,r2Axes,result)
            try
                problem=obj.createProblem('multi_stride_fit',struct());
                lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                    plotSensitivity(sensitivityAxes, ...
                    problem.Dataset.SensitivityStudyData);
                diagnostics=result.Provenance.diagnostics;
                lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                    plotR2(r2Axes,diagnostics.R2);
                rendered=true;
            catch
                rendered=false;
            end
        end
        function plotSimulation(~,axesMap,simulation,profile)
            %PLOTSIMULATION Select source-derived or clean plotting behavior
            % through the current visualization profile.
            lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotBodyAndLegs(axesMap.Torso,simulation,profile);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotLoad(axesMap.Back,simulation,profile);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotFootfall(axesMap.Front,simulation,[],profile);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotGRF(axesMap.Forces,simulation,profile);
            lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotTugline(axesMap.Auxiliary,simulation,[],profile);
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

function value=multiStrideConfiguration(value)
if isfield(value,'InitialDecision')||isfield(value,'StridePlan')
    return
end
catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset( ...
    catalog.defaultMultiPath());
value.InitialDecision=dataset.XAccum;
end

function problem=createSingleStrideProblem(model,configuration)
[configuration,count]=normalizeStrideConfiguration(configuration,1);
if count==1
    if isfield(configuration,'StridePlan')&&~isempty(configuration.StridePlan)
        configuration.InitialDecision= ...
            lmzmodels.slip_quad_load.XAccumPlanAdapter.encode( ...
            configuration.StridePlan);
        configuration=rmfield(configuration,'StridePlan');
    end
    problem=lmzmodels.slip_quad_load.SingleStrideProblem( ...
        model,configuration);
    return
end
if ~isfield(configuration,'InitialDecision')&& ...
        ~isfield(configuration,'StridePlan')&&isfield(configuration,'DatasetPath')
    dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset( ...
        configuration.DatasetPath);
    configuration.InitialDecision=dataset.XAccum;
end
configuration=simulationConfiguration(configuration);
problem=lmz.multistride.NStrideSimulationProblem( ...
    model,multiStrideConfiguration(configuration));
end

function problem=createMultiStrideFitProblem(model,configuration)
generalized=isfield(configuration,'NumberOfStrides')|| ...
    (isfield(configuration,'StridePlan')&&~isempty(configuration.StridePlan))|| ...
    (isfield(configuration,'InitialDecision')&& ...
    ~isempty(configuration.InitialDecision));
if generalized
    [configuration,~]=normalizeStrideConfiguration(configuration,2);
    configuration.ProblemId='n_stride_fit';
    configuration.ObjectiveTimingMode='fixed_precompleted';
end
problem=lmzmodels.slip_quad_load.MultiStrideFitProblem(model,configuration);
end

function [configuration,requested]=normalizeStrideConfiguration( ...
        configuration,defaultCount)
if ~isstruct(configuration)||~isscalar(configuration)
    error('lmz:MultiStride:SimulationConfiguration', ...
        'Stride configuration must be a scalar struct.');
end
hasPlan=isfield(configuration,'StridePlan')&& ...
    ~isempty(configuration.StridePlan);
hasDecision=isfield(configuration,'InitialDecision')&& ...
    ~isempty(configuration.InitialDecision);
if hasPlan&&hasDecision
    error('lmz:MultiStride:AmbiguousInput', ...
        'Specify StridePlan or InitialDecision, not both.');
end
available=0;inferred=defaultCount;source='none';originalLength=0;
if hasPlan
    plan=configuration.StridePlan;
    if ~isa(plan,'lmz.multistride.StridePlan')||~isscalar(plan)|| ...
            ~strcmp(plan.ModelId,'slip_quad_load')
        error('lmz:MultiStride:PlanModel', ...
            'StridePlan must be a scalar slip_quad_load plan.');
    end
    available=plan.CompletedStrideCount;
    inferred=plan.RequestedStrideCount;source='StridePlan';
    originalLength=xAccumLength(available);
elseif hasDecision
    configuration.InitialDecision= ...
        lmzmodels.slip_quad_load.XAccumAdapter.encode( ...
        configuration.InitialDecision);
    available=lmzmodels.slip_quad_load.XAccumAdapter.strideCount( ...
        configuration.InitialDecision);
    inferred=available;source='InitialDecision';
    originalLength=numel(configuration.InitialDecision);
end
if isfield(configuration,'NumberOfStrides')
    requested=configuration.NumberOfStrides;
    validateStrideCount(requested);
else
    requested=inferred;
    configuration.NumberOfStrides=requested;
end
truncatePlan=hasPlan&&requested<=available&& ...
    (requested<available||configuration.StridePlan.RequestedStrideCount~=requested);
truncateDecision=hasDecision&&requested<available;
if truncatePlan
    originalRequested=configuration.StridePlan.RequestedStrideCount;
    configuration.StridePlan=configuration.StridePlan.truncate(requested);
    diagnostics=truncationDiagnostics(source,available,requested, ...
        originalLength,xAccumLength(requested));
    diagnostics.OriginalRequestedStrideCount=originalRequested;
    configuration=recordTruncation(configuration,diagnostics);
elseif truncateDecision
    [configuration.InitialDecision,diagnostics]= ...
        lmzmodels.slip_quad_load.XAccumPlanAdapter.truncate( ...
        configuration.InitialDecision,requested);
    diagnostics.Source=source;
    configuration=recordTruncation(configuration,diagnostics);
end
end

function configuration=recordTruncation(configuration,diagnostics)
configuration.InputTruncationDiagnostics=diagnostics;
provenance=struct();
if isfield(configuration,'Provenance')&&isstruct(configuration.Provenance)
    provenance=configuration.Provenance;
end
provenance.InputTruncation=diagnostics;
configuration.Provenance=provenance;
end

function value=simulationConfiguration(value)
if isfield(value,'DatasetPath'),value=rmfield(value,'DatasetPath');end
if isfield(value,'InputTruncationDiagnostics')
    value=rmfield(value,'InputTruncationDiagnostics');
end
end

function value=truncationDiagnostics(source,original,retained, ...
        originalLength,retainedLength)
value=struct('Source',source,'OriginalStrideCount',original, ...
    'RetainedStrideCount',retained,'OriginalLength',originalLength, ...
    'RetainedLength',retainedLength,'ExplicitTruncation',true);
end

function value=xAccumLength(count)
if count<1,value=0;else,value=44+13*(count-1);end
end

function validateStrideCount(value)
if ~isnumeric(value)||~isreal(value)||~isscalar(value)|| ...
        ~isfinite(value)||value<1||value~=fix(value)
    error('lmz:MultiStride:StrideCount', ...
        'NumberOfStrides must be a positive integer.');
end
end

function value=hasStrideRoutingFields(configuration)
value=any(isfield(configuration,{'NumberOfStrides','StridePlan', ...
    'InitialDecision','XAccum'}));
end
