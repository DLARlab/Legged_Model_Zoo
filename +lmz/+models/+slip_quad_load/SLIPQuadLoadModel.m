classdef SLIPQuadLoadModel < lmz.models.slip_quadruped.SLIPQuadrupedModel
    methods
        function m=metadata(~),m=struct('id','slip_quad_load','display_name','SLIP Quadruped with Load','version','1.0.0');end
        function c=capabilities(~),c={'simulation','periodic_orbit','trajectory_fit','optimization','footfall_view','force_view','sensitivity_view','animation'};end
        function s=parameterSchema(obj),base=parameterSchema@lmz.models.slip_quadruped.SLIPQuadrupedModel(obj);e=base.Entries;e(end+1)=lmz.core.NamedVectorSchema.entry('rope_stiffness','Rope stiffness','load','N/m',10,eps,Inf,10);e(end+1)=lmz.core.NamedVectorSchema.entry('load_mass','Load mass','load','kg',1,eps,Inf,1);e(end+1)=lmz.core.NamedVectorSchema.entry('rope_length','Rope rest length','load','m',1,eps,Inf,1);s=lmz.core.NamedVectorSchema(e);end
        function result=simulate(obj,request),result=simulate@lmz.models.slip_quadruped.SLIPQuadrupedModel(obj,request);p=obj.parameterSchema().defaults();extension=max(0,result.state(:,1)-p(end));force=p(end-2)*extension;result.parameters=p;result.channels.rope_force=force;result.observables.peak_rope_force=max(force);end
        function f=kinematics(obj,state,parameters,context),f=kinematics@lmz.models.slip_quadruped.SLIPQuadrupedModel(obj,state,parameters(1:7),context);for i=1:numel(f),f(i).load=[state(i,1)-parameters(end),0,0];end,end
        function p=createProblem(obj,id,options),if nargin<3,options=struct();end;if ~any(strcmp(id,{'periodic_orbit','single_stride_fit','multi_stride_fit'})),error('lmz:UnsupportedProblem','Unsupported problem.');end;p=lmz.problems.PeriodicOrbitProblem(obj,obj.decisionSchema(),options);end
    end
end
