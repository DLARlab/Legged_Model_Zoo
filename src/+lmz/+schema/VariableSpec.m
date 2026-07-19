classdef VariableSpec
    properties (SetAccess=private)
        Name; Label; LatexLabel; Group; Unit; Note; DefaultValue
        LowerBound; UpperBound; Scale; Topology; PeriodSource
    end
    methods
        function obj = VariableSpec(name, varargin)
            p = inputParser;
            addRequired(p, 'name', @(x)ischar(x) && ~isempty(x));
            addParameter(p, 'Label', name, @ischar); addParameter(p, 'LatexLabel', name, @ischar);
            addParameter(p, 'Group', 'general', @ischar); addParameter(p, 'Unit', '', @ischar);
            addParameter(p, 'Note', '', @ischar); addParameter(p, 'DefaultValue', 0, @(x)isnumeric(x)&&isscalar(x));
            addParameter(p, 'LowerBound', -Inf, @(x)isnumeric(x)&&isscalar(x));
            addParameter(p, 'UpperBound', Inf, @(x)isnumeric(x)&&isscalar(x));
            addParameter(p, 'Scale', 1, @(x)isnumeric(x)&&isscalar(x));
            addParameter(p, 'Topology', 'euclidean', @ischar); addParameter(p, 'PeriodSource', '', @ischar);
            parse(p, name, varargin{:}); r = p.Results;
            valid = {'euclidean','positive','bounded','angle','cyclic_time'};
            if r.LowerBound >= r.UpperBound, error('lmz:InvalidBounds','Lower bound must be below upper bound.'); end
            if ~isfinite(r.Scale) || r.Scale <= 0, error('lmz:InvalidScale','Scale must be positive and finite.'); end
            if ~any(strcmp(r.Topology, valid)), error('lmz:InvalidTopology','Unknown topology.'); end
            if strcmp(r.Topology,'positive') && r.LowerBound < 0, error('lmz:InvalidBounds','Positive variables require a nonnegative lower bound.'); end
            if strcmp(r.Topology,'cyclic_time') && isempty(r.PeriodSource), error('lmz:MissingPeriod','Cyclic time requires PeriodSource.'); end
            obj.Name=r.name; obj.Label=r.Label; obj.LatexLabel=r.LatexLabel; obj.Group=r.Group;
            obj.Unit=r.Unit; obj.Note=r.Note; obj.DefaultValue=r.DefaultValue;
            obj.LowerBound=r.LowerBound; obj.UpperBound=r.UpperBound; obj.Scale=r.Scale;
            obj.Topology=r.Topology; obj.PeriodSource=r.PeriodSource;
        end
        function s = toStruct(obj)
            props = properties(obj); s = struct();
            for k=1:numel(props), s.(props{k}) = obj.(props{k}); end
        end
    end
end
