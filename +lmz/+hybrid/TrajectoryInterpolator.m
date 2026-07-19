classdef TrajectoryInterpolator
    methods (Static)
        function x=sample(result,t,side)
            if nargin<3,side='post';end;T=result.time(:);Y=result.state;i=find(T==t);if ~isempty(i),if strcmp(side,'pre'),x=Y(i(1),:);else,x=Y(i(end),:);end;return;end
            [Tu,ia]=unique(T,'last');x=interp1(Tu,Y(ia,:),t,'pchip');
        end
    end
end
