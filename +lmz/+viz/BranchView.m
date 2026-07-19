classdef BranchView < handle
    properties, Axes; SelectionCallback=[]; end
    methods
        function obj=BranchView(ax),obj.Axes=ax;end
        function h=plot(obj,branch,xName,yName,varargin),x=arrayfun(@(p)localValue(p,xName),branch.Points);y=arrayfun(@(p)localValue(p,yName),branch.Points);h=plot(obj.Axes,x,y,'o-','PickableParts','all');h.ButtonDownFcn=@(~,e)obj.selectNearest(branch,x,y,e.IntersectionPoint);xlabel(obj.Axes,xName);ylabel(obj.Axes,yName);end
        function selectNearest(obj,b,x,y,p),[~,i]=min((x-p(1)).^2+(y-p(2)).^2);if ~isempty(obj.SelectionCallback),obj.SelectionCallback(b.Points(i));end,end
    end
end
function v=localValue(p,name),if strcmp(name,'arclength'),v=p.arclength;elseif isfield(p.observables,name),v=p.observables.(name);elseif isfield(p.decoded,name),v=p.decoded.(name);else,error('lmz:UnknownAxis','Unknown named branch axis %s.',name);end,end
