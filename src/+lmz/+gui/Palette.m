classdef Palette
    %PALETTE Accessible default and high-contrast presentation colors.
    methods (Static)
        function value = named(name)
            name = char(name);
            switch name
                case 'default'
                    value = struct('Name','default','Background',[.94 .94 .94], ...
                        'Foreground',[.10 .10 .10],'AxesBackground',[1 1 1], ...
                        'LockedColor',[1 .78 0],'LockedMarker','p', ...
                        'HoverColor',[1 1 1],'HoverMarker','o', ...
                        'Accent',[0 .447 .741]);
                case 'high-contrast'
                    value = struct('Name','high-contrast','Background',[0 0 0], ...
                        'Foreground',[1 1 1],'AxesBackground',[.08 .08 .08], ...
                        'LockedColor',[1 1 0],'LockedMarker','p', ...
                        'HoverColor',[0 1 1],'HoverMarker','d', ...
                        'Accent',[1 .55 0]);
                otherwise
                    error('lmz:GUI:Palette','Unknown palette %s.',name);
            end
        end

        function result = distinguishableSelectionMarkers(name)
            value = lmz.gui.Palette.named(name);
            result = ~strcmp(value.LockedMarker,value.HoverMarker) && ...
                any(value.LockedColor~=value.HoverColor);
        end
    end
end
