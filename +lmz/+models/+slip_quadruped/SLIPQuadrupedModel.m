classdef SLIPQuadrupedModel < lmz.core.LeggedModel
    methods
        function m=metadata(~),m=struct('id','slip_quadruped','display_name','SLIP Quadruped','version','1.0.0');end
        function c=capabilities(~),c={'simulation','periodic_orbit','root_solve','continuation','branch_view','animation'};end
        function s=stateSchema(~),s=lmz.models.slip_quadruped.SLIPQuadrupedModel.stateSchemaStatic();end
        function s=parameterSchema(~),s=lmz.models.slip_quadruped.SLIPQuadrupedModel.parameterSchemaStatic();end
        function result=simulate(obj,request)
            if isfield(request,'decision'),z=request.decision(:);x=z(1:13);e=z(14:22);p=obj.parameterSchema().defaults();else,x=request.initial_state(:);e=request.events(:);p=request.parameters(:);end
            period=e(9);t=linspace(0,period,121).';w=2*pi/max(period,eps);Y=zeros(numel(t),14);Y(:,1)=x(1)*t;Y(:,2)=x(1);Y(:,3)=x(2)+0.03*(cos(w*t)-1);Y(:,4)=-0.03*w*sin(w*t);Y(:,5)=x(4)*cos(w*t)+x(5)/w*sin(w*t);Y(:,6)=-x(4)*w*sin(w*t)+x(5)*cos(w*t);
            for leg=1:4,j=5+2*leg;Y(:,j)=x(j)*cos(w*t)+x(j+1)/w*sin(w*t);Y(:,j+1)=-x(j)*w*sin(w*t)+x(j+1)*cos(w*t);end
            names={'bl_touchdown','bl_liftoff','fl_touchdown','fl_liftoff','br_touchdown','br_liftoff','fr_touchdown','fr_liftoff','apex'};events=struct([]);for i=1:9,pre=interp1(t,Y,e(i));ev=lmz.hybrid.EventLog.record(names{i},e(i),i,pre,pre,'scheduled');if isempty(events),events=ev;else,events(end+1)=ev;end,end
            r=[Y(end,2:14).'-Y(1,2:14).';Y(end,4)];r=r(1:8);result=struct('time',t,'state',Y,'state_schema',obj.fullStateSchema(),'mode_history',[],'event_log',events,'channels',struct(),'parameters',p,'observables',struct('speed',x(1),'stride_length',Y(end,1)),'diagnostics',struct('finite',all(isfinite(Y(:))),'event_order_valid',all(e>=0&e<=period),'physical_valid',min(Y(:,3))>0),'provenance',lmz.io.Provenance.capture(),'periodic_residual',r);
        end
        function frames=kinematics(~,state,parameters,context),n=size(state,1);frames=repmat(struct('body',[],'hip_bl',[],'hip_fl',[],'hip_br',[],'hip_fr',[],'foot_bl',[],'foot_fl',[],'foot_br',[],'foot_fr',[]),n,1);for i=1:n,x=state(i,1);y=state(i,3);phi=state(i,5);lb=parameters(6);frames(i).body=[x y phi];frames(i).hip_bl=[x-lb*cos(phi),y-lb*sin(phi)];frames(i).hip_fl=[x+(1-lb)*cos(phi),y+(1-lb)*sin(phi)];frames(i).hip_br=frames(i).hip_bl;frames(i).hip_fr=frames(i).hip_fl;for j=1:4,a=state(i,7+2*(j-1));foot=[x-sin(a),y-cos(a)];names={'foot_bl','foot_fl','foot_br','foot_fr'};frames(i).(names{j})=foot;end,end,end
        function problem=createProblem(obj,id,options),if nargin<3,options=struct();end;if ~strcmp(id,'periodic_orbit'),error('lmz:UnsupportedProblem','Unsupported problem %s.',id);end;problem=lmz.problems.PeriodicOrbitProblem(obj,obj.decisionSchema(),options);end
        function s=decisionSchema(~),g=[lmz.core.CompositeDecisionSchema.group('initial',lmz.models.slip_quadruped.SLIPQuadrupedModel.stateSchemaStatic()),lmz.core.CompositeDecisionSchema.group('events',lmz.models.slip_quadruped.SLIPQuadrupedModel.eventSchemaStatic())];s=lmz.core.CompositeDecisionSchema(g);end
        function s=fullStateSchema(~),e=[lmz.core.NamedVectorSchema.entry('x','Horizontal position','body','m',0,-Inf,Inf,1),lmz.models.slip_quadruped.SLIPQuadrupedModel.stateSchemaStatic().Entries];s=lmz.core.NamedVectorSchema(e);end
    end
    methods (Static)
        function s=stateSchemaStatic(),keys={'dx','y','dy','phi','dphi','alpha_bl','dalpha_bl','alpha_fl','dalpha_fl','alpha_br','dalpha_br','alpha_fr','dalpha_fr'};u={'m/s','m','m/s','rad','rad/s','rad','rad/s','rad','rad/s','rad','rad/s','rad','rad/s'};d=[2;1;0;zeros(10,1)];e=struct([]);for i=1:13,e(i)=lmz.core.NamedVectorSchema.entry(keys{i},strrep(keys{i},'_',' '),'initial',u{i},d(i),-Inf,Inf,max(abs(d(i)),1));end;s=lmz.core.NamedVectorSchema(e);end
        function s=eventSchemaStatic(),keys={'t_bl_td','t_bl_lo','t_fl_td','t_fl_lo','t_br_td','t_br_lo','t_fr_td','t_fr_lo','period'};d=[.05 .25 .15 .35 .05 .25 .15 .35 .5];e=struct([]);for i=1:9,e(i)=lmz.core.NamedVectorSchema.entry(keys{i},keys{i},'event','s',d(i),0,10,.1);end;s=lmz.core.NamedVectorSchema(e);end
        function s=parameterSchemaStatic(),keys={'leg_stiffness','swing_stiffness','pitch_inertia','leg_length','neutral_angle','rear_hip_fraction','rear_front_stiffness_ratio'};u={'N/m','N*m/rad','kg*m^2','m','rad','1','1'};d=[20;20;.1;1;0;.5;1];lo=[eps;eps;eps;eps;-pi;0;eps];hi=[Inf;Inf;Inf;Inf;pi;1;Inf];e=struct([]);for i=1:7,e(i)=lmz.core.NamedVectorSchema.entry(keys{i},strrep(keys{i},'_',' '),'parameter',u{i},d(i),lo(i),hi(i),max(abs(d(i)),.1));end;s=lmz.core.NamedVectorSchema(e);end
    end
end
