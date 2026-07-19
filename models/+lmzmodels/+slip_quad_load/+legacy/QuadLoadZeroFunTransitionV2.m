%% This version of the dynamic model is designed for tunable system parameters: Para = [k,ks,J,lb,l]
% Vendored compatibility runtime from
% DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights,
% Stored_Functions/Dynamics/Quad_Load_ZeroFun_Transition_v2.m,
% commit 19f3133073c988cc0c3424a647b4adbb60a90b99.
% Local changes are limited to the package-safe public function name,
% package-qualified recursive calls, and suppressing iterative fsolve text
% so ordinary library simulation remains quiet.
%  The code is using ode function to integrate the system dynamics.
%  The script cnsists of:  1. Defining initial states, parameters, and phase
%                          2. Integrate the system using different ODE function base the phase (timing variables)
%                          3. The ODE functions: Stance Dynamics and Swing Dynamics
%                          4. Functions that compute the stance leg accelerations
%                          5. Computing the ground reaction forces
%  In this version v2, the stance dynamics are calculated based on input lb.

%  The output of the script consists of: 1. Residual values defined by periodic and holonomic constraints
%                                        2. States, Time, Parameters of the system
%                                        3. Vertical Ground Reaction Force
%                                        4. The States at Touchdown and Liftoff Timings

%% Dynamics Start from here: 
function [residual, T, Y, P, GRFs, F_Leash, Y_EVENT] = QuadLoadZeroFunTransitionV2(varargin)
    
    stiff_ode = 0;
    
    %— detect skip‐solve flag and strip it out —
    skipSolve = false;
    if ~isempty(varargin) && ischar(varargin{end}) ...
            && strcmp(varargin{end},'skipSolve')
        skipSolve = true;
        varargin(end) = [];
    end

    %— now parse your six numeric inputs + optional constraints —
    [X_Quad, E_Quad, Para_Quad, X_Load, Para_Load, constraints] = ...
        ParseTransitionInputs(varargin{:});

    % abort if parse failed
    if isempty(X_Quad)
        return;
    end

    %— only enforce the foot‐on‐ground timing at the top level —
    if ~skipSolve
        E_Quad = EnforceEventTimingQuad( ...
            X_Quad, E_Quad, Para_Quad, X_Load, Para_Load, constraints );
    end

    %**********************************************************************
    % General Preparation for the Quad
    %**********************************************************************
    
    Para_Quad = abs(Para_Quad);   % Force the parameters to be positive values

    % Define model parameters:
    M  = 1;              % Set the torso mass to be 1
       
    % Identical Parameters
    k   = Para_Quad(1);       % linear leg stiffness of legs

    % Set different ks for different legs: sequence BL, FL, BR, FR
    ks_pre  = Para_Quad(2:5); % swing stiffness of legs before touchdown, omega = sqrt(ks);
    ks_pst  = Para_Quad(6:9); % swing stiffness of legs after touchdown,  omega = sqrt(ks);

    J   = Para_Quad(10); % torso pitching inertia
    l   = Para_Quad(11); % Ratio between resting leg length and main body l/L, usually set to be 1.
    osa = Para_Quad(12); % Resting angle of swing leg motion 
    
    % Asymmetrical Parameters

    lb = Para_Quad(13); % distance from COM to hip joint/length of torso
    
    if lb>0.9   % set the limit the this value
        lb = 0.9;
    end
    if lb<0.1
        lb = 0.1;
    end

    kr = Para_Quad(14); % ratio of linear stiffness between back and front legs: kr = kb/kf, when kb+kf = 2*k;

    kb = 2*k/(1+ 1/kr);
    kf = 2*k/(1+ kr);


    %%%%%%%%%%%%%%%%%
    % Initial states
    % N = 18 ; % 10 continuous states (including x)
    N = 16;
    x0_quad        = 0;
    dx0_quad       = X_Quad(1); 
    y0_quad        = X_Quad(2);
    dy0_quad       = X_Quad(3);
    phi0_quad      = X_Quad(4);
    dphi0_quad     = X_Quad(5);

    alphaBL0_quad  = X_Quad(6);   % Left legs
    dalphaBL0_quad = X_Quad(7);
    alphaFL0_quad  = X_Quad(8);
    dalphaFL0_quad = X_Quad(9);
    
    alphaBR0_quad  = X_Quad(10);  % Right legs
    dalphaBR0_quad = X_Quad(11);
    alphaFR0_quad  = X_Quad(12);
    dalphaFR0_quad = X_Quad(13);    
    %%%%%%%%%%%%%%%%%

    % Event timing:
    E_Quad = EventTimingRegulation(E_Quad); % wrap timings into [0..tAPEX]

    tBL_TD    = E_Quad(1);
    tBL_LO    = E_Quad(2);
    tFL_TD    = E_Quad(3);
    tFL_LO    = E_Quad(4);
    tBR_TD    = E_Quad(5);
    tBR_LO    = E_Quad(6);
    tFR_TD    = E_Quad(7);
    tFR_LO    = E_Quad(8);
    tAPEX     = E_Quad(9);
    


    %**********************************************************************
    % General Preparation for the Sled
    %**********************************************************************
    
    % Parameters for the Sled:
    H_Load        = Para_Load(1);     % Height of the Sled
    M_Load        = Para_Load(2);     % Mass of the Sled
    mu_Load       = Para_Load(3);     % Friction Ratio of the Sled
    l_Load       = Para_Load(4);     % Resting length  of the leash


    % States of the 
    x0_Load  = X_Load(1);
    dx0_Load = X_Load(2);

    y0_Load  = H_Load;
    dy0_Load = 0;

    if length(X_Load)>3 && length(Para_Load)<5
        k_rope = X_Load(end-1);
    else
        k_rope   = Para_Load(5);     % Spring stiffness of the leash
    end
    
    if length(X_Load)>2 && length(Para_Load)<6
        theta_slope = X_Load(end);
    else
        theta_slope   = Para_Load(6);     % Slope angle that changes the direction of gravity
    end



    %**********************************************************************
    % Integration
    %**********************************************************************
    % Set up start of integration:
    T_START = 0;
    Y_START = [x0_quad, dx0_quad, y0_quad, dy0_quad, phi0_quad, dphi0_quad,...
               alphaBL0_quad, dalphaBL0_quad, alphaFL0_quad, dalphaFL0_quad,...
               alphaBR0_quad, dalphaBR0_quad, alphaFR0_quad, dalphaFR0_quad,...
               x0_Load, dx0_Load, y0_Load, dy0_Load];


    % Integrate motion in 4 steps, which are determined by the order of the
    % event times: 
    % Determine this order (iEVENT(i) is the Eventnumber of the ith event)
    [tEVENT,iEVENT] = sort([tBL_TD,tBL_LO,tFL_TD,tFL_LO,tBR_TD,tBR_LO,tFR_TD,tFR_LO,tAPEX]);
    % Prepare output:
    T = [];
    Y = [];
    Y_EVENT = zeros(9,18);

    for i = 1:9 %Integrate motion i/5
        % Figure out the current contact configuration (this is used in the
        % dynamics function)
        t_ = (T_START+tEVENT(i))/2;
        
        [contactBL, precontactBL, postcontactBL] = determineContact(t_, tBL_TD, tBL_LO, tAPEX);
        [contactFL, precontactFL, postcontactFL] = determineContact(t_, tFL_TD, tFL_LO, tAPEX);
        [contactBR, precontactBR, postcontactBR] = determineContact(t_, tBR_TD, tBR_LO, tAPEX);
        [contactFR, precontactFR, postcontactFR] = determineContact(t_, tFR_TD, tFR_LO, tAPEX);
        

        % Set up solver     
        %************************
        % Variable time step solver:
        % Setup ode solver options: 

%         options = odeset('RelTol',1e-12,'AbsTol',1e-12);

            if  abs(T_START - tEVENT(i))<1e-12 % T_START == tEVENT(i)  
                % make sure the time interval is valid
                Y_PART = Y_START;
                T_PART = T_START;
            else
                if X_Quad(1) < 15
                    options = odeset('RelTol',1e-12,'AbsTol',1e-12);
                    [T_PART,Y_PART] = ode45(@ode,[T_START,tEVENT(i)],Y_START,options);
                else
                    options = odeset('RelTol',1e-13,'AbsTol',1e-13);
                    [T_PART,Y_PART] = ode45(@ode,[T_START,tEVENT(i)],Y_START,options);
                end
            end   

        % Event handlers:
        if iEVENT(i)==1
            % If this is EVENT 1, append hind leg touchdown L:
            T_PART=[T_PART;T_PART(end)]; 
            Y_PART=[Y_PART;Y_PART(end,:)];
            Pv1 = [Y_PART(end,[1 3 5 7 9]), Y_PART(end,[1 3 5 7 9]+1), zeros(1,5), lb]';
            Y_PART(end,8) = Func_alphaB_VA_v2(Pv1);
        end

        if iEVENT(i)==3
            % If this is EVENT 3, append front leg touchdown R:
            T_PART=[T_PART;T_PART(end)];
            Y_PART=[Y_PART;Y_PART(end,:)];
            Pv2 = [Y_PART(end,[1 3 5 7 9]), Y_PART(end,[1 3 5 7 9]+1), zeros(1,5), lb]';
            Y_PART(end,10) = Func_alphaF_VA_v2(Pv2);
        end

        if iEVENT(i)==5
            % If this is EVENT 5, append hind leg touchdown L:
            T_PART=[T_PART;T_PART(end)]; 
            Y_PART=[Y_PART;Y_PART(end,:)];
            Pv3 = [Y_PART(end,[1 3 5 11 13]), Y_PART(end,[1 3 5 11 13]+1), zeros(1,5), lb]';
            Y_PART(end,12) = Func_alphaB_VA_v2(Pv3);
        end

        if iEVENT(i)==7
            % If this is EVENT 3, append front leg touchdown R:
            T_PART=[T_PART;T_PART(end)];
            Y_PART=[Y_PART;Y_PART(end,:)];
            Pv4 = [Y_PART(end,[1 3 5 11 13]), Y_PART(end,[1 3 5 11 13]+1), zeros(1,5), lb]';
            Y_PART(end,14) = Func_alphaF_VA_v2(Pv4);
        end


        if iEVENT(i)==2
            % If this is EVENT 1, append hind leg touchdown L:
            T_PART=[T_PART;T_PART(end)]; 
            Y_PART=[Y_PART;Y_PART(end,:)];
            Pv1 = [Y_PART(end,[1 3 5 7 9]), Y_PART(end,[1 3 5 7 9]+1), zeros(1,5), lb]';
            Y_PART(end,8) = Func_alphaB_VA_v2(Pv1);
        end

        if iEVENT(i)==4
            % If this is EVENT 3, append front leg touchdown R:
            T_PART=[T_PART;T_PART(end)];
            Y_PART=[Y_PART;Y_PART(end,:)];
            Pv2 = [Y_PART(end,[1 3 5 7 9]), Y_PART(end,[1 3 5 7 9]+1), zeros(1,5), lb]';
            Y_PART(end,10) = Func_alphaF_VA_v2(Pv2);
        end

        if iEVENT(i)==6
            % If this is EVENT 5, append hind leg touchdown L:
            T_PART=[T_PART;T_PART(end)]; 
            Y_PART=[Y_PART;Y_PART(end,:)];
            Pv3 = [Y_PART(end,[1 3 5 11 13]), Y_PART(end,[1 3 5 11 13]+1), zeros(1,5), lb]';
            Y_PART(end,12) = Func_alphaB_VA_v2(Pv3);
        end

        if iEVENT(i)==8
            % If this is EVENT 3, append front leg touchdown R:
            T_PART=[T_PART;T_PART(end)];
            Y_PART=[Y_PART;Y_PART(end,:)];
            Pv4 = [Y_PART(end,[1 3 5 11 13]), Y_PART(end,[1 3 5 11 13]+1), zeros(1,5), lb]';
            Y_PART(end,14) = Func_alphaF_VA_v2(Pv4);
        end

        
        % Compose total solution
        T = [T;T_PART];
        Y = [Y;Y_PART];

        % Extract values at Events
        Y_EVENT(iEVENT(i),:)=Y(end,:);
        % Prepare initial values for next integration:
        T_START = T(end);
        Y_START = Y(end,:);
    end
    




    function [contact, precontact, postcontact] = determineContact(t, t_TD, t_LO, t_APEX)
       
        if t_TD < t_LO
            % Pre-contact: t < touchdown
            precontact = (t < t_TD);
        
            % In-contact: touchdown ≤ t < liftoff
            contact    = (t >= t_TD) && (t < t_LO);
        
            % Post-contact: t ≥ liftoff
            postcontact = (t >= t_LO);
        else
            % Pre-contact: liftoff ≤ t < touchdown
            precontact = (t >= t_LO) && (t < t_TD);
        
            % In-contact: 0 ≤ t < liftoff || touchdown < t < APEX
            contact    = ( (t >= 0) && (t < t_LO) )  ||  ( (t >= t_TD) && (t <= t_APEX) );
        
            % Post-contact: t ≥ liftoff
            postcontact = 0;

        end
    
    end


    P = [tBL_TD,tBL_LO,tFL_TD,tFL_LO,tBR_TD,tBR_LO,tFR_TD,tFR_LO,tAPEX,k,mean(mean([ks_pre; ks_pst])),J,l,osa,lb,kr,l_Load];
    
    [GRF,GRF_X,GRF_Y] = ComputeGRF(P,Y,T);
    GRFs = [GRF GRF_X GRF_Y];
    F_Leash = ComputeLeashForce(Y,k_rope,l_Load);
     
    %**********************************************************************
    % Compute Residuals
    %**********************************************************************
    % Relbbel event values:
    YBL_TD = Y_EVENT(1,:)';
    YBL_LO = Y_EVENT(2,:)';
    YFL_TD = Y_EVENT(3,:)';
    YFL_LO = Y_EVENT(4,:)';

    YBR_TD = Y_EVENT(5,:)';
    YBR_LO = Y_EVENT(6,:)';
    YFR_TD = Y_EVENT(7,:)';
    YFR_LO = Y_EVENT(8,:)';    
    
    YAPEX  = Y_EVENT(9,:)';
    % Compute residuals
    residual = zeros(8,1);
    

    % Physical Constraints
    % At the touch-down events, the feet have to be on the ground:
    residual(1)  = YBL_TD(3)  - lb*sin(YBL_TD(5)) - l*cos(YBL_TD(5)+YBL_TD(7));
    residual(2)  = YFL_TD(3)  + (1-lb)*sin(YFL_TD(5)) - l*cos(YFL_TD(5)+YFL_TD(9));
    % At the lift-off events, the feet also have to be on the ground:
    residual(3)  = YBL_LO(3)  - lb*sin(YBL_LO(5)) - l*cos(YBL_LO(5)+YBL_LO(7));
    residual(4)  = YFL_LO(3)  + (1-lb)*sin(YFL_LO(5)) - l*cos(YFL_LO(5)+YFL_LO(9));
    
    % At the touch-down events, the feet have to be on the ground:
    residual(5)  = YBR_TD(3)  - lb*sin(YBR_TD(5)) - l*cos(YBR_TD(5)+YBR_TD(11));
    residual(6)  = YFR_TD(3)  + (1-lb)*sin(YFR_TD(5)) - l*cos(YFR_TD(5)+YFR_TD(13));
    % At the lift-off events, the feet also have to be on the ground:
    residual(7)  = YBR_LO(3)  - lb*sin(YBR_LO(5)) - l*cos(YBR_LO(5)+YBR_LO(11));
    residual(8)  = YFR_LO(3)  + (1-lb)*sin(YFR_LO(5)) - l*cos(YFR_LO(5)+YFR_LO(13));

    % Physical Constraints
    residual(1:8)  = 1e0*residual(1:8);


    % Poincare section
    residual(end+1) = 1e0*YAPEX(4);
    
    
    % Ensure the Force Along the leash is also periodic
    residual(end+1) = 1e0*(F_Leash(end) - F_Leash(1));

    % Load States is periodic
    residual(end+1:end+3) = 1e0*(Y(1,16:18).' - YAPEX(16:18)); % x is not periodic
    
    % Ensure the Distance between the Quad and Sled is periodic
    l_leash_true_initial  = sqrt((Y(1,1)-Y(1,15))^2 + (Y(1,3)-0)^2);
    l_leash_true_final    = sqrt((Y(end,1)-Y(end,15))^2 + (Y(end,3)-0)^2);
    residual(end+1)       = 1e0*(l_leash_true_initial - l_leash_true_final);


    % Periodicity:
    residual(end+1:end+13) = 1e0*(Y(1,2:14).' - YAPEX(2:14)); % x is not periodic
   





    
    
    
    % **********************************************************************
    % Constraints Application
    % **********************************************************************
    if ismember('(BL,BR)', constraints)
        residual(end+1) = tBL_TD - tBR_TD;
        residual(end+1) = tBL_LO - tBR_LO;
    elseif ismember('(FL,FR)', constraints)
        residual(end+1) = tFL_TD - tFR_TD;
        residual(end+1) = tFL_LO - tFR_LO;
    elseif ismember('(BL,FL)', constraints)
        residual(end+1) = tBL_TD - tFL_TD;
        residual(end+1) = tBL_LO - tFL_LO;
    elseif ismember('(BR,FR)', constraints)
        residual(end+1) = tBR_TD - tFR_TD;
        residual(end+1) = tBR_LO - tFR_LO;
    elseif ismember('(BR,FL)', constraints)
        residual(end+1) = tBR_TD - tFL_TD;
        residual(end+1) = tBR_LO - tFL_LO;
    elseif ismember('(BL,FR)', constraints)
        residual(end+1) = tBL_TD - tFR_TD;
        residual(end+1) = tBL_LO - tFR_LO;
    end
    



    %**********************************************************************
    % Dynamics Function
    %**********************************************************************
    function dydt_ = ode(~,Y)
    % Extract individual states:
        x_quad       = Y(1);
        dx_quad      = Y(2);
        y_quad       = Y(3);
        dy_quad      = Y(4);
        phi_quad     = Y(5);
        dphi_quad    = Y(6);
        alphaBL_quad  = Y(7);
        dalphaBL_quad = Y(8);
        alphaFL_quad  = Y(9);
        dalphaFL_quad = Y(10);
        alphaBR_quad  = Y(11);
        dalphaBR_quad = Y(12);
        alphaFR_quad  = Y(13);
        dalphaFR_quad = Y(14);

        x_load        = Y(15);
        dx_load       = Y(16);
        % y_load        = Y(17);
        % dy_load       = Y(18);
        y_load        = y0_Load;
        dy_load       = dy0_Load;


        
        pos0 = [x_quad;y_quad];
        posB = pos0 + lb*[cos(phi_quad + pi);sin(phi_quad + pi)] ;
        posF = pos0 + (1-lb)*[cos(phi_quad);sin(phi_quad)] ;
         
        % Compute forces acting on the main body (only legs in contact
        % contribute): 

        BLforce = 0;
        FLforce = 0;
        BRforce = 0;
        FRforce = 0;
        
        if contactBL
            BLforce = (l- posB(2)/cos(alphaBL_quad+phi_quad))*kb;
        end
        if contactFL
            FLforce = (l- posF(2)/cos(alphaFL_quad+phi_quad))*kf;
        end
        if contactBR
            BRforce = (l- posB(2)/cos(alphaBR_quad+phi_quad))*kb;
        end
        if contactFR
            FRforce = (l- posF(2)/cos(alphaFR_quad+phi_quad))*kf;
        end
        
        Fx_quad  = -BLforce*sin(alphaBL_quad+phi_quad) - FLforce*sin(alphaFL_quad+phi_quad)...
              -BRforce*sin(alphaBR_quad+phi_quad) - FRforce*sin(alphaFR_quad+phi_quad);
        Fy_quad  =  BLforce*cos(alphaBL_quad+phi_quad) + FLforce*cos(alphaFL_quad+phi_quad)...
              +BRforce*cos(alphaBR_quad+phi_quad) + FRforce*cos(alphaFR_quad+phi_quad);
        Tor_quad = -BLforce*lb*cos(alphaBL_quad)  + FLforce*(1-lb)*cos(alphaFL_quad) ...
              -BRforce*lb*cos(alphaBR_quad)  + FRforce*(1-lb)*cos(alphaFR_quad);
        


        % Distributed gravity
        g_x   = 1*sin(theta_slope);  % g is normalized to 1
        g_y   = -1*cos(theta_slope);  % g is normalized to 1

        % Force between quad and Sled
        % distance between quad and Sled
        d_quad_sled     = sqrt( (x_quad-x_load)^2 + (y_quad - y_load)^2 );
        if d_quad_sled > l_Load
            f_quad_sled = (d_quad_sled - l_Load)*k_rope;
        else
            f_quad_sled = 0;
        end
        % angle of force between quad and Sled
        theta_quad_sled = atan2((y_quad - y_load), (x_quad-x_load));

        % Compute main body acceleration:
        ddx_quad   = Fx_quad + g_x - f_quad_sled*cos(theta_quad_sled);
        ddy_quad   = Fy_quad + g_y - f_quad_sled*sin(theta_quad_sled);
        ddphi_quad = Tor_quad/J;
        


        N_sled     =  -g_y;   % support force to the Sled        
        Fx_sled    =  f_quad_sled*cos(theta_quad_sled)  - mu_Load*N_sled;
        ddx_sled   =  Fx_sled/M_Load;

        Fy_sled    = 0;     % set y force of Sled to be zero for simplicity
        ddy_sled   = Fy_sled/M_Load;
       



        AsvL = [x_quad y_quad phi_quad alphaBL_quad alphaFL_quad dx_quad dy_quad dphi_quad dalphaBL_quad dalphaFL_quad ddx_quad ddy_quad ddphi_quad 0 0, lb]';  
        % Compute leg acceleration:
       
        if contactBL
            [dalphaBL_quad,ddalphaBL_quad] = Func_alphaB_VA_v2(AsvL);  
        elseif precontactBL
            ddalphaBL_quad = - ( Tor_quad/J - Tor_quad*lb*sin(alphaBL_quad)/(J*l) ...
                         + Fx_quad*cos(alphaBL_quad + phi_quad)/(M*l)...
                         + Fy_quad*sin(alphaBL_quad + phi_quad)/(M*l)...
                         + alphaBL_quad*ks_pre(1)/(l^2)... 
                         + dphi_quad^2*lb*cos(alphaBL_quad)/l);
        elseif postcontactBL
            ddalphaBL_quad = - ( Tor_quad/J - Tor_quad*lb*sin(alphaBL_quad)/(J*l) ...
                         + Fx_quad*cos(alphaBL_quad + phi_quad)/(M*l)...
                         + Fy_quad*sin(alphaBL_quad + phi_quad)/(M*l)...
                         + alphaBL_quad*ks_pst(1)/(l^2)... 
                         + dphi_quad^2*lb*cos(alphaBL_quad)/l);
        end
        
        if contactFL
            [dalphaFL_quad,ddalphaFL_quad] = Func_alphaF_VA_v2(AsvL);
        elseif precontactFL
            ddalphaFL_quad = - ( Tor_quad/J + Tor_quad*(1-lb)*sin(alphaFL_quad)/(J*l)...
                         + Fx_quad*cos(alphaFL_quad + phi_quad)/(M*l)...
                         + Fy_quad*sin(alphaFL_quad + phi_quad)/(M*l)...
                         + alphaFL_quad*ks_pre(2)/(l^2)...
                         - dphi_quad^2*(1-lb)*cos(alphaFL_quad)/l);
        elseif postcontactFL
            ddalphaFL_quad = - ( Tor_quad/J + Tor_quad*(1-lb)*sin(alphaFL_quad)/(J*l)...
                         + Fx_quad*cos(alphaFL_quad + phi_quad)/(M*l)...
                         + Fy_quad*sin(alphaFL_quad + phi_quad)/(M*l)...
                         + alphaFL_quad*ks_pst(2)/(l^2)...
                         - dphi_quad^2*(1-lb)*cos(alphaFL_quad)/l);
        end
        
        AsvR = [x_quad y_quad phi_quad alphaBR_quad alphaFR_quad dx_quad dy_quad dphi_quad dalphaBR_quad dalphaFR_quad ddx_quad ddy_quad ddphi_quad 0 0, lb]';  
        % Compute leg angle acceleration:
       
        if contactBR
            [dalphaBR_quad,ddalphaBR_quad] = Func_alphaB_VA_v2(AsvR);  
        elseif precontactBR
            ddalphaBR_quad = - ( Tor_quad/J - Tor_quad*lb*sin(alphaBR_quad)/(J*l) ...
                         + Fx_quad*cos(alphaBR_quad + phi_quad)/(M*l)...
                         + Fy_quad*sin(alphaBR_quad + phi_quad)/(M*l)...
                         + alphaBR_quad*ks_pre(3)/(l^2)... 
                         + dphi_quad^2*lb*cos(alphaBR_quad)/l);    
        elseif postcontactBR
            ddalphaBR_quad = - ( Tor_quad/J - Tor_quad*lb*sin(alphaBR_quad)/(J*l) ...
                         + Fx_quad*cos(alphaBR_quad + phi_quad)/(M*l)...
                         + Fy_quad*sin(alphaBR_quad + phi_quad)/(M*l)...
                         + alphaBR_quad*ks_pst(3)/(l^2)... 
                         + dphi_quad^2*lb*cos(alphaBR_quad)/l);                       
        end
        
        if contactFR
            [dalphaFR_quad,ddalphaFR_quad] = Func_alphaF_VA_v2(AsvR);
        elseif precontactFR
            ddalphaFR_quad = - ( Tor_quad/J + Tor_quad*(1-lb)*sin(alphaFR_quad)/(J*l)...
                         + Fx_quad*cos(alphaFR_quad + phi_quad)/(M*l)...
                         + Fy_quad*sin(alphaFR_quad + phi_quad)/(M*l)...
                         + alphaFR_quad*ks_pre(4)/(l^2)...
                         - dphi_quad^2*(1-lb)*cos(alphaFR_quad)/l);
        elseif postcontactFR
            ddalphaFR_quad = - ( Tor_quad/J + Tor_quad*(1-lb)*sin(alphaFR_quad)/(J*l)...
                         + Fx_quad*cos(alphaFR_quad + phi_quad)/(M*l)...
                         + Fy_quad*sin(alphaFR_quad + phi_quad)/(M*l)...
                         + alphaFR_quad*ks_pst(4)/(l^2)...
                         - dphi_quad^2*(1-lb)*cos(alphaFR_quad)/l);
        end
        
        
        dydt_ = [dx_quad;ddx_quad;dy_quad;ddy_quad;dphi_quad;ddphi_quad;...
                 dalphaBL_quad;ddalphaBL_quad;dalphaFL_quad;ddalphaFL_quad;...
                 dalphaBR_quad;ddalphaBR_quad;dalphaFR_quad;ddalphaFR_quad;...
                 dx_load;ddx_sled;dy_load;ddy_sled];

        % dydt_ = [dx_quad;ddx_quad;dy_quad;ddy_quad;dphi_quad;ddphi_quad;...
        %  dalphaBL_quad;ddalphaBL_quad;dalphaFL_quad;ddalphaFL_quad;...
        %  dalphaBR_quad;ddalphaBR_quad;dalphaFR_quad;ddalphaFR_quad;...
        %  dx_sled;ddx_sled];
        
    end

end
%% Compute Stance Leg Dynamics
    function [dalphaB,ddalphaB] = Func_alphaB_VA_v2(in1)
    %Func_alphaB_VA_v2_V2
    %    [DALPHAB,DDALPHAB] = Func_alphaB_VA_v2_V2(IN1)

    %    This function was generated by the Symbolic Math Toolbox version 8.7.
    %    16-Feb-2023 22:36:05

    alphaB = in1(4,:);
    dalphaB = in1(9,:);
    ddphi = in1(13,:);
    ddx = in1(11,:);
    ddy = in1(12,:);
    dphi = in1(8,:);
    dx = in1(6,:);
    dy = in1(7,:);
    lb = in1(16,:);
    phi = in1(3,:);
    y = in1(2,:);
    t2 = cos(alphaB);
    t3 = sin(phi);
    t4 = alphaB+phi;
    t5 = alphaB.*2.0;
    t6 = alphaB.*3.0;
    t7 = dalphaB.^2;
    t8 = dphi.^2;
    t9 = phi.*2.0;
    t10 = phi.*3.0;
    t11 = cos(t4);
    t12 = sin(t4);
    t13 = phi+t4;
    t16 = t4.*2.0;
    dalphaB = -(dx+dphi.*y.*2.0+dx.*cos(t16)+dy.*sin(t16)-dphi.*lb.*t3-dphi.*lb.*sin(alphaB+t4))./(y.*2.0-lb.*t3.*2.0);
    if nargout > 1
        t18 = t4.*3.0;
        t14 = sin(t13);
        t15 = cos(t13);
        t17 = alphaB+t16;
        ddalphaB = -(ddx.*t11.*3.0+ddy.*t12+ddx.*cos(t18)+ddy.*sin(t18)+lb.*t8.*cos(t17)-ddphi.*lb.*sin(t17)+dalphaB.*dy.*t11.*8.0+dphi.*dy.*t11.*8.0-ddphi.*lb.*t14+ddphi.*t11.*y.*4.0-lb.*t2.*t7.*4.0-lb.*t2.*t8.*6.0+lb.*t7.*t15.*4.0+lb.*t8.*t15+t7.*t12.*y.*8.0+t8.*t12.*y.*8.0-dalphaB.*dphi.*lb.*t2.*1.2e+1+dalphaB.*dphi.*lb.*t15.*4.0+dalphaB.*dphi.*t12.*y.*1.6e+1)./(lb.*t14.*-2.0+t11.*y.*4.0+lb.*sin(alphaB).*2.0);
    end

    end
    function [dalphaF,ddalphaF] = Func_alphaF_VA_v2(in1)
    %FUNC_ALPHAF_VA_V2
    %    [DALPHAF,DDALPHAF] = FUNC_ALPHAF_VA_V2(IN1)

    %    This function was generated by the Symbolic Math Toolbox version 8.7.
    %    16-Feb-2023 22:36:08

    alphaF = in1(5,:);
    dalphaF = in1(10,:);
    ddphi = in1(13,:);
    ddx = in1(11,:);
    ddy = in1(12,:);
    dphi = in1(8,:);
    dx = in1(6,:);
    dy = in1(7,:);
    lb = in1(16,:);
    phi = in1(3,:);
    y = in1(2,:);
    t2 = cos(phi);
    t3 = sin(phi);
    t4 = alphaF+phi;
    t6 = lb-1.0;
    t5 = tan(t4);
    t8 = t3.*t6;
    t7 = t5.^2;
    t10 = -t8;
    t12 = t2.*t5.*t6;
    t16 = -1.0./(t8-y);
    t9 = t7+1.0;
    t14 = t10+y;
    t15 = -t12;
    t11 = dy.*t9;
    t13 = 1.0./t9;
    dalphaF = (t13.*(dx+dy.*t5-dphi.*(t10+t12+t9.*(t8-y))))./(t8-y);
    if nargout > 1
        t17 = -t9.*(t8-y);
        t18 = t5.*t9.*(t8-y).*-2.0;
        t19 = dalphaF.*t18;
        ddalphaF = (t13.*(ddx+dphi.*(t11+t19+dphi.*(t18+t2.*t6+t5.*t8-t2.*t6.*t9.*2.0)-dalphaF.*t2.*t6.*t9)-dalphaF.*(-t11+dphi.*(t2.*t6.*t9+t5.*t9.*(t8-y).*2.0)+dalphaF.*t5.*t9.*(t8-y).*2.0)+ddy.*t5-ddphi.*(t10+t12+t9.*(t8-y))+dy.*(dalphaF.*t9+dphi.*t9)))./(t8-y);
    end

    end
%%  Compute Ground Reaction Force
function [GRF,GRF_X,GRF_Y] = ComputeGRF(P,Y,T)

    tBL_TD = P(1);
    tBL_LO = P(2);
    tFL_TD = P(3);
    tFL_LO = P(4);
    tBR_TD = P(5);
    tBR_LO = P(6);
    tFR_TD = P(7);
    tFR_LO = P(8);
    k  = P(10);
    l  = P(13);
    lb = P(15);
    kr = P(16);
    
    kb = 2*k/(1+ 1/kr);
    kf = 2*k/(1+ kr);
    
    n = length(T);
    
    FBLx = zeros(n,1);
    FFLx = zeros(n,1);
    FBRx = zeros(n,1);
    FFRx = zeros(n,1);
    
    FBLy = zeros(n,1);
    FFLy = zeros(n,1);
    FBRy = zeros(n,1);
    FFRy = zeros(n,1);
    
    FBL = zeros(n,1);
    FFL = zeros(n,1);
    FBR = zeros(n,1);
    FFR = zeros(n,1);
    
    
    % Compute vertical GRF using the data   
    for  i = 1:n

        t_ = T(i);
        if ((t_>tBL_TD && t_<tBL_LO && tBL_TD<tBL_LO) || ((t_<tBL_LO || t_>tBL_TD) && tBL_TD>tBL_LO))
            contactBL = true;
        else
            contactBL = false;
        end
        if ((t_>tFL_TD && t_<tFL_LO && tFL_TD<tFL_LO) || ((t_<tFL_LO || t_>tFL_TD) && tFL_TD>tFL_LO))
            contactFL = true;
        else
            contactFL = false;
        end


        if ((t_>tBR_TD && t_<tBR_LO && tBR_TD<tBR_LO) || ((t_<tBR_LO || t_>tBR_TD) && tBR_TD>tBR_LO))
            contactBR = true;
        else
            contactBR = false;
        end
        if ((t_>tFR_TD && t_<tFR_LO && tFR_TD<tFR_LO) || ((t_<tFR_LO || t_>tFR_TD) && tFR_TD>tFR_LO))
            contactFR = true;
        else
            contactFR = false;
        end  

        y_ = Y(i,:);
        
        x        = y_(1);
        y        = y_(3);
        phi      = y_(5);        
        alphaBL   = y_(7);
        alphaFL   = y_(9);
        alphaBR   = y_(11);
        alphaFR   = y_(13);


        pos0 = [x;y];
        posB = pos0 + lb*[cos(phi + pi);sin(phi + pi)] ;
        posF = pos0 + (1-lb)*[cos(phi);sin(phi)] ;

        % Compute forces acting on the main body (only legs in contact
        % contribute): 
        
        if contactBL
            FBLx(i) = (l- posB(2)/cos(alphaBL+phi))*kb*sin(alphaBL+phi);
        end
        if contactFL
            FFLx(i) = (l- posF(2)/cos(alphaFL+phi))*kf*sin(alphaFL+phi);
        end 
        if contactBR
            FBRx(i) = (l- posB(2)/cos(alphaBR+phi))*kb*sin(alphaBR+phi);
        end
        if contactFR
            FFRx(i) = (l- posF(2)/cos(alphaFR+phi))*kf*sin(alphaFR+phi);
        end
              
        if contactBL
            FBLy(i) = (l- posB(2)/cos(alphaBL+phi))*kb*cos(alphaBL+phi);
        end
        if contactFL
            FFLy(i) = (l- posF(2)/cos(alphaFL+phi))*kf*cos(alphaFL+phi);
        end 
        if contactBR
            FBRy(i) = (l- posB(2)/cos(alphaBR+phi))*kb*cos(alphaBR+phi);
        end
        if contactFR
            FFRy(i) = (l- posF(2)/cos(alphaFR+phi))*kf*cos(alphaFR+phi);
        end
        
        if contactBL
            FBL(i) = (l- posB(2)/cos(alphaBL+phi))*kb;
        end
        if contactFL
            FFL(i) = (l- posF(2)/cos(alphaFL+phi))*kf;
        end 
        if contactBR
            FBR(i) = (l- posB(2)/cos(alphaBR+phi))*kb;
        end
        if contactFR
            FFR(i) = (l- posF(2)/cos(alphaFR+phi))*kf;
        end   

    end
    GRF_X = [FBLx FFLx FBRx FFRx];
    GRF_Y = [FBLy FFLy FBRy FFRy];
    GRF   = [FBL  FFL  FBR  FFR ];
end


%% Compute Leash Force

function F_Leash = ComputeLeashForce(Y,k_leash,l_leash)
F_Leash = zeros(size(Y,1),1);
for i = 1:length(F_Leash)
        % d_quad_Sled     = sqrt( (Y(i,1)-Y(i,15))^2 + (Y(i,3) - Y(i,17))^2);
        d_quad_Sled     = sqrt( (Y(i,1)-Y(i,15))^2 + (Y(i,3) - Y(i,17))^2);
        if d_quad_Sled > l_leash
            f_quad_Sled = (d_quad_Sled - l_leash)*k_leash;
        else
            f_quad_Sled = 0;
        end
        F_Leash(i) = f_quad_Sled;
end
end

%% helper: parse inputs (improved)
function [X_quad, E_quad, Para_quad, X_load, Para_load, constraints] = ParseTransitionInputs(varargin)
% Parses up to five numeric inputs (X_quad:13, E_quad:9, Para_quad:14, X_load:2, Para_load:6)
% plus an optional constraints struct/cell.

% Initialize outputs
X_quad    = [];
E_quad    = [];
Para_quad = [];
X_load    = [];
Para_load = [];
constraints = {};

% Separate numeric arrays and constraints
nums = {};
for k = 1:numel(varargin)
    v = varargin{k};
    if isnumeric(v)
        nums{end+1} = v(:)';
    elseif isstruct(v) || iscell(v)
        constraints = v;
    else
        error('ParseTransitionInputs:InvalidType', 'Input %d has invalid type.', k);
    end
end

% Required lengths
L.X  = 13;
L.E  = 9;
L.P  = 14;
L.xl = 2;
L.pl = 6;
allLen = L.X + L.E + L.P + L.xl + L.pl;

% Helper to split combined vector
splitCombined = @(v, lenA, lenB) deal(v(1:lenA), v(lenA+1:lenA+lenB));

nNum = numel(nums);
if nNum == 1
    v = nums{1}; Ltot = numel(v);
    if Ltot ~= allLen
        error('ParseTransitionInputs:BadLength', 'Single input must have length %d.', allLen);
    end
    % split in fixed order: X, E, Para, X_load, Para_load
    idx = 0;
    X_quad    = v(idx+1:idx+L.X);   idx = idx + L.X;
    E_quad    = v(idx+1:idx+L.E);   idx = idx + L.E;
    Para_quad = v(idx+1:idx+L.P);   idx = idx + L.P;
    X_load    = v(idx+1:idx+L.xl);  idx = idx + L.xl;
    Para_load = v(idx+1:idx+L.pl);

elseif nNum <= 5
    % try to assign by matching lengths
    assigned = struct('X',false,'E',false,'P',false,'xl',false,'pl',false);
    for i = 1:numel(nums)
        v = nums{i}; lv = numel(v);
        switch lv
          case L.X
            if ~assigned.X
              X_quad = v; assigned.X = true;
            end
          case L.E
            if ~assigned.E
              E_quad = v; assigned.E = true;
            end
          case L.P
            if ~assigned.P
              Para_quad = v; assigned.P = true;
            end
          case L.xl
            if ~assigned.xl
              X_load = v; assigned.xl = true;
            end
          case L.pl
            if ~assigned.pl
              Para_load = v; assigned.pl = true;
            end
          otherwise
            % check for two-field combinations
            if ~assigned.X && ~assigned.E && lv == L.X+L.E
                [X_quad,E_quad] = splitCombined(v, L.X, L.E);
                assigned.X = true; assigned.E = true;

            elseif ~assigned.X && ~assigned.P && lv == L.X+L.P
                [X_quad,Para_quad] = splitCombined(v, L.X, L.P);
                assigned.X = true; assigned.P = true;

            elseif ~assigned.E && ~assigned.P && lv == L.E+L.P
                [E_quad,Para_quad] = splitCombined(v, L.E, L.P);
                assigned.E = true; assigned.P = true;

            elseif ~assigned.xl && ~assigned.pl && lv == L.xl+L.pl
                [X_load,Para_load] = splitCombined(v, L.xl, L.pl);
                assigned.xl = true; assigned.pl = true;

            else
                error('ParseTransitionInputs:BadLength', 'Unrecognized numeric input length %d.', lv);
            end
        end
    end

    % final check: all five must be assigned
    if ~all(struct2array(assigned))
        error('ParseTransitionInputs:Missing', 'Unable to assign all five numeric inputs.');
    end

else
    error('ParseTransitionInputs:TooMany', 'No more than 5 numeric inputs allowed.');
end
end


function Eout = EnforceEventTimingQuad(X, E, Para, X_load, Para_load, constraints)
    % Use wrapped timings
    E_wrapped = E;
    tol = 1e-8;
    max_attempts = 1;

    % Initial residual check
    r0 = lmzmodels.slip_quad_load.legacy.QuadLoadZeroFunTransitionV2( ...
        X, E_wrapped, Para, X_load, Para_load, constraints, 'skipSolve');
    
    if all(abs(r0(1:9)) < tol)
        Eout = E_wrapped;
        return;
    end

    % Modern fsolve options
    opts = optimoptions('fsolve', ...
        'Algorithm','levenberg-marquardt', ...
        'ScaleProblem','jacobian', ...
        'Display','off', ...
        'MaxFunctionEvaluations',10000, ...
        'MaxIterations',100, ...
        'FunctionTolerance',1e-9, ...
        'StepTolerance',1e-12);

    % Objective function
    funE = @(e) PhysicalResidual(X, e, Para, X_load, Para_load, constraints);
    solved = false;
    

    for attempt = 1:max_attempts
        if attempt > 1
            base_val = E(1:8);
            pct_range = 0.05 + 0.05*attempt/max_attempts;  % e.g., 5% + 1% per retry
            disturbance = (rand(1, 4) - 0.5) * 2 * pct_range;  % ±pct_range
            E_wrapped = E;
            E_wrapped([1 3 5 7]) = base_val([1 3 5 7]) .* (1 - disturbance);
            E_wrapped([2 4 6 8]) = base_val([2 4 6 8]) .* (1 + disturbance);

            % Display disturbance info
            fprintf('Attempt %d:\n', attempt);
            fprintf('  Varying percentage = [%s]\n', ...
                sprintf('%+.2f%% ', disturbance * 100));
            fprintf('  Disturbed values   = [%s]\n\n', ...
                sprintf('%.6f ', E_wrapped(1:8)));
            pause(0.5);
        else
            E_wrapped = E;
        end

        % Attempt solve
        E_sol = fsolve(funE, E_wrapped, opts);

        % Check result
        r = lmzmodels.slip_quad_load.legacy.QuadLoadZeroFunTransitionV2(X, E_sol, Para, X_load, Para_load, constraints, 'skipSolve');
        if all(abs(r(1:9)) < tol)
            solved = true;
            break;
        end
    end





    % Final output decision
    if solved
        Eout = E_sol(:)';
    else
        % user_input = input('Event Timing that satisfies physical constraints CANNOT be found. Continue with non-physical solution? [Y/N]: ', 's');
        % if strcmpi(user_input, 'Y')
        %     Eout = E_sol(:)';  % best attempt
        % else
        %     error('Dynamics function stopped due to non-physical solution.');
        % end
        Eout = E_wrapped;
        disp("Continue with non-physical solution with residual = " + num2str(norm(r(1:9))))
    end
end


function r9 = PhysicalResidual(e, X, ParaQuad, Xload, Paraload, constr)
    % call the core with skipSolve
    full = lmzmodels.slip_quad_load.legacy.QuadLoadZeroFunTransitionV2( ...
              X, e, ParaQuad, Xload, Paraload, constr, 'skipSolve' );
    % return only the first 8 residuals
    r9 = full(1:9);
end


%% Function: Event Timing Regulation (Outside Zero Function)
function X_out = EventTimingRegulation(X_in)
    X_out = X_in;
    n = numel(X_in);
    if n == 22
        % Full state+timing vector: timings at indices 14-22
        tIdx = 14:22;
        timings = X_in(tIdx);
    elseif n == 9
        % Only timing vector: assign directly
        timings = X_in(:);
        tIdx = 1:9;
    else
        error('EventTimingRegulation:InvalidInput', ...
            'Input length must be 9 or 22.');
    end
    % Extract timings
    tBL_TD = timings(1);
    tBL_LO = timings(2);
    tFL_TD = timings(3);
    tFL_LO = timings(4);
    tBR_TD = timings(5);
    tBR_LO = timings(6);
    tFR_TD = timings(7);
    tFR_LO = timings(8);
    tAPEX  = timings(9);
    % Wrap into [0, tAPEX]
    wrap = @(t) mod(t, tAPEX);
    tBL_TD_ = wrap(tBL_TD);
    tBL_LO_ = wrap(tBL_LO);
    tFL_TD_ = wrap(tFL_TD);
    tFL_LO_ = wrap(tFL_LO);
    tBR_TD_ = wrap(tBR_TD);
    tBR_LO_ = wrap(tBR_LO);
    tFR_TD_ = wrap(tFR_TD);
    tFR_LO_ = wrap(tFR_LO);
    tAPEX_  = tAPEX;
    % Place back into output
    newTimings = [tBL_TD_; tBL_LO_; tFL_TD_; tFL_LO_; tBR_TD_; tBR_LO_; tFR_TD_; tFR_LO_; tAPEX_];
    X_out(tIdx) = newTimings;
end
