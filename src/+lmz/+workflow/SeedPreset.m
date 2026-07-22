classdef SeedPreset
    %SEEDPRESET Declarative first/second seed policy.
    properties (SetAccess = private)
        FirstSeed
        SecondSeedOptions
        DefaultSecondSeed
        GeneratedRadius
        Options
    end
    methods
        function obj = SeedPreset(value)
            if nargin < 1 || isempty(value), value = struct(); end
            if ~isstruct(value) || ~isscalar(value)
                error('lmz:Workflow:SeedPreset', ...
                    'seedPreset must be one object.');
            end
            obj.FirstSeed = fieldOr(value, 'firstSeed', 'locked_point');
            obj.SecondSeedOptions = textList(fieldOr(value, ...
                'secondSeedOptions', {'adjacent_next','adjacent_previous', ...
                'generated_corrected'}));
            obj.DefaultSecondSeed = fieldOr(value, 'defaultSecondSeed', ...
                firstOr(obj.SecondSeedOptions, 'adjacent_next'));
            obj.GeneratedRadius = fieldOr(value, 'generatedRadius', 0.005);
            obj.Options = fieldOr(value, 'options', struct());
            if ~ischar(obj.FirstSeed) || ~ischar(obj.DefaultSecondSeed) || ...
                    ~any(strcmp(obj.DefaultSecondSeed,obj.SecondSeedOptions)) || ...
                    ~isnumeric(obj.GeneratedRadius) || ...
                    ~isscalar(obj.GeneratedRadius) || ...
                    ~isfinite(obj.GeneratedRadius) || obj.GeneratedRadius <= 0 || ...
                    ~isstruct(obj.Options) || ~isscalar(obj.Options)
                error('lmz:Workflow:SeedPreset', ...
                    'The seed preset is invalid.');
            end
        end

        function value = toStruct(obj)
            value = struct('firstSeed',obj.FirstSeed, ...
                'secondSeedOptions',{obj.SecondSeedOptions}, ...
                'defaultSecondSeed',obj.DefaultSecondSeed, ...
                'generatedRadius',obj.GeneratedRadius,'options',obj.Options);
        end
    end
end

function values = textList(value)
if ischar(value)
    values = {value};
elseif iscell(value) && all(cellfun(@ischar,value))
    values = value(:)';
else
    error('lmz:Workflow:SeedPreset','Seed options must be text.');
end
end
function value = firstOr(values, fallback)
if isempty(values), value = fallback; else, value = values{1}; end
end
function value = fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
