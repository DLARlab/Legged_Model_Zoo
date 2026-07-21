classdef PlanarTranslationSymmetry < lmz.poincare.StateSymmetry
    %PLANARTRANSLATIONSYMMETRY Explicit translation of named positions.
    properties (SetAccess = private)
        PositionStateNames = {'x'}
    end

    methods
        function obj = PlanarTranslationSymmetry(id, positionStateNames)
            if nargin < 1 || isempty(id)
                id = 'planar_translation';
            end
            if nargin < 2 || isempty(positionStateNames)
                positionStateNames = {'x'};
            elseif ischar(positionStateNames)
                positionStateNames = {positionStateNames};
            elseif isstring(positionStateNames)
                positionStateNames = cellstr(positionStateNames(:));
            end
            if ~iscell(positionStateNames) || isempty(positionStateNames) || ...
                    ~all(cellfun(@(x) ischar(x) && ~isempty(regexp(x, ...
                    '^[A-Za-z][A-Za-z0-9_]*$', 'once')), positionStateNames)) || ...
                    numel(unique(positionStateNames)) ~= numel(positionStateNames)
                error('lmz:Poincare:TranslationStates', ...
                    'Translation state names must be unique identifiers.');
            end
            obj@lmz.poincare.StateSymmetry(id);
            obj.PositionStateNames = reshape(positionStateNames, 1, []);
        end

        function value = apply(obj, state, amount, stateSchema)
            value = obj.transform(state, amount, stateSchema);
        end

        function value = inverse(obj, state, amount, stateSchema)
            value = obj.transform(state, -amount, stateSchema);
        end

        function value = displacement(obj, returnedState, referenceState, stateSchema)
            if ~isa(stateSchema, 'lmz.schema.VariableSchema')
                error('lmz:Poincare:StateSchema', ...
                    'Planar translation requires a VariableSchema.');
            end
            stateSchema.validateVector(returnedState);
            stateSchema.validateVector(referenceState);
            index = stateSchema.indexOf(obj.PositionStateNames{1});
            value = returnedState(index) - referenceState(index);
        end

        function value = toStruct(obj)
            value = toStruct@lmz.poincare.StateSymmetry(obj);
            value.positionStateNames = obj.PositionStateNames;
        end
    end

    methods (Access = private)
        function value = transform(obj, state, amount, stateSchema)
            if ~isa(stateSchema, 'lmz.schema.VariableSchema')
                error('lmz:Poincare:StateSchema', ...
                    'Planar translation requires a VariableSchema.');
            end
            if ~isnumeric(amount) || ~isscalar(amount) || ~isfinite(amount)
                error('lmz:Poincare:SymmetryAmount', ...
                    'Translation amount must be a finite scalar.');
            end
            if ~isnumeric(state) || ~isreal(state) || any(~isfinite(state(:)))
                error('lmz:Poincare:SymmetryState', ...
                    'Translated states must be finite real numeric data.');
            end
            indices = zeros(1, numel(obj.PositionStateNames));
            for index = 1:numel(indices)
                indices(index) = stateSchema.indexOf( ...
                    obj.PositionStateNames{index});
            end
            value = state;
            if isvector(state)
                if numel(state) ~= stateSchema.count()
                    error('lmz:Poincare:SymmetryState', ...
                        'Translated state does not match its schema.');
                end
                column = state(:);
                column(indices) = column(indices) + amount;
                value = reshape(column, size(state));
            elseif size(state, 2) == stateSchema.count()
                value(:, indices) = value(:, indices) + amount;
            elseif size(state, 1) == stateSchema.count()
                value(indices, :) = value(indices, :) + amount;
            else
                error('lmz:Poincare:SymmetryState', ...
                    'Translated state matrix does not match its schema.');
            end
        end
    end
end
