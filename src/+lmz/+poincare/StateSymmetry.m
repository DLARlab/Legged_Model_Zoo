classdef (Abstract) StateSymmetry
    %STATESYMMETRY Explicit state action used for periodic comparison.
    properties (SetAccess = private)
        Id = ''
    end

    methods
        function obj = StateSymmetry(id)
            if nargin < 1
                id = 'identity';
            end
            if ~ischar(id) || isempty(regexp(id, ...
                    '^[a-z][a-z0-9_]*$', 'once'))
                error('lmz:Poincare:SymmetryId', ...
                    'State symmetry ID must be a lowercase identifier.');
            end
            obj.Id = id;
        end

        function value = align(obj, returnedState, referenceState, stateSchema)
            shift = obj.displacement(returnedState, referenceState, stateSchema);
            value = obj.inverse(returnedState, shift, stateSchema);
        end

        function value = displacement(~, returnedState, referenceState, stateSchema)
            localValidateVector(returnedState, stateSchema);
            localValidateVector(referenceState, stateSchema);
            value = 0;
        end

        function value = toStruct(obj)
            value = struct('id', obj.Id, 'class', class(obj));
        end
    end

    methods (Abstract)
        value = apply(obj, state, amount, stateSchema)
        value = inverse(obj, state, amount, stateSchema)
    end
end

function localValidateVector(value, schema)
if ~isa(schema, 'lmz.schema.VariableSchema')
    error('lmz:Poincare:StateSchema', ...
        'A VariableSchema is required for a state symmetry.');
end
schema.validateVector(value);
end
