classdef EventSchedule
    properties, Times double=[]; Names cell={}; Types cell={}; end
    methods
        function obj=EventSchedule(times,names,types),if nargin>0,obj.Times=times(:);obj.Names=names(:);end;if nargin>2,obj.Types=types(:);else,obj.Types=repmat({'scheduled'},numel(obj.Times),1);end;end
        function report=validate(obj,horizon),report=lmz.core.ValidationReport();if numel(obj.Times)~=numel(obj.Names),report=report.addError('Event times/names mismatch.');end;if any(~isfinite(obj.Times))||any(obj.Times<0)||any(obj.Times>horizon),report=report.addError('Event times outside simulation horizon.');end,end
        function [times,order]=sorted(obj),[times,order]=sort(obj.Times,'ascend');end
    end
end
