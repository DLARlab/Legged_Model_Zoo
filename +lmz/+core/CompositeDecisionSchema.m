classdef CompositeDecisionSchema
    properties (SetAccess=private), Groups struct = struct([]); Version char='1.0'; end
    methods
        function obj=CompositeDecisionSchema(groups,version), if nargin>0,obj.Groups=groups;end;if nargin>1,obj.Version=char(version);end;end
        function n=width(obj), n=0; for i=1:numel(obj.Groups),n=n+obj.Groups(i).repeat*obj.Groups(i).schema.width();end,end
        function x=encode(obj,data)
            x=[]; for i=1:numel(obj.Groups),g=obj.Groups(i); vals=data.(g.key); if g.repeat==1&&~iscell(vals),vals={vals};end; for j=1:g.repeat,x=[x;g.schema.encode(vals{j})];end,end
        end
        function data=decode(obj,x)
            if numel(x)~=obj.width(),error('lmz:Size','Composite vector width mismatch.');end
            data=struct(); cursor=1; for i=1:numel(obj.Groups),g=obj.Groups(i); vals=cell(1,g.repeat); for j=1:g.repeat,n=g.schema.width();vals{j}=g.schema.decode(x(cursor:cursor+n-1));cursor=cursor+n;end;if g.repeat==1,data.(g.key)=vals{1};else,data.(g.key)=vals;end,end
        end
        function s=scales(obj),s=[];for i=1:numel(obj.Groups),for j=1:obj.Groups(i).repeat,s=[s;obj.Groups(i).schema.scales()];end,end,end
        function b=lowerBounds(obj),b=[];for i=1:numel(obj.Groups),for j=1:obj.Groups(i).repeat,b=[b;obj.Groups(i).schema.lowerBounds()];end,end,end
        function b=upperBounds(obj),b=[];for i=1:numel(obj.Groups),for j=1:obj.Groups(i).repeat,b=[b;obj.Groups(i).schema.upperBounds()];end,end,end
        function x=defaults(obj),x=[];for i=1:numel(obj.Groups),for j=1:obj.Groups(i).repeat,x=[x;obj.Groups(i).schema.defaults()];end,end,end
        function report=validateVector(obj,x),report=lmz.core.ValidationReport();if ~isnumeric(x)||~isvector(x)||numel(x)~=obj.width(),report=report.addError(sprintf('Expected numeric vector of width %d.',obj.width()));return;end;if any(~isfinite(x)),report=report.addError('Vector contains non-finite values.');end;if any(x(:)<obj.lowerBounds())||any(x(:)>obj.upperBounds()),report=report.addError('Vector violates schema bounds.');end,end
    end
    methods (Static), function g=group(key,schema,repeat),if nargin<3,repeat=1;end;g=struct('key',char(key),'schema',schema,'repeat',repeat);end,end
end
