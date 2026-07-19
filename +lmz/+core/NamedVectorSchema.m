classdef NamedVectorSchema
    properties (SetAccess=private)
        Version char = '1.0'
        Entries struct = struct([])
    end
    methods
        function obj = NamedVectorSchema(entries, version)
            if nargin < 1, entries = struct([]); end
            if nargin > 1, obj.Version = char(version); end
            obj.Entries = obj.normalize(entries); report=obj.validateDefinition(); report.throwIfInvalid();
        end
        function n = width(obj), n = sum([obj.Entries.size]); end
        function keys = keys(obj), keys = {obj.Entries.key}; end
        function slice = slice(obj, key)
            i = find(strcmp(obj.keys(), char(key)), 1);
            if isempty(i), error('lmz:UnknownKey', 'Unknown schema key "%s".', key); end
            first = 1 + sum([obj.Entries(1:i-1).size]); slice = first:(first+obj.Entries(i).size-1);
        end
        function x = defaults(obj), x = vertcat(obj.Entries.default); end
        function x = lowerBounds(obj), x = vertcat(obj.Entries.lower); end
        function x = upperBounds(obj), x = vertcat(obj.Entries.upper); end
        function x = scales(obj), x = vertcat(obj.Entries.scale); end
        function x = encode(obj, values)
            x = zeros(obj.width(),1);
            for i=1:numel(obj.Entries)
                k=obj.Entries(i).key;
                if isstruct(values), v=values.(k); elseif isa(values,'containers.Map'), v=values(k); else, error('lmz:EncodeType','Values must be a struct or map.'); end
                if numel(v)~=obj.Entries(i).size, error('lmz:Size','%s must contain %d values.',k,obj.Entries(i).size); end
                x(obj.slice(k))=v(:);
            end
        end
        function values = decode(obj, x)
            report=obj.validateVector(x); report.throwIfInvalid(); values=struct();
            for i=1:numel(obj.Entries), k=obj.Entries(i).key; values.(k)=reshape(x(obj.slice(k)),[],1); end
        end
        function report = validateVector(obj,x)
            report=lmz.core.ValidationReport();
            if ~isnumeric(x)||~isvector(x)||numel(x)~=obj.width(), report=report.addError(sprintf('Expected numeric vector of width %d.',obj.width())); return; end
            if any(~isfinite(x)), report=report.addError('Vector contains non-finite values.'); end
            if any(x(:)<obj.lowerBounds())||any(x(:)>obj.upperBounds()), report=report.addError('Vector violates schema bounds.'); end
        end
        function report = validateDefinition(obj)
            report=lmz.core.ValidationReport(); k=obj.keys();
            if numel(unique(k))~=numel(k), report=report.addError('Schema keys must be unique.'); end
            for i=1:numel(obj.Entries)
                e=obj.Entries(i);
                if e.size<1||fix(e.size)~=e.size, report=report.addError(['Invalid size for ' e.key]); end
                if any(~isfinite(e.default))||any(~isfinite(e.scale))||any(e.scale<=0), report=report.addError(['Invalid default/scale for ' e.key]); end
                if any(e.lower>e.upper)||any(e.default<e.lower)||any(e.default>e.upper), report=report.addError(['Inconsistent bounds for ' e.key]); end
            end
        end
    end
    methods (Static)
        function e = entry(key,label,group,units,default,lower,upper,scale,varargin)
            n=numel(default); e=struct('key',char(key),'label',char(label),'group',char(group),'size',n,'units',char(units), ...
                'default',default(:),'lower',lmz.core.NamedVectorSchema.expand(lower,n),'upper',lmz.core.NamedVectorSchema.expand(upper,n), ...
                'scale',lmz.core.NamedVectorSchema.expand(scale,n),'periodic',false,'period',NaN,'transform','');
            if ~isempty(varargin), p=inputParser; addParameter(p,'Periodic',false); addParameter(p,'Period',NaN); addParameter(p,'Transform',''); parse(p,varargin{:}); e.periodic=p.Results.Periodic; e.period=p.Results.Period; e.transform=char(p.Results.Transform); end
        end
        function y=expand(x,n), if isscalar(x), y=repmat(x,n,1); else, y=x(:); end; if numel(y)~=n,error('lmz:SchemaSize','Entry metadata size mismatch.');end; end
    end
    methods (Access=private)
        function out=normalize(~,entries)
            out=entries(:).';
            for i=1:numel(out), out(i).default=out(i).default(:); out(i).lower=out(i).lower(:); out(i).upper=out(i).upper(:); out(i).scale=out(i).scale(:); end
        end
    end
end
