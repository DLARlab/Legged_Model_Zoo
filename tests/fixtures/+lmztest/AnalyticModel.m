classdef AnalyticModel < lmz.api.LeggedModel
    %ANALYTICMODEL Minimal deterministic model used by continuation tests.
    methods
        function value=getManifest(~)
            value=struct('id','analytic_test','version','1.0.0');
        end
        function value=getCapabilities(~)
            value=struct('simulate',false,'solve',true,'continue',true, ...
                'optimize',false,'visualize',false,'animate',false, ...
                'parameterHomotopy',false,'branchFamilyScan',false);
        end
        function value=getPhysicalStateSchema(~)
            value=lmz.schema.VariableSchema();
        end
        function value=getParameterSchema(~)
            value=lmz.schema.VariableSchema();
        end
        function value=listProblems(~),value={'line'};end
        function value=createProblem(obj,id,configuration)
            if ~strcmp(id,'line'),error('lmztest:UnknownProblem','Unknown test problem.');end
            value=lmztest.AnalyticContinuationProblem(obj,configuration);
        end
        function value=simulate(~,varargin) %#ok<STOUT,INUSD>
            error('lmztest:NoSimulation','The analytic test model does not simulate.');
        end
        function value=kinematics(~,frame),value=frame;end
        function value=getPlotDescriptors(~),value=struct([]);end
    end
end
