classdef LegacyQuadrupedEvaluator
    %LEGACYQUADRUPEDEVALUATOR Deterministic wrapper around migrated dynamics.
    methods
        function raw = evaluate(~, decision, parameters, context)
            if nargin < 4, context = lmz.api.RunContext.synchronous(0); end
            context.check();
            [residual,time,states,legacyParameters,grf,eventStates] = ...
                lmzmodels.slip_quadruped.legacy.QuadrupedalZeroFun( ...
                decision(1:13),decision(14:22),parameters,{},'skipSolve');
            [uniqueTime,keep] = unique(time(:),'last');
            uniqueStates = states(keep,:);
            uniqueGrf = grf(keep,:);
            schedule = lmzmodels.slip_quadruped.legacy.EventTimingRegulation(decision(14:22));
            modes = lmzmodels.slip_quadruped.LegacyQuadrupedEvaluator.contactModes(uniqueTime,schedule);
            names = {'BL_TD','BL_LO','FL_TD','FL_LO','BR_TD','BR_LO','FR_TD','FR_LO','APEX'};
            records = repmat(struct('Name','','Time',0,'State',zeros(1,14), ...
                'PreState',zeros(1,14),'PostState',zeros(1,14)),9,1);
            for index = 1:9
                matching=find(abs(time(:)-schedule(index))<=max(1,abs(schedule(index)))*1e-13);
                if isempty(matching),preState=eventStates(index,:);postState=eventStates(index,:);else,preState=states(matching(1),:);postState=states(matching(end),:);end
                records(index) = struct('Name',names{index},'Time',schedule(index), ...
                    'State',eventStates(index,:),'PreState',preState,'PostState',postState);
            end
            raw = struct('Residual',residual(:),'Time',uniqueTime, ...
                'States',uniqueStates,'LegacyTime',time(:),'LegacyStates',states, ...
                'LegacyParameters',legacyParameters,'GroundReactionForces',uniqueGrf, ...
                'LegacyGroundReactionForces',grf,'EventStates',eventStates, ...
                'EventRecords',records,'Modes',modes,'Schedule',schedule(:), ...
                'DuplicateSamplesRemoved',numel(time)-numel(uniqueTime));
        end
    end
    methods (Static, Access=private)
        function modes = contactModes(time,schedule)
            period = schedule(9);
            names = {'back_left','front_left','back_right','front_right'};
            pairs = [1 2;3 4;5 6;7 8];
            modes = struct();
            for index = 1:4
                td = schedule(pairs(index,1)); lo = schedule(pairs(index,2));
                if td <= lo
                    contact = time >= td & time <= lo;
                else
                    contact = time >= td | time <= lo;
                end
                modes.(names{index}) = logical(contact(:));
            end
            modes.period = period;
        end
    end
end
