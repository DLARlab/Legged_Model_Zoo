function [residual,T,Y,P,Y_EVENT,TE,scaledResidual] = ...
        BipedApex(decision,offsets,k,omega)
%BIPEDAPEX Package-safe adaptation of ZeroFunc_BipedApex_offset.
% Source: DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions,
% commit 4595146c5881a5313bc8fe92de85099193ef9be9. The event ordering,
% touchdown resets, ODE tolerances, dynamics, energy, and 15-entry residual
% intentionally preserve the source. Globals and path dependence are removed.

decision = decision(:); offsets = offsets(:);
if numel(decision) ~= 12 || numel(offsets) ~= 2
    error('lmz:slip_biped:EvaluatorInput', ...
        'BipedApex requires 12 decisions and two offsets.');
end
if nargin < 3 || isempty(k), k = 20; end
if nargin < 4 || isempty(omega), omega = 6.5; end

offsetL = offsets(1); offsetR = offsets(2);
x0 = 0; dx0 = decision(1); y0 = decision(2); dy0 = decision(3);
alphaL0 = decision(4); dalphaL0 = decision(5);
alphaR0 = decision(6); dalphaR0 = decision(7);
tAPEX = decision(12);
if ~isfinite(tAPEX) || tAPEX <= 0
    error('lmz:slip_biped:InvalidPeriod','tAPEX must be positive.');
end
timing = zeros(4,1);
for timingIndex=1:4
    timing(timingIndex)=sourceWrap(decision(7+timingIndex),tAPEX);
end
tL_TD = timing(1); tL_LO = timing(2);
tR_TD = timing(3); tR_LO = timing(4);

T_START = 0;
Y_START = [x0,dx0,y0,dy0,alphaL0,dalphaL0,alphaR0,dalphaR0];
[tEVENT,iEVENT] = sort([timing(:);tAPEX]);
T = []; Y = []; Y_EVENT = zeros(5,8);
contactL = false; contactR = false;
for eventIndex = 1:5
    midpoint = (T_START+tEVENT(eventIndex))/2;
    contactL = inContact(midpoint,tL_TD,tL_LO);
    contactR = inContact(midpoint,tR_TD,tR_LO);
    options = odeset('RelTol',1e-12,'AbsTol',1e-12);
    if abs(T_START-tEVENT(eventIndex)) < 1e-12
        T_PART = T_START; Y_PART = Y_START;
    else
        [T_PART,Y_PART] = ode45(@dynamics,[T_START,tEVENT(eventIndex)], ...
            Y_START,options);
    end
    if iEVENT(eventIndex) == 1
        T_PART = [T_PART;T_PART(end)]; %#ok<AGROW>
        Y_PART = [Y_PART;Y_PART(end,:)]; %#ok<AGROW>
        Y_PART(end,6) = -(Y_PART(end,2)+Y_PART(end,4)*tan(Y_PART(end,5))) / ...
            (Y_PART(end,3)*(tan(Y_PART(end,5))^2+1));
    elseif iEVENT(eventIndex) == 3
        T_PART = [T_PART;T_PART(end)]; %#ok<AGROW>
        Y_PART = [Y_PART;Y_PART(end,:)]; %#ok<AGROW>
        Y_PART(end,8) = -(Y_PART(end,2)+Y_PART(end,4)*tan(Y_PART(end,7))) / ...
            (Y_PART(end,3)*(tan(Y_PART(end,7))^2+1));
    end
    T = [T;T_PART]; %#ok<AGROW>
    Y = [Y;Y_PART]; %#ok<AGROW>
    Y_EVENT(iEVENT(eventIndex),:) = Y(end,:);
    T_START = T(end); Y_START = Y(end,:);
end

YL_TD = Y_EVENT(1,:)'; YL_LO = Y_EVENT(2,:)';
YR_TD = Y_EVENT(3,:)'; YR_LO = Y_EVENT(4,:)'; YAPEX = Y_EVENT(5,:)';
residual = zeros(15,1);
residual(1:7) = Y(1,2:8).'-YAPEX(2:8);
residual(8) = YL_TD(3)-cos(YL_TD(5));
residual(9) = YR_TD(3)-cos(YR_TD(7));
residual(10) = YL_LO(3)-cos(YL_LO(5));
residual(11) = YR_LO(3)-cos(YR_LO(7));
% Entry 12 is structurally reserved and is exactly zero in the source.
residual(13) = YL_TD(5)+YR_LO(7);
residual(14) = YR_TD(7)+YL_LO(5);
residual(15) = YAPEX(4);
scales = [44;1000;1;50;20;50;20;1;1;1;1;1;20;20;1];
scaledResidual = residual./scales;
P = [tL_TD,tL_LO,tR_TD,tR_LO,tAPEX,k,omega];
dll = 0; dlr = 0;
if contactL, dll = 1-YAPEX(3)/cos(YAPEX(5)); end
if contactR, dlr = 1-YAPEX(3)/cos(YAPEX(7)); end
TE = 0.5*(YAPEX(2)^2+YAPEX(4)^2)+YAPEX(3)+0.5*k*(dll^2+dlr^2);

    function dydt = dynamics(~,state)
        dx = state(2); y = state(3); dy = state(4);
        alphaL = state(5); dalphaL = state(6);
        alphaR = state(7); dalphaR = state(8);
        Fx = 0; Fy = 0;
        if contactL
            Fx = Fx-(1-y/cos(alphaL))*k*sin(alphaL);
            Fy = Fy+(1-y/cos(alphaL))*k*cos(alphaL);
        end
        if contactR
            Fx = Fx-(1-y/cos(alphaR))*k*sin(alphaR);
            Fy = Fy+(1-y/cos(alphaR))*k*cos(alphaR);
        end
        ddx = Fx; ddy = Fy-1;
        if contactL
            ddalphaL = -2*tan(alphaL)*dalphaL^2-2*dy*dalphaL/y- ...
                (ddx+ddy*tan(alphaL))/(y*(tan(alphaL)^2+1));
        else
            ddalphaL = -cos(alphaL)*Fx-sin(alphaL)*Fy- ...
                (alphaL-offsetL)*omega^2;
        end
        if contactR
            ddalphaR = -2*tan(alphaR)*dalphaR^2-2*dy*dalphaR/y- ...
                (ddx+ddy*tan(alphaR))/(y*(tan(alphaR)^2+1));
        else
            ddalphaR = -cos(alphaR)*Fx-sin(alphaR)*Fy- ...
                (alphaR-offsetR)*omega^2;
        end
        dydt = [dx;ddx;dy;ddy;dalphaL;ddalphaL;dalphaR;ddalphaR];
    end
end

function value = inContact(time,touchdown,liftoff)
if touchdown < liftoff
    value = time > touchdown && time < liftoff;
else
    value = time < liftoff || time > touchdown;
end
end

function value=sourceWrap(value,period)
% Preserve the source's inclusive [0,period] while-loop convention.
while value<0,value=value+period;end
while value>period,value=value-period;end
end
