classdef NStridePeriodicCodec
    %NSTRIDEPERIODICCODEC Split X_accum into unknowns and fixed parameters.
    properties (SetAccess = private)
        NumberOfStrides
        Template
        DecisionIndices
        ParameterIndices
        DecisionSchema
        ParameterSchema
    end

    methods
        function obj = NStridePeriodicCodec(template)
            template = lmzmodels.slip_quad_load.XAccumAdapter.encode(template);
            count = lmzmodels.slip_quad_load.XAccumAdapter. ...
                strideCount(template);
            full = lmzmodels.slip_quad_load.MultiStrideDecisionSchema. ...
                create(count, template);
            decision = [1:13, 37:38, 14:22];
            for stride = 2:count
                indices = lmzmodels.slip_quad_load.LaterStrideLayout. ...
                    globalIndices(stride);
                decision = [decision, indices.EventTiming]; %#ok<AGROW>
            end
            parameters = setdiff(1:numel(template), decision, 'stable');
            obj.NumberOfStrides = count;
            obj.Template = template(:);
            obj.DecisionIndices = decision(:);
            obj.ParameterIndices = parameters(:);
            obj.DecisionSchema = lmz.schema.VariableSchema( ...
                full.Specs(obj.DecisionIndices), full.Version);
            obj.ParameterSchema = lmz.schema.VariableSchema( ...
                full.Specs(obj.ParameterIndices), full.Version);
        end

        function value = decisionDefaults(obj)
            value = obj.Template(obj.DecisionIndices);
        end

        function value = parameterDefaults(obj)
            value = obj.Template(obj.ParameterIndices);
        end

        function value = expand(obj, decision, parameters)
            obj.DecisionSchema.validateVector(decision);
            obj.ParameterSchema.validateVector(parameters);
            value = obj.Template;
            value(obj.DecisionIndices) = decision(:);
            value(obj.ParameterIndices) = parameters(:);
            value = lmzmodels.slip_quad_load.XAccumAdapter.encode(value);
        end

        function value = toStruct(obj)
            value = struct('Layout', '44+13*(N-1)', ...
                'NumberOfStrides', obj.NumberOfStrides, ...
                'DecisionIndices', obj.DecisionIndices, ...
                'ParameterIndices', obj.ParameterIndices, ...
                'UnknownCount', obj.DecisionSchema.count(), ...
                'FixedParameterCount', obj.ParameterSchema.count());
        end
    end
end
