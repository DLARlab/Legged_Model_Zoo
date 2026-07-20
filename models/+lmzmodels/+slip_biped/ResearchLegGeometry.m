classdef ResearchLegGeometry
    %RESEARCHLEGGEOMETRY Pure source-faithful compound point-foot geometry.
    methods (Static)
        function geometry=compute(x,y,legLength,gamma,side,geometryMode)
            if nargin<6,geometryMode='animated';end
            parts=lmzmodels.slip_biped.ResearchLegGeometry.parts( ...
                x,y,legLength,gamma,side,geometryMode);
            geometry=parts.Layered;
        end

        function value=parts(x,y,legLength,gamma,side,geometryMode)
            if nargin<6,geometryMode='animated';end
            validateScalar(x,'x');validateScalar(y,'y');
            validateScalar(legLength,'leg length');validateScalar(gamma,'leg angle');
            side=validateChoice(side,{'left','right'},'leg side');
            geometryMode=validateChoice(geometryMode, ...
                {'animated','source_constructor'},'geometry mode');
            compression=legLength-1;
            spring1=springGeometry(x,y,compression,gamma,side,1);
            lower=lowerGeometry(x,y,compression,gamma,side,geometryMode);
            spring2=springGeometry(x,y,compression,gamma,side,2);
            upper=upperGeometry(x,y,gamma,side);
            metadata=componentMetadata('compound_leg',side);
            metadata.legLength=legLength;metadata.compression=compression;
            metadata.geometryMode=geometryMode;
            metadata.layerOrder={'spring1','lower','spring2','upper'};
            layered=lmz.viz.LayeredGeometry([side 'Leg'], ...
                {spring1,lower,spring2,upper},metadata);
            value=struct('Spring1',spring1,'Lower',lower, ...
                'Spring2',spring2,'Upper',upper,'Layered',layered, ...
                'Side',side,'LegLength',legLength,'Compression',compression, ...
                'GeometryMode',geometryMode);
        end

        function value=frame(state,eventTimes,time)
            if ~isnumeric(eventTimes)||numel(eventTimes)<5|| ...
                    any(~isfinite(eventTimes(1:5)))
                error('lmz:slip_biped:LegEvents', ...
                    'Event times must contain LTD, LLO, RTD, RLO, and period.');
            end
            validateScalar(time,'frame time');period=eventTimes(5);
            wrapped=lmzmodels.slip_biped.ResearchLegGeometry.wrapEventTimes( ...
                eventTimes(1:4),period);
            contactLeft=lmzmodels.slip_biped.ResearchLegGeometry.contactAt( ...
                time,wrapped(1),wrapped(2));
            contactRight=lmzmodels.slip_biped.ResearchLegGeometry.contactAt( ...
                time,wrapped(3),wrapped(4));
            value=lmzmodels.slip_biped.ResearchLegGeometry.frameFromContacts( ...
                state,contactLeft,contactRight);
            value.EventTimes=[wrapped(:);period];value.Time=time;
        end

        function value=frameFromContacts(state,contactLeft,contactRight)
            [x,y,alphaLeft,alphaRight]=stateValues(state);
            validateLogical(contactLeft,'left contact');
            validateLogical(contactRight,'right contact');
            leftLength=1;rightLength=1;
            if contactLeft,leftLength=y/cos(alphaLeft);end
            if contactRight,rightLength=y/cos(alphaRight);end
            left=lmzmodels.slip_biped.ResearchLegGeometry.parts( ...
                x,y,leftLength,alphaLeft,'left','animated');
            right=lmzmodels.slip_biped.ResearchLegGeometry.parts( ...
                x,y,rightLength,alphaRight,'right','animated');
            value=struct('Left',left,'Right',right, ...
                'Contact',struct('left',contactLeft,'right',contactRight), ...
                'LegLength',[leftLength rightLength], ...
                'BodyCenter',[x y],'Angles',[alphaLeft alphaRight]);
        end

        function wrapped=wrapEventTimes(eventTimes,period)
            if ~isnumeric(eventTimes)||numel(eventTimes)~=4|| ...
                    any(~isfinite(eventTimes(:)))
                error('lmz:slip_biped:LegEvents', ...
                    'Exactly four finite contact-event times are required.');
            end
            validateScalar(period,'stride period');
            if period<=0
                error('lmz:slip_biped:LegPeriod','Stride period must be positive.');
            end
            wrapped=eventTimes(:);
            % Preserve ShowTrajectory_BipedalDemo's exact one-pass wrapping.
            for index=1:4
                if wrapped(index)<0,wrapped(index)=wrapped(index)+period;end
                if wrapped(index)>period,wrapped(index)=wrapped(index)-period;end
            end
        end

        function contact=contactAt(time,touchdown,liftoff)
            validateScalar(time,'frame time');validateScalar(touchdown,'touchdown');
            validateScalar(liftoff,'liftoff');
            contact=(time>touchdown&&time<liftoff&&touchdown<liftoff)|| ...
                ((time<liftoff||time>touchdown)&&touchdown>liftoff);
        end

        function [schedule,available]=scheduleFromSimulation(simulation)
            if ~isa(simulation,'lmz.api.SimulationResult')
                error('lmz:slip_biped:LegSimulation','SimulationResult is required.');
            end
            schedule=zeros(5,1);available=false;records=simulation.EventRecords;
            if isempty(records)||~isfield(records,'Name')||~isfield(records,'Time')
                return
            end
            required={'L_TD','L_LO','R_TD','R_LO','APEX'};
            names=cell(1,numel(records));
            for index=1:numel(records),names{index}=char(records(index).Name);end
            for index=1:5
                match=find(strcmpi(required{index},names),1);
                if isempty(match)||~isnumeric(records(match).Time)|| ...
                        ~isscalar(records(match).Time)||~isfinite(records(match).Time)
                    schedule=zeros(5,1);return
                end
                schedule(index)=records(match).Time;
            end
            if schedule(5)<=0,schedule=zeros(5,1);return,end
            schedule(1:4)=lmzmodels.slip_biped.ResearchLegGeometry.wrapEventTimes( ...
                schedule(1:4),schedule(5));
            available=true;
        end

        function value=provenance()
            value=struct( ...
                'sourceRepository','DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions', ...
                'sourceCommit','4595146c5881a5313bc8fe92de85099193ef9be9', ...
                'sourcePaths',{{ ...
                    'Stored_Functions/Graphics/DrawLegsPointFeet.m', ...
                    'Stored_Functions/Graphics/DrawLegsLeftPointFeet.m', ...
                    'Stored_Functions/Graphics/SetDrawLegsPointFeet.m', ...
                    'Stored_Functions/Graphics/SLIP_Model_Graphics_PointFeet_BipedalDemo.m'}}, ...
                'sourceFunctions','DrawLegsPointFeet_DrawLegsLeftPointFeet_SetDrawLegsPointFeet_update', ...
                'adaptation',['Primary output is the shared post-update formula actually ', ...
                    'used for both legs. source_constructor remains available only to ', ...
                    'measure the transient constructor asymmetry.']);
        end
    end
end

function geometry=springGeometry(x,y,compression,gamma,side,part)
horizontal=zeros(1,15);horizontal(1:2:15)=-0.09;
horizontal(2:2:14)=0.09;
vertical=[-0.4,linspace(-0.4,-0.8-compression,13),-0.8-compression];
if part==1
    local=[horizontal(:),vertical(:)];faces=[(1:14).',(2:15).'];
    name=[side 'Spring1'];component='spring1';
else
    local=[horizontal(1:14).',vertical(1:14).'];
    faces=reshape(1:14,2,7).';name=[side 'Spring2'];component='spring2';
end
metadata=componentMetadata(component,side);metadata.compression=compression;
metadata.styleKey='spring';
geometry=lmz.viz.PatchGeometry(name,transform(local,gamma,x,y),faces,metadata);
end

function geometry=upperGeometry(x,y,gamma,side)
phi=linspace(pi,0,20);
horizontal=[-0.12,-0.12,-0.05,0.05*cos(phi),0.05,0.12,0.12];
vertical=[-0.4,-0.35,-0.35,0.05*sin(phi),-0.35,-0.35,-0.4];
metadata=componentMetadata('upper',side);metadata.styleKey=[side 'Leg'];
geometry=lmz.viz.PatchGeometry([side 'Upper'], ...
    transform([horizontal(:),vertical(:)],gamma,x,y),[26,1:25],metadata);
end

function geometry=lowerGeometry(x,y,compression,gamma,side,geometryMode)
phi1=linspace(pi/2,0,20);phi2=linspace(pi/2,pi/2+2*pi,20);
phi3=linspace(pi,pi/2,10);
if strcmp(geometryMode,'source_constructor')&&strcmp(side,'left')
    width=0.03;top=-0.70;
    endpoints=[top,-0.81];ending=[-0.81,top];
elseif strcmp(geometryMode,'source_constructor')
    width=0.04;top=-0.30;
    endpoints=[top,-0.81];ending=[-0.81,top];
else
    width=0.04;
    endpoints=[-0.30+compression,-0.81];
    ending=[-0.81,-0.30+compression];
end
horizontal=[-width,-width,0.10*cos(phi1)-0.10, ...
    0.01*cos(phi2),0.10*cos(phi3)+0.10,width,width];
vertical=[endpoints,0.19*sin(phi1)-1,0.01*sin(phi2)-1, ...
    0.19*sin(phi3)-1,ending]-compression;
metadata=componentMetadata('lower_point_foot',side);
metadata.compression=compression;metadata.geometryMode=geometryMode;
metadata.pointFootRadius=0.01;metadata.styleKey=[side 'Leg'];
geometry=lmz.viz.PatchGeometry([side 'Lower'], ...
    transform([horizontal(:),vertical(:)],gamma,x,y),1:54,metadata);
end

function vertices=transform(local,gamma,x,y)
rotation=[cos(gamma),-sin(gamma);sin(gamma),cos(gamma)];
vertices=(rotation*local.').'+[x,y];
end

function metadata=componentMetadata(component,side)
metadata=lmzmodels.slip_biped.ResearchLegGeometry.provenance();
metadata.component=component;metadata.side=side;
end

function [x,y,alphaLeft,alphaRight]=stateValues(state)
if isstruct(state)&&isscalar(state)&&all(isfield(state, ...
        {'x','y','alphaL','alphaR'}))
    x=state.x;y=state.y;alphaLeft=state.alphaL;alphaRight=state.alphaR;
elseif isnumeric(state)&&isvector(state)&&numel(state)>=7
    state=state(:);x=state(1);y=state(3);
    alphaLeft=state(5);alphaRight=state(7);
else
    error('lmz:slip_biped:LegState', ...
        'State must expose named x, y, alphaL, and alphaR values.');
end
validateScalar(x,'x');validateScalar(y,'y');
validateScalar(alphaLeft,'left angle');validateScalar(alphaRight,'right angle');
end

function validateScalar(value,description)
if ~isnumeric(value)||~isreal(value)||~isscalar(value)||~isfinite(value)
    error('lmz:slip_biped:LegValue','%s must be a finite scalar.',description);
end
end

function validateLogical(value,description)
if ~islogical(value)||~isscalar(value)
    error('lmz:slip_biped:LegContact','%s must be logical.',description);
end
end

function value=validateChoice(value,allowed,description)
if isstring(value)&&isscalar(value),value=char(value);end
if ~ischar(value)||~any(strcmp(value,allowed))
    error('lmz:slip_biped:LegChoice','Unknown %s.',description);
end
end
