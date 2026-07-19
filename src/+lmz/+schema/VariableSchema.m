classdef VariableSchema
    properties (SetAccess=private), Specs; Version; end
    methods
        function obj = VariableSchema(specs, version)
            if nargin<1, specs = lmz.schema.VariableSpec.empty(0,1); end
            if nargin<2, version = '1.0.0'; end
            names = arrayfun(@(x)x.Name, specs, 'UniformOutput', false);
            if numel(unique(names)) ~= numel(names), error('lmz:DuplicateVariable','Variable names must be unique.'); end
            obj.Specs = specs(:); obj.Version = version;
            for k=1:numel(specs)
                if strcmp(specs(k).Topology,'cyclic_time') && ~any(strcmp(specs(k).PeriodSource,names))
                    error('lmz:UnresolvedPeriod','Period source is not present in schema.');
                end
            end
        end
        function n = count(obj), n = numel(obj.Specs); end
        function names = names(obj), names = arrayfun(@(x)x.Name,obj.Specs,'UniformOutput',false); end
        function i = indexOf(obj,name)
            i=find(strcmp(name,obj.names()),1); if isempty(i), error('lmz:UnknownVariable','Unknown variable %s.',name); end
        end
        function v = defaults(obj), v=arrayfun(@(x)x.DefaultValue,obj.Specs(:)); end
        function values = unpack(obj, vector)
            obj.validateVector(vector); values=struct();
            for k=1:obj.count(), values.(obj.Specs(k).Name)=vector(k); end
        end
        function vector = pack(obj, values)
            vector=zeros(obj.count(),1); for k=1:obj.count(), vector(k)=values.(obj.Specs(k).Name); end
            obj.validateVector(vector);
        end
        function validateVector(obj,v)
            if ~isnumeric(v)||numel(v)~=obj.count()||any(~isfinite(v)), error('lmz:InvalidVector','Vector has wrong size or nonfinite values.'); end
            v=v(:); for k=1:obj.count()
                s=obj.Specs(k); if v(k)<s.LowerBound||v(k)>s.UpperBound, error('lmz:OutOfBounds','%s is outside bounds.',s.Name); end
            end
            obj.resolvePeriods(v);
        end
        function periods=resolvePeriods(obj,v)
            periods=nan(obj.count(),1);
            for k=1:obj.count()
                if strcmp(obj.Specs(k).Topology,'angle'), periods(k)=2*pi; end
                if strcmp(obj.Specs(k).Topology,'cyclic_time')
                    periods(k)=v(obj.indexOf(obj.Specs(k).PeriodSource));
                    if ~isfinite(periods(k))||periods(k)<=0, error('lmz:InvalidPeriod','Period must be positive and finite.'); end
                end
            end
        end
        function s=toStruct(obj)
            specs=cell(obj.count(),1); for k=1:obj.count(), specs{k}=obj.Specs(k).toStruct(); end
            s=struct('version',obj.Version,'orderedNames',{obj.names()},'variables',{specs});
        end
    end
end
