classdef GuardEventPolicy
    %GUARDEVENTPOLICY Trusted-code state guard definitions for ODE events.
    properties (SetAccess = private)
        Definitions = struct([])
    end
    methods
        function obj = GuardEventPolicy(definitions)
            if nargin < 1 || isempty(definitions)
                return
            end
            if ~isstruct(definitions)
                error('lmz:Hybrid:GuardDefinitions', ...
                    'Guard definitions must be a struct array.');
            end
            required = {'Id','GuardFcn','Direction','Terminal','Priority', ...
                'FromMode','ToMode','ResetId'};
            for element = 1:numel(definitions)
                for index = 1:numel(required)
                    if ~isfield(definitions(element), required{index})
                        error('lmz:Hybrid:GuardField', ...
                            'Guard definition is missing %s.', required{index});
                    end
                end
                if ~isa(definitions(element).GuardFcn, 'function_handle') || ...
                        ~isscalar(definitions(element).Direction) || ...
                        ~ismember(definitions(element).Direction, [-1 0 1]) || ...
                        ~islogical(definitions(element).Terminal) || ...
                        ~isscalar(definitions(element).Terminal)
                    error('lmz:Hybrid:GuardContract', ...
                        'Guard callback, direction, or terminal flag is invalid.');
                end
            end
            obj.Definitions = definitions(:);
        end

        function [value, terminal, direction, mapping] = evaluate(obj, ...
                time, state, modeId, parameters, context)
            active = arrayfun(@(x) isempty(x.FromMode) || ...
                strcmp(x.FromMode, modeId), obj.Definitions);
            mapping = find(active);
            value = zeros(numel(mapping), 1);
            terminal = ones(numel(mapping), 1);
            direction = zeros(numel(mapping), 1);
            for index = 1:numel(mapping)
                definition = obj.Definitions(mapping(index));
                value(index) = definition.GuardFcn( ...
                    time, state, parameters, context);
                direction(index) = definition.Direction;
            end
        end

        function events = detected(obj, mapping, eventIndices, time)
            uniqueDefinitions = unique(mapping(eventIndices), 'stable');
            events = lmz.simulation.HybridEvent.empty(0, 1);
            for index = 1:numel(uniqueDefinitions)
                definitionIndex = uniqueDefinitions(index);
                definition = obj.Definitions(definitionIndex);
                events(end + 1, 1) = lmz.simulation.HybridEvent( ...
                    definition.Id, time, 'Priority', definition.Priority, ...
                    'DeclarationOrder', definitionIndex, ...
                    'FromMode', definition.FromMode, ...
                    'ToMode', definition.ToMode, ...
                    'ResetId', definition.ResetId, ...
                    'Terminal', definition.Terminal); %#ok<AGROW>
            end
            if ~isempty(events)
                keys = [[events.Priority].', [events.DeclarationOrder].'];
                [~, order] = sortrows(keys, [1 2]);
                events = events(order);
            end
        end
    end
end
