classdef FeasibilityPolicy
    %FEASIBILITYPOLICY Scientific validity kept separate from residuals.
    methods (Static)
        function value=assess(decision,offsets,residual,states)
            messages={};
            valid=numel(decision)==12 && numel(offsets)==2 && ...
                all(isfinite(decision(:))) && all(isfinite(offsets(:))) && ...
                all(isfinite(residual(:))) && decision(12)>0;
            if ~valid,messages{end+1}='Candidate contains invalid values.';end %#ok<AGROW>
            if numel(decision)==12 && decision(1)<=0.01
                valid=false;messages{end+1}='Forward apex velocity must exceed 0.01.'; %#ok<AGROW>
            end
            minimumHeight=NaN;
            if nargin>=4 && ~isempty(states)
                minimumHeight=min(states(:,3));
                if minimumHeight<=0
                    valid=false;messages{end+1}='Body height reached the ground.'; %#ok<AGROW>
                end
            end
            minimumGap=NaN;
            if numel(decision)==12 && decision(12)>0
                events=sort(mod(decision(8:11),decision(12)));
                gaps=diff([events;events(1)+decision(12)]);minimumGap=min(gaps);
            end
            value=struct('Valid',valid,'Messages',{messages}, ...
                'MinimumEventGap',minimumGap,'MinimumBodyHeight',minimumHeight);
        end
    end
end
