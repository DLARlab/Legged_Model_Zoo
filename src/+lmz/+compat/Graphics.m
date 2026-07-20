classdef Graphics
    %GRAPHICS Export axes through a preferred path or tested fallback.
    methods (Static)
        function exportAxes(axesHandle, path, resolution, forceFallback)
            if nargin < 3 || isempty(resolution)
                resolution = 150;
            end
            if nargin < 4
                forceFallback = false;
            end
            if isempty(axesHandle) || ~isgraphics(axesHandle, 'axes')
                error('lmz:Compatibility:Axes', 'A valid axes is required.');
            end
            if ~forceFallback && exist('exportgraphics', 'file') == 2
                [~, ~, extension] = fileparts(path);
                if strcmpi(extension, '.pdf')
                    exportgraphics(axesHandle, path, 'ContentType', 'auto');
                else
                    exportgraphics(axesHandle, path, 'Resolution', resolution);
                end
                return
            end
            lmz.compat.Graphics.exportFallback(axesHandle, path, resolution);
        end

        function tf = preferredExporterAvailable(forceFallback)
            if nargin < 1
                forceFallback = false;
            end
            tf = ~forceFallback && exist('exportgraphics', 'file') == 2;
        end
    end

    methods (Static, Access = private)
        function exportFallback(axesHandle, path, resolution)
            drawnow;
            frame = getframe(axesHandle);
            [~, ~, extension] = fileparts(path);
            switch lower(extension)
                case {'.png', '.jpg', '.jpeg', '.tif', '.tiff'}
                    imwrite(frame.cdata, path);
                case '.pdf'
                    figureHandle = figure('Visible', 'off', 'Color', 'white');
                    cleanup = onCleanup(@() delete(figureHandle));
                    copyAxes = axes('Parent', figureHandle, ...
                        'Position', [0 0 1 1]);
                    image(copyAxes, frame.cdata);
                    axis(copyAxes, 'image');
                    axis(copyAxes, 'off');
                    set(copyAxes, 'YDir', 'reverse');
                    print(figureHandle, path, '-dpdf', ...
                        sprintf('-r%d', resolution));
                    clear cleanup
                otherwise
                    error('lmz:Compatibility:GraphicsType', ...
                        ['Fallback export supports PNG, JPEG, TIFF, ' ...
                        'and PDF files.']);
            end
        end
    end
end
