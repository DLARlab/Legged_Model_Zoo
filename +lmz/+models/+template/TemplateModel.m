classdef TemplateModel < lmz.core.LeggedModel
    methods
        function m=metadata(~),m=struct('id','template','display_name','Authoring Template','version','1.0.0');end
        function c=capabilities(~),c={'simulation'};end
        function s=stateSchema(~),s=lmz.core.NamedVectorSchema(lmz.core.NamedVectorSchema.entry('height','Height','body','m',1,0,Inf,1));end
        function s=parameterSchema(~),s=lmz.core.NamedVectorSchema(lmz.core.NamedVectorSchema.entry('gravity','Gravity','environment','m/s^2',9.81,eps,Inf,9.81));end
        function r=simulate(obj,q),t=linspace(0,1,11).';r=struct('time',t,'state',ones(size(t)),'state_schema',obj.stateSchema(),'mode_history',[],'event_log',struct([]),'channels',struct(),'parameters',obj.parameterSchema().defaults(),'observables',struct(),'diagnostics',struct('finite',true,'event_order_valid',true),'provenance',lmz.io.Provenance.capture());end
        function f=kinematics(~,state,parameters,context),f=struct('body',[0 state(1) 0]);end
        function p=createProblem(~,id,options),error('lmz:UnsupportedProblem','Template has no numerical problem.');end
    end
end
