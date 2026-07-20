classdef TrajectoryFitProblem < lmz.api.OptimizationProblem
    %TRAJECTORYFITPROBLEM Source-equivalent 16-variable jerboa trajectory fit.
    properties (SetAccess=private)
        Dataset
        DatasetPath
        Evaluator
        EnforceConstraints
        ObjectiveFormulation
    end
    methods
        function obj=TrajectoryFitProblem(model,configuration)
            if nargin<2,configuration=struct();end
            decision=lmzmodels.slip_biped.TrajectoryFitDecisionSchema.create();
            enforceConstraints=false;
            if isfield(configuration,'EnforceConstraints')
                enforceConstraints=logical(configuration.EnforceConstraints);
            end
            if enforceConstraints
                defaultWeights=[5;50;10;10;0;0];
                objectiveFormulation='source-fmc_cost_fun';
            else
                defaultWeights=[5;50;20;20;100;100];
                objectiveFormulation='source-fms_cost_fun';
            end
            parameterSchema=lmz.schema.VariableSchema([ ...
                lmz.schema.VariableSpec('weight_position','DefaultValue',defaultWeights(1),'LowerBound',0); ...
                lmz.schema.VariableSpec('weight_height','DefaultValue',defaultWeights(2),'LowerBound',0); ...
                lmz.schema.VariableSpec('weight_left_angle','DefaultValue',defaultWeights(3),'LowerBound',0); ...
                lmz.schema.VariableSpec('weight_right_angle','DefaultValue',defaultWeights(4),'LowerBound',0); ...
                lmz.schema.VariableSpec('weight_residual','DefaultValue',defaultWeights(5),'LowerBound',0); ...
                lmz.schema.VariableSpec('weight_event_timing','DefaultValue',defaultWeights(6),'LowerBound',0)],'1.0.0');
            obj@lmz.api.OptimizationProblem(model,'trajectory_fit','optimization', ...
                decision,parameterSchema,parameterSchema.defaults(),configuration);
            obj.Version='2.0.0';obj.Evaluator=lmzmodels.slip_biped.LegacyBipedEvaluator();
            defaultPath=fullfile(lmz.util.ProjectPaths.examples(),'data','slip_biped', ...
                'trajectory_fit','exp_1802_j30.mat');
            if isfield(configuration,'DatasetPath'),defaultPath=configuration.DatasetPath;end
            obj.DatasetPath=defaultPath;obj.Dataset=obj.loadDataset(defaultPath);
            obj.EnforceConstraints=enforceConstraints;
            obj.ObjectiveFormulation=objectiveFormulation;
        end
        function [value,terms,diagnostics]=evaluateObjective(obj,u,p,context)
            context.check();obj.ParameterSchema.validateVector(p);
            u=obj.optimizationCandidate(u);
            warningState=warning('query','MATLAB:ode45:IntegrationTolNotMet');
            warning('off','MATLAB:ode45:IntegrationTolNotMet');
            warningCleanup=onCleanup(@()warning(warningState));
            try
                raw=obj.Evaluator.evaluate(u(1:12),u(15:16),context, ...
                    struct('k_leg',u(13),'omega_swing',u(14)));
                if numel(raw.LegacyTime)<2||any(~isfinite(raw.LegacyStates(:)))
                    error('lmz:slip_biped:FitIntegration','Fit integration did not complete.');
                end
                simulated=obj.resample(raw.LegacyTime,raw.LegacyStates,obj.Dataset.To);
            catch exception
                if strcmp(exception.identifier,'lmz:Cancelled'),rethrow(exception),end
                [value,terms,diagnostics]=obj.invalidTrial(u,exception);return
            end
            observed=obj.Dataset.ob_data;
            norms=struct('position',norm(simulated.x-observed(:,1)), ...
                'height',norm(simulated.y-observed(:,3)), ...
                'left_angle',norm(simulated.alphaL-observed(:,5)), ...
                'right_angle',norm(simulated.alphaR-observed(:,7)), ...
                'residual',norm(raw.ScaledResidual), ...
                ... % Preserve source row-minus-column implicit expansion.
                'event_timing',norm([obj.Dataset.footsequence(:).' obj.Dataset.To(end)]-u(8:12)));
            terms=struct('position_mismatch',p(1)*norms.position, ...
                'height_mismatch',p(2)*norms.height, ...
                'left_leg_angle_mismatch',p(3)*norms.left_angle, ...
                'right_leg_angle_mismatch',p(4)*norms.right_angle, ...
                'periodic_residual_penalty',p(5)*norms.residual, ...
                'event_timing_penalty',p(6)*norms.event_timing);
            value=sum(cell2mat(struct2cell(terms)));
            diagnostics=struct('LegacyEquivalent',true, ...
                'ObjectiveFormulation',obj.ObjectiveFormulation, ...
                'DatasetPath',obj.DatasetPath,'DatasetId','exp_1802_j30', ...
                'UnweightedNorms',norms,'ScaledResidual',raw.ScaledResidual, ...
                'UnscaledResidual',raw.Residual,'ConstraintResidual',raw.ScaledResidual, ...
                'Simulation',simulated,'Energy',raw.Energy, ...
                'TimingNormShape',[5 5], ...
                'SourceCommit','4595146c5881a5313bc8fe92de85099193ef9be9');
            clear warningCleanup
        end
        function names=objectiveTerms(~)
            names={'position_mismatch','height_mismatch','left_leg_angle_mismatch', ...
                'right_leg_angle_mismatch','periodic_residual_penalty','event_timing_penalty'};
        end
        function [c,ceq]=nonlinearConstraints(obj,u,~,context)
            context.check();
            if ~obj.EnforceConstraints,c=[];ceq=[];return,end
            u=obj.optimizationCandidate(u);
            warningState=warning('query','MATLAB:ode45:IntegrationTolNotMet');
            warning('off','MATLAB:ode45:IntegrationTolNotMet');
            warningCleanup=onCleanup(@()warning(warningState));
            try
                raw=obj.Evaluator.evaluate(u(1:12),u(15:16),context, ...
                    struct('k_leg',u(13),'omega_swing',u(14)));
                if numel(raw.LegacyTime)<2||any(~isfinite(raw.ScaledResidual))
                    error('lmz:slip_biped:FitIntegration','Constraint integration did not complete.');
                end
                c=[];ceq=raw.ScaledResidual;
            catch exception
                if strcmp(exception.identifier,'lmz:Cancelled'),rethrow(exception),end
                c=[];ceq=1e3*ones(15,1);
            end
            clear warningCleanup
        end
        function result=simulateDecision(obj,u,context)
            context.check();obj.DecisionSchema.validateVector(u);
            raw=obj.Evaluator.evaluate(u(1:12),u(15:16),context, ...
                struct('k_leg',u(13),'omega_swing',u(14)));
            observables=lmzmodels.slip_biped.ObservableProvider.compute( ...
                raw.Time,raw.States,u(1:12),raw,'trajectory fit');
            parameters=struct('offset_left',u(15),'offset_right',u(16), ...
                'k_leg',u(13),'omega_swing',u(14));
            result=lmz.api.SimulationResult(raw.Time, ...
                lmzmodels.slip_biped.PhysicalStateSchema.create(),raw.States,raw.Modes, ...
                observables,parameters,struct('Evaluator', ...
                'migrated-ZeroFunc_BipedApex_offset_optimization', ...
                'DuplicateSamplesRemoved',raw.DuplicateSamplesRemoved, ...
                'HiddenEventTimeSolve',false,'Energy',raw.Energy), ...
                struct('sourceRepository','DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions', ...
                'sourceCommit','4595146c5881a5313bc8fe92de85099193ef9be9'), ...
                'EventRecords',raw.EventRecords,'GroundReactionForces',raw.GroundReactionForces);
            kinematics=lmzmodels.slip_biped.KinematicsProvider.compute(result);
            result=lmz.api.SimulationResult(result.Time,result.StateSchema,result.States, ...
                result.Modes,result.Observables,result.Parameters,result.Diagnostics, ...
                result.Provenance,'EventRecords',result.EventRecords, ...
                'GroundReactionForces',result.GroundReactionForces,'Kinematics',kinematics);
        end
        function value=sourceSeed(obj)
            seedPath=fullfile(fileparts(obj.DatasetPath),'sim_1802_j30.mat');
            loaded=lmz.io.SafeMat.loadVariables(seedPath,{'X'});
            if ~isfield(loaded,'X')||numel(loaded.X)~=16
                error('lmz:slip_biped:FitSeed','Source fit seed is missing or invalid.');
            end
            value=loaded.X(:);
        end
    end
    methods (Static)
        function value=resample(time,states,observationTime)
            fields={'x','y','alphaL','alphaR'};columns=[1 3 5 7];
            value=struct();query=observationTime(:);
            for index=1:numel(fields)
                output=states(:,columns(index));
                [~,keep]=unique(output);
                value.(fields{index})=interp1(time(keep),output(keep),query,'linear','extrap');
            end
            value.time=query;
        end
    end
    methods (Static, Access=private)
        function dataset=loadDataset(path)
            if exist(path,'file')~=2
                error('lmz:slip_biped:FitDataset','Trajectory-fit dataset is missing: %s',path);
            end
            variables=whos('-file',path);names={variables.name};
            loaded=lmz.io.SafeMat.loadVariables(path,names);
            required={'To','footsequence','ob_data'};
            for index=1:numel(required)
                if ~isfield(loaded,required{index})
                    error('lmz:slip_biped:FitDataset','Dataset is missing %s.',required{index});
                end
            end
            if size(loaded.ob_data,2)~=8 || numel(loaded.To)~=size(loaded.ob_data,1) || ...
                    numel(loaded.footsequence)~=4
                error('lmz:slip_biped:FitDataset','Trajectory-fit dataset dimensions are invalid.');
            end
            dataset=struct('To',loaded.To(:),'footsequence',loaded.footsequence(:), ...
                'ob_data',loaded.ob_data,'Source_Video','');
            if isfield(loaded,'Source_Video'),dataset.Source_Video=loaded.Source_Video;end
        end
    end
    methods (Access=private)
        function value=optimizationCandidate(obj,value)
            if ~isnumeric(value)||numel(value)~=16||any(~isfinite(value(:)))
                error('lmz:slip_biped:FitDecision','Fit decision must contain 16 finite values.');
            end
            value=value(:);[lower,upper]=obj.bounds();
            % fmincon can request roundoff-level trial points beyond a bound.
            % Clamp only those internal trials; public simulation remains strict.
            value=max(lower(:),min(upper(:),value));
        end
        function [value,terms,diagnostics]=invalidTrial(obj,u,exception)
            center=obj.DecisionSchema.defaults();scale=obj.scale(u);
            value=1e8+1e4*sum(((u-center)./scale(:)).^2);
            terms=struct('position_mismatch',0,'height_mismatch',0, ...
                'left_leg_angle_mismatch',0,'right_leg_angle_mismatch',0, ...
                'periodic_residual_penalty',value,'event_timing_penalty',0);
            diagnostics=struct('LegacyEquivalent',true,'InvalidTrial',true, ...
                'FailureIdentifier',exception.identifier,'FailureMessage',exception.message, ...
                'DatasetPath',obj.DatasetPath);
        end
    end
end
