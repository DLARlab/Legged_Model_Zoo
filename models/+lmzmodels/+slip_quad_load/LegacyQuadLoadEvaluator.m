classdef LegacyQuadLoadEvaluator
    %LEGACYQUADLOADEVALUATOR Package-safe wrapper around preserved dynamics.
    methods
        function raw=evaluateStride(~,vector,context,enforceEventTiming)
            if nargin<3||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if nargin<4,enforceEventTiming=false;end
            context.check();vector=vector(:);
            lmzmodels.slip_quad_load.FirstStrideLayout.validate(vector);
            if enforceEventTiming
                [residual,time,states,parameters,grf,tug,eventStates]= ...
                    lmzmodels.slip_quad_load.legacy.QuadLoadZeroFunTransitionV2(vector);
            else
                [residual,time,states,parameters,grf,tug,eventStates]= ...
                    lmzmodels.slip_quad_load.legacy.QuadLoadZeroFunTransitionV2(vector,'skipSolve');
            end
            schedule=parameters(1:9).';
            modes=lmzmodels.slip_quad_load.LegacyQuadLoadEvaluator.contactModes(time(:),schedule);
            names={'BL_TD','BL_LO','FL_TD','FL_LO','BR_TD','BR_LO','FR_TD','FR_LO','APEX'};
            records=repmat(struct('Name','','Time',0,'StrideIndex',1, ...
                'State',zeros(1,18),'PreState',zeros(1,18),'PostState',zeros(1,18)),9,1);
            for index=1:9
                tolerance=max(1,abs(schedule(index)))*1e-12;
                matching=find(abs(time(:)-schedule(index))<=tolerance);
                if isempty(matching)
                    preState=eventStates(index,:);postState=eventStates(index,:);
                else
                    preState=states(matching(1),:);postState=states(matching(end),:);
                end
                records(index)=struct('Name',names{index},'Time',schedule(index), ...
                    'StrideIndex',1,'State',eventStates(index,:), ...
                    'PreState',preState,'PostState',postState);
            end
            [uniqueTime,keep]=unique(time(:),'last');
            raw=struct('Residual',residual(:),'Time',uniqueTime, ...
                'States',states(keep,:),'GroundReactionForces',grf(keep,:), ...
                'TuglineForce',tug(keep,:),'Modes',subsetModes(modes,keep), ...
                'LegacyTime',time(:),'LegacyStates',states, ...
                'LegacyGroundReactionForces',grf,'LegacyTuglineForce',tug(:), ...
                'Parameters',parameters(:).','EventStates',eventStates, ...
                'EventRecords',records,'Schedule',schedule(:), ...
                'DuplicateSamplesRemoved',numel(time)-numel(uniqueTime), ...
                'EventTimingEnforced',logical(enforceEventTiming));
        end
    end
    methods (Static)
        function modes=contactModes(time,schedule)
            names={'back_left','front_left','back_right','front_right'};
            pairs=[1 2;3 4;5 6;7 8];modes=struct();
            for index=1:4
                td=schedule(pairs(index,1));lo=schedule(pairs(index,2));
                if td<=lo,contact=time>=td&time<=lo;else,contact=time>=td|time<=lo;end
                modes.(names{index})=logical(contact(:));
            end
        end
    end
end
function value=subsetModes(modes,indices)
value=struct();names=fieldnames(modes);
for index=1:numel(names),item=modes.(names{index});value.(names{index})=item(indices);end
end
