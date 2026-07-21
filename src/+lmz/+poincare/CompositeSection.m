classdef CompositeSection < lmz.poincare.PoincareSection
    %COMPOSITESECTION Scalar primary section plus trusted acceptance checks.
    properties (SetAccess = private)
        Primary
        Conditions
    end

    methods
        function obj = CompositeSection(descriptor, primary, conditions)
            obj@lmz.poincare.PoincareSection(descriptor);
            if ~strcmp(obj.Kind, 'composite')
                error('lmz:Poincare:CompositeKind', ...
                    'CompositeSection requires kind composite.');
            end
            if ~isa(primary, 'lmz.poincare.PoincareSection')
                error('lmz:Poincare:CompositePrimary', ...
                    'Composite primary must be a PoincareSection.');
            end
            if nargin < 3 || isempty(conditions)
                conditions = {};
            elseif ~iscell(conditions)
                conditions = {conditions};
            end
            for index = 1:numel(conditions)
                condition = conditions{index};
                if ~isa(condition, 'function_handle') && ...
                        ~(isobject(condition) && ...
                        ismethod(condition, 'acceptCrossing'))
                    error('lmz:Poincare:CompositeCondition', ...
                        ['Composite conditions must be trusted callbacks or ' ...
                        'objects implementing acceptCrossing.']);
                end
            end
            obj.Primary = primary;
            obj.Conditions = reshape(conditions, 1, []);
        end

        function result = value(obj, time, state, parameters, modeId)
            result = obj.Primary.value(time, state, parameters, modeId);
        end

        function result = gradient(obj, time, state, parameters, modeId)
            result = obj.Primary.gradient(time, state, parameters, modeId);
        end

        function result = directionalDerivative(obj, time, state, ...
                parameters, modeId, flow)
            result = obj.Primary.directionalDerivative( ...
                time, state, parameters, modeId, flow);
        end

        function result = coordinates(obj, state, stateSchema)
            if isempty(obj.Descriptor.CoordinateNames)
                result = obj.Primary.coordinates(state, stateSchema);
            else
                result = coordinates@lmz.poincare.PoincareSection( ...
                    obj, state, stateSchema);
            end
        end

        function [accepted, reason] = acceptCrossing(obj, crossing, eventHistory)
            if nargin < 3
                eventHistory = {};
            end
            [accepted, reason] = acceptCrossing@lmz.poincare.PoincareSection( ...
                obj, crossing, eventHistory);
            if ~accepted
                return
            end
            for index = 1:numel(obj.Conditions)
                condition = obj.Conditions{index};
                if isa(condition, 'function_handle')
                    if nargout(condition) == 1
                        valid = condition(crossing, eventHistory);
                        conditionReason = sprintf('condition-%d', index);
                    else
                        [valid, conditionReason] = ...
                            condition(crossing, eventHistory);
                    end
                else
                    [valid, conditionReason] = ...
                        condition.acceptCrossing(crossing, eventHistory);
                end
                if ~islogical(valid) || ~isscalar(valid)
                    error('lmz:Poincare:CompositeConditionResult', ...
                        'Composite condition result must be a logical scalar.');
                end
                if ~valid
                    accepted = false;
                    if isempty(conditionReason)
                        conditionReason = sprintf('condition-%d', index);
                    end
                    reason = conditionReason;
                    return
                end
            end
        end

        function valid = matches(obj, record)
            %MATCHES Delegate named-event matching to the scalar primary.
            valid = isa(obj.Primary, 'lmz.poincare.NamedEventSection') && ...
                obj.Primary.matches(record);
        end

        function crossing = crossingFromRecord(obj, record, varargin)
            %CROSSINGFROMRECORD Rebind a named primary crossing to this section.
            if ~isa(obj.Primary, 'lmz.poincare.NamedEventSection')
                error('lmz:Poincare:CompositePrimaryKind', ...
                    'Composite named-event crossing requires a named primary.');
            end
            primaryCrossing = obj.Primary.crossingFromRecord(record, varargin{:});
            history = localField(primaryCrossing.Metadata, ...
                'EventHistory', {});
            crossing = obj.rebindCrossing(primaryCrossing, history);
        end

        function [detected, crossing] = detectCrossing(obj, firstTime, ...
                firstState, secondTime, secondState, varargin)
            %DETECTCROSSING Delegate state-plane detection to the primary.
            if ~isa(obj.Primary, 'lmz.poincare.StateFunctionSection')
                error('lmz:Poincare:CompositePrimaryKind', ...
                    'Composite state detection requires a state-plane primary.');
            end
            [detected, primaryCrossing] = obj.Primary.detectCrossing( ...
                firstTime, firstState, secondTime, secondState, varargin{:});
            if ~detected
                crossing = lmz.poincare.SectionCrossing.empty(0, 1);
                return
            end
            history = localField(primaryCrossing.Metadata, ...
                'EventHistory', {});
            crossing = obj.rebindCrossing(primaryCrossing, history);
        end
    end

    methods (Access = private)
        function crossing = rebindCrossing(obj, source, eventHistory)
            metadata = source.Metadata;
            metadata.PrimarySectionId = obj.Primary.Id;
            metadata.EventHistory = eventHistory;
            crossing = lmz.poincare.SectionCrossing(obj.Id, source.Time, ...
                'EventId', source.EventId, ...
                'ModeBefore', source.ModeBefore, ...
                'ModeAfter', source.ModeAfter, ...
                'PreState', source.PreState, ...
                'PostState', source.PostState, ...
                'StateSide', obj.StateSide, 'Value', source.Value, ...
                'DirectionalDerivative', source.DirectionalDerivative, ...
                'CrossingDirection', source.CrossingDirection, ...
                'Grazing', source.Grazing, ...
                'Occurrence', source.Occurrence, 'Metadata', metadata);
            [accepted, reason] = obj.acceptCrossing(crossing, eventHistory);
            crossing = crossing.withAcceptance(accepted, reason);
        end
    end
end

function value = localField(source, name, fallback)
if isstruct(source) && isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end
