classdef Model < lmz.api.LeggedModel
    methods
        function v=getManifest(~), v=struct('id','slip.quadruped.load','version','1.0.0'); end
        function v=getCapabilities(~), v=struct('simulate',false,'solve',false,'optimize',false); end
        function v=getPhysicalStateSchema(~), v=[]; end
        function v=getParameterSchema(~), v=[]; end
        function v=listProblems(~), v={'single_stride_periodic','multi_stride_fit'}; end
        function v=createProblem(~,id,c), v=struct('id',id,'configuration',c,'status','not-migrated'); end
        function v=simulate(~,~,~), error('lmz:NotMigrated','Load simulation is not migrated.'); end
        function v=kinematics(~,f), v=f; end
        function v=getPlotDescriptors(~), v=struct([]); end
    end
end
