classdef SectionCrossing
    %SECTIONCROSSING Normalized section-crossing state and diagnostics.
    properties (SetAccess = private)
        SectionId = ''
        Time = 0
        EventId = ''
        ModeBefore = ''
        ModeAfter = ''
        PreState = zeros(0, 1)
        PostState = zeros(0, 1)
        StateSide = 'post'
        State = zeros(0, 1)
        Value = 0
        DirectionalDerivative = NaN
        CrossingDirection = 0
        Grazing = false
        Occurrence = 1
        Accepted = false
        RejectionReason = ''
        Metadata = struct()
    end

    methods
        function obj = SectionCrossing(sectionId, time, varargin)
            if nargin == 0
                return
            end
            parser = inputParser;
            addRequired(parser, 'sectionId', @ischar);
            addRequired(parser, 'time', @(x) isnumeric(x) && isscalar(x) && ...
                isreal(x) && isfinite(x));
            addParameter(parser, 'EventId', '', @ischar);
            addParameter(parser, 'ModeBefore', '', @ischar);
            addParameter(parser, 'ModeAfter', '', @ischar);
            addParameter(parser, 'PreState', zeros(0, 1), @localState);
            addParameter(parser, 'PostState', zeros(0, 1), @localState);
            addParameter(parser, 'StateSide', 'post', @ischar);
            addParameter(parser, 'Value', 0, @(x) isnumeric(x) && ...
                isscalar(x) && isreal(x) && isfinite(x));
            addParameter(parser, 'DirectionalDerivative', NaN, ...
                @(x) isnumeric(x) && isscalar(x) && isreal(x) && ...
                (isfinite(x) || isnan(x)));
            addParameter(parser, 'CrossingDirection', 0, ...
                @(x) isnumeric(x) && isscalar(x) && ismember(x, [-1 0 1]));
            addParameter(parser, 'Grazing', false, ...
                @(x) islogical(x) && isscalar(x));
            addParameter(parser, 'Occurrence', 1, @(x) isnumeric(x) && ...
                isscalar(x) && isfinite(x) && x >= 1 && x == fix(x));
            addParameter(parser, 'Accepted', false, ...
                @(x) islogical(x) && isscalar(x));
            addParameter(parser, 'RejectionReason', '', @ischar);
            addParameter(parser, 'Metadata', struct(), ...
                @(x) isstruct(x) && isscalar(x));
            parse(parser, sectionId, time, varargin{:});
            values = parser.Results;
            if isempty(regexp(values.sectionId, '^[a-z][a-z0-9_]*$', 'once'))
                error('lmz:Poincare:CrossingSectionId', ...
                    'Crossing section ID is invalid.');
            end
            if ~any(strcmp(values.StateSide, {'pre','post'}))
                error('lmz:Poincare:CrossingStateSide', ...
                    'Crossing state side must be pre or post.');
            end
            preState = values.PreState(:);
            postState = values.PostState(:);
            if isempty(preState) && ~isempty(postState)
                preState = postState;
            elseif isempty(postState) && ~isempty(preState)
                postState = preState;
            end
            if numel(preState) ~= numel(postState)
                error('lmz:Poincare:CrossingStateDimension', ...
                    'Crossing pre/post states must have equal dimensions.');
            end
            if strcmp(values.StateSide, 'pre')
                selectedState = preState;
            else
                selectedState = postState;
            end
            obj.SectionId = values.sectionId;
            obj.Time = values.time;
            obj.EventId = values.EventId;
            obj.ModeBefore = values.ModeBefore;
            obj.ModeAfter = values.ModeAfter;
            obj.PreState = preState;
            obj.PostState = postState;
            obj.StateSide = values.StateSide;
            obj.State = selectedState;
            obj.Value = values.Value;
            obj.DirectionalDerivative = values.DirectionalDerivative;
            obj.CrossingDirection = values.CrossingDirection;
            obj.Grazing = values.Grazing;
            obj.Occurrence = values.Occurrence;
            obj.Accepted = values.Accepted;
            obj.RejectionReason = values.RejectionReason;
            obj.Metadata = values.Metadata;
        end

        function value = withAcceptance(obj, accepted, reason)
            if nargin < 3
                reason = '';
            end
            value = lmz.poincare.SectionCrossing(obj.SectionId, obj.Time, ...
                'EventId', obj.EventId, 'ModeBefore', obj.ModeBefore, ...
                'ModeAfter', obj.ModeAfter, 'PreState', obj.PreState, ...
                'PostState', obj.PostState, 'StateSide', obj.StateSide, ...
                'Value', obj.Value, ...
                'DirectionalDerivative', obj.DirectionalDerivative, ...
                'CrossingDirection', obj.CrossingDirection, ...
                'Grazing', obj.Grazing, 'Occurrence', obj.Occurrence, ...
                'Accepted', logical(accepted), ...
                'RejectionReason', reason, 'Metadata', obj.Metadata);
        end

        function value = toStruct(obj)
            value = struct('sectionId', obj.SectionId, 'time', obj.Time, ...
                'eventId', obj.EventId, 'modeBefore', obj.ModeBefore, ...
                'modeAfter', obj.ModeAfter, 'preState', obj.PreState, ...
                'postState', obj.PostState, 'stateSide', obj.StateSide, ...
                'state', obj.State, 'value', obj.Value, ...
                'directionalDerivative', obj.DirectionalDerivative, ...
                'crossingDirection', obj.CrossingDirection, ...
                'grazing', obj.Grazing, 'occurrence', obj.Occurrence, ...
                'accepted', obj.Accepted, ...
                'rejectionReason', obj.RejectionReason, ...
                'metadata', obj.Metadata);
        end
    end

    methods (Static)
        function obj = fromStruct(value)
            required = {'sectionId','time','eventId','modeBefore', ...
                'modeAfter','preState','postState','stateSide','value', ...
                'directionalDerivative','crossingDirection','grazing', ...
                'occurrence','accepted','rejectionReason','metadata'};
            if ~isstruct(value) || ~isscalar(value) || ...
                    ~all(isfield(value, required))
                error('lmz:Poincare:StoredCrossing', ...
                    'Stored section crossing data are incomplete.');
            end
            obj = lmz.poincare.SectionCrossing(value.sectionId,value.time, ...
                'EventId',value.eventId,'ModeBefore',value.modeBefore, ...
                'ModeAfter',value.modeAfter,'PreState',value.preState, ...
                'PostState',value.postState,'StateSide',value.stateSide, ...
                'Value',value.value, ...
                'DirectionalDerivative',value.directionalDerivative, ...
                'CrossingDirection',value.crossingDirection, ...
                'Grazing',logical(value.grazing), ...
                'Occurrence',value.occurrence, ...
                'Accepted',logical(value.accepted), ...
                'RejectionReason',value.rejectionReason, ...
                'Metadata',value.metadata);
        end
    end
end

function valid = localState(value)
valid = isnumeric(value) && isreal(value) && isvector(value) && ...
    all(isfinite(value(:)));
end
