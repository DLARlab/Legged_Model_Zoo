classdef HybridEvent
    %HYBRIDEVENT Validated scheduled or detected transition definition.
    properties (SetAccess = private)
        Id = ''
        Time = NaN
        Priority = 0
        DeclarationOrder = 0
        FromMode = ''
        ToMode = ''
        ResetId = ''
        Terminal = false
        Metadata = struct()
    end
    methods
        function obj = HybridEvent(id, time, varargin)
            if nargin == 0
                return
            end
            parser = inputParser;
            addRequired(parser, 'id', @ischar);
            addRequired(parser, 'time', ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x));
            addParameter(parser, 'Priority', 0, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x));
            addParameter(parser, 'DeclarationOrder', 0, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
            addParameter(parser, 'FromMode', '', @ischar);
            addParameter(parser, 'ToMode', '', @ischar);
            addParameter(parser, 'ResetId', id, @ischar);
            addParameter(parser, 'Terminal', false, ...
                @(x) islogical(x) && isscalar(x));
            addParameter(parser, 'Metadata', struct(), ...
                @(x) isstruct(x) && isscalar(x));
            parse(parser, id, time, varargin{:});
            values = parser.Results;
            ids = {values.id, values.FromMode, values.ToMode, values.ResetId};
            for index = 1:numel(ids)
                if ~isempty(ids{index}) && isempty(regexp(ids{index}, ...
                        '^[A-Za-z][A-Za-z0-9_]*$', 'once'))
                    error('lmz:Hybrid:EventId', ...
                        'Hybrid event identifiers must be simple names.');
                end
            end
            obj.Id = values.id;
            obj.Time = values.time;
            obj.Priority = values.Priority;
            obj.DeclarationOrder = values.DeclarationOrder;
            obj.FromMode = values.FromMode;
            obj.ToMode = values.ToMode;
            obj.ResetId = values.ResetId;
            obj.Terminal = values.Terminal;
            obj.Metadata = values.Metadata;
        end
    end
end
