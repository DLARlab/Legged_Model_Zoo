classdef VariableChart
    %VARIABLECHART Product-chart operations over a VariableSchema.
    properties (SetAccess=private)
        Schema
    end

    methods
        function obj = VariableChart(schema)
            obj.Schema = schema;
        end

        function difference = difference(obj, first, second)
            obj.Schema.validateVector(first);
            obj.Schema.validateVector(second);
            difference = first(:) - second(:);
            periods = obj.Schema.resolvePeriods(second);
            for index = 1:obj.Schema.count()
                if isfinite(periods(index))
                    period = periods(index);
                    difference(index) = mod( ...
                        difference(index) + period / 2, period) - period / 2;
                end
            end
        end

        function candidate = retract(obj, base, delta)
            base = base(:);
            delta = delta(:);
            if numel(base) ~= obj.Schema.count() || ...
                    numel(delta) ~= obj.Schema.count()
                error('lmz:Schema:InvalidRetractionSize', ...
                    'Base and delta must match the schema size.');
            end
            candidate = base + delta;
            % Period variables may change in this step. Resolve cyclic periods
            % from the candidate, not from the base point.
            periods = obj.Schema.resolvePeriods(candidate);
            candidate = obj.wrap(candidate, periods);
            obj.Schema.validateVector(candidate);
        end

        function candidate = canonicalize(obj, candidate)
            candidate = candidate(:);
            periods = obj.Schema.resolvePeriods(candidate);
            candidate = obj.wrap(candidate, periods);
            obj.Schema.validateVector(candidate);
        end
    end

    methods (Access=private)
        function candidate = wrap(obj, candidate, periods)
            for index = 1:obj.Schema.count()
                if ~isfinite(periods(index))
                    continue
                end
                spec = obj.Schema.Specs(index);
                period = periods(index);
                if strcmp(spec.Topology, 'angle') && ...
                        isfinite(spec.LowerBound)
                    origin = spec.LowerBound;
                else
                    origin = 0;
                end
                candidate(index) = origin + ...
                    mod(candidate(index) - origin, period);
            end
        end
    end
end
