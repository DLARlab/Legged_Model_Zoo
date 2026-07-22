classdef Accessibility
    %ACCESSIBILITY Shared GUI accessibility and layout helpers.
    properties (Constant)
        MinimumWindowSize = [900 650]
    end
    methods (Static)
        function tag(control,value,tooltip)
            if ~isempty(control)&&isvalid(control)
                if isprop(control,'Tag'), control.Tag = value; end
                if nargin>=3&&~isempty(tooltip)&&isprop(control,'Tooltip')
                    control.Tooltip = tooltip;
                end
            end
        end

        function enforceMinimumWindow(figureHandle)
            if isempty(figureHandle)||~isvalid(figureHandle), return, end
            position = figureHandle.Position;
            minimum = lmz.gui.Accessibility.MinimumWindowSize;
            position(3) = max(position(3),minimum(1));
            position(4) = max(position(4),minimum(2));
            if ~isequal(position,figureHandle.Position)
                figureHandle.Position = position;
            end
        end

        function applyPalette(figureHandle,axesHandles,palette)
            if ~isempty(figureHandle)&&isvalid(figureHandle)
                figureHandle.Color = palette.Background;
            end
            for index = 1:numel(axesHandles)
                axesHandle = axesHandles(index);
                if isempty(axesHandle)||~isgraphics(axesHandle), continue, end
                axesHandle.Color = palette.AxesBackground;
                axesHandle.XColor = palette.Foreground;
                axesHandle.YColor = palette.Foreground;
                axesHandle.ZColor = palette.Foreground;
            end
        end
    end
end
