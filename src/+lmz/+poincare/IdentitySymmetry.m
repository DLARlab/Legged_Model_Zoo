classdef IdentitySymmetry < lmz.poincare.StateSymmetry
    %IDENTITYSYMMETRY Identity action for models without quotient symmetry.
    methods
        function obj = IdentitySymmetry(id)
            if nargin < 1
                id = 'identity';
            end
            obj@lmz.poincare.StateSymmetry(id);
        end

        function value = apply(~, state, amount, stateSchema)
            localValidate(state, amount, stateSchema);
            value = state;
        end

        function value = inverse(~, state, amount, stateSchema)
            localValidate(state, amount, stateSchema);
            value = state;
        end
    end
end

function localValidate(state, amount, schema)
if ~isa(schema, 'lmz.schema.VariableSchema') || ...
        ~isnumeric(state) || ~isreal(state) || any(~isfinite(state(:))) || ...
        (~isvector(state) && size(state, 1) ~= schema.count() && ...
        size(state, 2) ~= schema.count())
    error('lmz:Poincare:SymmetryState', ...
        'Identity symmetry state does not match its schema.');
end
if isvector(state) && numel(state) ~= schema.count()
    error('lmz:Poincare:SymmetryState', ...
        'Identity symmetry state does not match its schema.');
end
if ~isnumeric(amount) || ~isscalar(amount) || ~isfinite(amount)
    error('lmz:Poincare:SymmetryAmount', ...
        'Symmetry amount must be a finite scalar.');
end
end
