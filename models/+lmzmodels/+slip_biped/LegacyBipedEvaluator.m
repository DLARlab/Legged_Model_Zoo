classdef LegacyBipedEvaluator
    %LEGACYBIPEDEVALUATOR Deterministic wrapper around preserved dynamics.
    methods
        function raw = evaluate(~,decision,offsets,context,configuration)
            if nargin < 4 || isempty(context), context=lmz.api.RunContext.synchronous(0); end
            if nargin < 5, configuration=struct(); end
            context.check();
            k = lmzmodels.slip_biped.LegacyBipedEvaluator.fieldOr(configuration,'k_leg',20);
            omega = lmzmodels.slip_biped.LegacyBipedEvaluator.fieldOr(configuration,'omega_swing',6.5);
            [residual,time,states,legacyParameters,eventStates,energy,scaled] = ...
                lmzmodels.slip_biped.legacy.BipedApex(decision,offsets,k,omega);
            [uniqueTime,keep] = unique(time(:),'last');
            uniqueStates = states(keep,:);
            schedule = legacyParameters(1:5).';
            modes = lmzmodels.slip_biped.LegacyBipedEvaluator.contactModes(uniqueTime,schedule);
            names = {'L_TD','L_LO','R_TD','R_LO','APEX'};
            records = repmat(struct('Name','','Time',0,'State',zeros(1,8), ...
                'PreState',zeros(1,8),'PostState',zeros(1,8)),5,1);
            tolerance = 1e-11;
            for index = 1:5
                matching = find(abs(time(:)-schedule(index)) <= ...
                    tolerance*max(1,abs(schedule(index))));
                if isempty(matching)
                    preState=eventStates(index,:); postState=eventStates(index,:);
                else
                    preState=states(matching(1),:); postState=states(matching(end),:);
                end
                records(index)=struct('Name',names{index},'Time',schedule(index), ...
                    'State',eventStates(index,:),'PreState',preState,'PostState',postState);
            end
            grf = lmzmodels.slip_biped.LegacyBipedEvaluator.forces(uniqueStates,modes,k);
            raw=struct('Residual',residual(:),'ScaledResidual',scaled(:), ...
                'Time',uniqueTime,'States',uniqueStates,'LegacyTime',time(:), ...
                'LegacyStates',states,'LegacyParameters',legacyParameters, ...
                'EventStates',eventStates,'EventRecords',records, ...
                'Modes',modes,'Schedule',schedule,'Energy',energy, ...
                'GroundReactionForces',grf, ...
                'DuplicateSamplesRemoved',numel(time)-numel(uniqueTime), ...
                'KLeg',k,'OmegaSwing',omega);
        end
    end
    methods (Static, Access=private)
        function modes=contactModes(time,schedule)
            modes=struct('left',false(size(time)),'right',false(size(time)), ...
                'period',schedule(5));
            pairs=[1 2;3 4]; names={'left','right'};
            for index=1:2
                td=schedule(pairs(index,1));lo=schedule(pairs(index,2));
                if td<lo,contact=time>=td & time<=lo; ...
                else,contact=time<=lo | time>=td;end
                modes.(names{index})=logical(contact(:));
            end
        end
        function grf=forces(states,modes,k)
            grf=zeros(size(states,1),6);
            angles=states(:,[5 7]); y=states(:,3);
            contacts=[modes.left,modes.right];
            for leg=1:2
                compression=1-y./cos(angles(:,leg));
                fx=-compression*k.*sin(angles(:,leg)).*contacts(:,leg);
                fy= compression*k.*cos(angles(:,leg)).*contacts(:,leg);
                grf(:,leg)=sqrt(fx.^2+fy.^2);
                grf(:,2+leg)=fx; grf(:,4+leg)=fy;
            end
        end
        function value=fieldOr(source,name,fallback)
            if isfield(source,name),value=source.(name);else,value=fallback;end
        end
    end
end
