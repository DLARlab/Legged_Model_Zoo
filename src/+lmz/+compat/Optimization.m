classdef Optimization
    %OPTIMIZATION Translate solver options across supported releases.
    methods (Static)
        function options = fsolve(values, forceFallback)
            if nargin < 2
                forceFallback = false;
            end
            options = lmz.compat.Optimization.make( ...
                'fsolve', values, forceFallback);
        end

        function options = fmincon(values, forceFallback)
            if nargin < 2
                forceFallback = false;
            end
            options = lmz.compat.Optimization.make( ...
                'fmincon', values, forceFallback);
        end
    end

    methods (Static, Access = private)
        function options = make(solver, values, forceFallback)
            if ~isstruct(values) || ~isscalar(values)
                error('lmz:Compatibility:OptimizationOptions', ...
                    'Solver option values must be a scalar structure.');
            end
            names = fieldnames(values);
            pairs = cell(1, 2 * numel(names));
            for index = 1:numel(names)
                pairs{2 * index - 1} = names{index};
                pairs{2 * index} = values.(names{index});
            end
            if ~forceFallback && exist('optimoptions', 'file') == 2
                options = optimoptions(solver, pairs{:});
                return
            end
            translated = lmz.compat.Optimization.translate(values);
            names = fieldnames(translated);
            pairs = cell(1, 2 * numel(names));
            for index = 1:numel(names)
                pairs{2 * index - 1} = names{index};
                pairs{2 * index} = translated.(names{index});
            end
            options = optimset(pairs{:});
        end

        function values = translate(values)
            mapping = { ...
                'FunctionTolerance', 'TolFun'; ...
                'OptimalityTolerance', 'TolFun'; ...
                'StepTolerance', 'TolX'; ...
                'ConstraintTolerance', 'TolCon'; ...
                'MaxIterations', 'MaxIter'; ...
                'MaxFunctionEvaluations', 'MaxFunEvals'};
            for index = 1:size(mapping, 1)
                current = mapping{index, 1};
                legacy = mapping{index, 2};
                if isfield(values, current)
                    values.(legacy) = values.(current);
                    values = rmfield(values, current);
                end
            end
            if isfield(values, 'Algorithm') && isempty(values.Algorithm)
                values = rmfield(values, 'Algorithm');
            end
        end
    end
end
