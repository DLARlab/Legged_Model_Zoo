classdef Model < lmz.api.LeggedModel
    methods
        function v=getManifest(~), v=struct('id','slip.quadruped.planar.v2','version','2.0.0'); end
        function v=getCapabilities(~), v=struct('simulate',true,'solve',true,'continue',true,'visualize',true); end
        function v=getPhysicalStateSchema(~), v=[]; end
        function v=getParameterSchema(~), v=[]; end
        function v=listProblems(~), v={'periodic_apex'}; end
        function v=createProblem(~,id,configuration), v=struct('id',id,'configuration',configuration,'status','legacy-adapter-pending'); end
        function v=simulate(~,request,context), context.check(); error('lmz:LegacyUnavailable','Legacy evaluator has not yet been vendored.'); end
        function v=kinematics(~,frame), v=frame; end
        function v=getPlotDescriptors(~), v=struct([]); end
    end
end
