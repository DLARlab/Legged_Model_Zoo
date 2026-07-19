classdef PeriodicOrbitView
    methods (Static),function h=plot(ax,result,xName,yName),sx=result.state_schema.slice(xName);sy=result.state_schema.slice(yName);h=plot(ax,result.state(:,sx),result.state(:,sy));xlabel(ax,xName);ylabel(ax,yName);end,end
end
