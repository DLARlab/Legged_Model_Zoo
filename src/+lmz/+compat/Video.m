classdef Video
    %VIDEO Select an available VideoWriter profile in one place.
    methods (Static)
        function [writer, profile] = create(path, profiles, forceFallback)
            if nargin < 2 || isempty(profiles)
                profiles = {'MPEG-4', 'Motion JPEG AVI'};
            end
            if nargin < 3
                forceFallback = false;
            end
            if exist('VideoWriter', 'class') ~= 8
                error('lmz:Compatibility:VideoUnavailable', ...
                    'VideoWriter is unavailable in this MATLAB installation.');
            end
            profiles = lmz.compat.Text.cellstr(profiles, 'video profiles');
            if forceFallback && numel(profiles) > 1
                profiles = profiles(2:end);
            end
            messages = cell(1, numel(profiles));
            for index = 1:numel(profiles)
                try
                    writer = VideoWriter(path, profiles{index});
                    profile = profiles{index};
                    return
                catch exception
                    messages{index} = exception.message;
                end
            end
            error('lmz:Compatibility:VideoProfile', ...
                'No requested VideoWriter profile is available: %s', ...
                strjoin(messages, ' | '));
        end
    end
end
