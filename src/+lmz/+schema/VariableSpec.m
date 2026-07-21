classdef VariableSpec
    %VARIABLESPEC Metadata and numerical topology for one named variable.
    properties (SetAccess=private)
        Name
        Label
        LatexLabel
        Group
        Unit
        Note
        DefaultValue
        LowerBound
        UpperBound
        Scale
        Topology
        PeriodSource
        Activity
        Role
        EnergyEffect
    end

    methods
        function obj = VariableSpec(name, varargin)
            parser = inputParser;
            addRequired(parser, 'name', @lmz.schema.VariableSpec.isName);
            addParameter(parser, 'Label', name, @ischar);
            addParameter(parser, 'LatexLabel', name, @ischar);
            addParameter(parser, 'Group', 'general', @ischar);
            addParameter(parser, 'Unit', '', @ischar);
            addParameter(parser, 'Note', '', @ischar);
            addParameter(parser, 'DefaultValue', 0, ...
                @lmz.schema.VariableSpec.isScalarReal);
            addParameter(parser, 'LowerBound', -Inf, ...
                @lmz.schema.VariableSpec.isScalarReal);
            addParameter(parser, 'UpperBound', Inf, ...
                @lmz.schema.VariableSpec.isScalarReal);
            addParameter(parser, 'Scale', 1, ...
                @lmz.schema.VariableSpec.isScalarReal);
            addParameter(parser, 'Topology', 'euclidean', @ischar);
            addParameter(parser, 'PeriodSource', '', @ischar);
            addParameter(parser, 'Activity', 'active', @ischar);
            addParameter(parser, 'Role', 'physical', @ischar);
            addParameter(parser, 'EnergyEffect', 'unknown', @ischar);
            parse(parser, name, varargin{:});
            values = parser.Results;

            if values.LowerBound >= values.UpperBound
                error('lmz:Schema:InvalidBounds', ...
                    'LowerBound must be below UpperBound for %s.', name);
            end
            if ~isfinite(values.Scale) || values.Scale <= 0
                error('lmz:Schema:InvalidScale', ...
                    'Scale must be positive and finite for %s.', name);
            end
            validTopologies = {'euclidean', 'positive', 'bounded', ...
                'angle', 'cyclic_time'};
            if ~any(strcmp(values.Topology, validTopologies))
                error('lmz:Schema:InvalidTopology', ...
                    'Unknown topology %s for %s.', values.Topology, name);
            end
            if strcmp(values.Topology, 'positive') && values.LowerBound < 0
                error('lmz:Schema:InvalidPositiveBounds', ...
                    'Positive variable %s requires LowerBound >= 0.', name);
            end
            if strcmp(values.Topology, 'bounded') && ...
                    (~isfinite(values.LowerBound) || ~isfinite(values.UpperBound))
                error('lmz:Schema:UnboundedBoundedVariable', ...
                    'Bounded variable %s requires finite bounds.', name);
            end
            if strcmp(values.Topology, 'cyclic_time') && ...
                    isempty(values.PeriodSource)
                error('lmz:Schema:MissingPeriodSource', ...
                    'Cyclic time %s requires PeriodSource.', name);
            end
            validActivities = {'active', 'inactive', 'derived'};
            if ~any(strcmp(values.Activity, validActivities))
                error('lmz:Schema:InvalidActivity', ...
                    'Unknown activity %s for %s.', values.Activity, name);
            end
            validRoles = {'physical', 'control', 'schedule', 'derived'};
            if ~any(strcmp(values.Role, validRoles))
                error('lmz:Schema:InvalidRole', ...
                    'Unknown role %s for %s.', values.Role, name);
            end
            validEnergyEffects = {'invariant', 'state_dependent', ...
                'work_input', 'unknown'};
            if ~any(strcmp(values.EnergyEffect, validEnergyEffects))
                error('lmz:Schema:InvalidEnergyEffect', ...
                    'Unknown energy effect %s for %s.', ...
                    values.EnergyEffect, name);
            end
            if ~isfinite(values.DefaultValue) || ...
                    values.DefaultValue < values.LowerBound || ...
                    values.DefaultValue > values.UpperBound
                error('lmz:Schema:InvalidDefault', ...
                    'DefaultValue is invalid for %s.', name);
            end

            obj.Name = values.name;
            obj.Label = values.Label;
            obj.LatexLabel = values.LatexLabel;
            obj.Group = values.Group;
            obj.Unit = values.Unit;
            obj.Note = values.Note;
            obj.DefaultValue = values.DefaultValue;
            obj.LowerBound = values.LowerBound;
            obj.UpperBound = values.UpperBound;
            obj.Scale = values.Scale;
            obj.Topology = values.Topology;
            obj.PeriodSource = values.PeriodSource;
            obj.Activity = values.Activity;
            obj.Role = values.Role;
            obj.EnergyEffect = values.EnergyEffect;
        end

        function value = toStruct(obj)
            value = struct( ...
                'Name', obj.Name, ...
                'Label', obj.Label, ...
                'LatexLabel', obj.LatexLabel, ...
                'Group', obj.Group, ...
                'Unit', obj.Unit, ...
                'Note', obj.Note, ...
                'DefaultValue', obj.DefaultValue, ...
                'LowerBound', obj.LowerBound, ...
                'UpperBound', obj.UpperBound, ...
                'Scale', obj.Scale, ...
                'Topology', obj.Topology, ...
                'PeriodSource', obj.PeriodSource, ...
                'Activity', obj.Activity, ...
                'Role', obj.Role, ...
                'EnergyEffect', obj.EnergyEffect);
        end
    end

    methods (Static)
        function obj = fromStruct(value)
            activity = 'active';
            if isfield(value, 'Activity')
                activity = value.Activity;
            end
            role = 'physical';
            if isfield(value, 'Role')
                role = value.Role;
            end
            energyEffect = 'unknown';
            if isfield(value, 'EnergyEffect')
                energyEffect = value.EnergyEffect;
            end
            obj = lmz.schema.VariableSpec(value.Name, ...
                'Label', value.Label, ...
                'LatexLabel', value.LatexLabel, ...
                'Group', value.Group, ...
                'Unit', value.Unit, ...
                'Note', value.Note, ...
                'DefaultValue', value.DefaultValue, ...
                'LowerBound', value.LowerBound, ...
                'UpperBound', value.UpperBound, ...
                'Scale', value.Scale, ...
                'Topology', value.Topology, ...
                'PeriodSource', value.PeriodSource, ...
                'Activity', activity, ...
                'Role', role, ...
                'EnergyEffect', energyEffect);
        end
    end

    methods (Static, Access=private)
        function valid = isName(value)
            valid = ischar(value) && ~isempty(regexp(value, ...
                '^[A-Za-z][A-Za-z0-9_]*$', 'once'));
        end

        function valid = isScalarReal(value)
            valid = isnumeric(value) && isreal(value) && isscalar(value);
        end
    end
end
