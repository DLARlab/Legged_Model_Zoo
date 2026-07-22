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

        function imageData = captureAxes(axesHandle, resolution, forceFallback)
            %CAPTUREAXES Return a deterministic RGB capture of classic/UI axes.
            if nargin < 2 || isempty(resolution)
                resolution = 120;
            end
            if nargin < 3
                forceFallback = false;
            end
            temporary = lmz.compat.Files.temporary(tempdir, '.png');
            cleanup = onCleanup(@() deleteIfPresent(temporary));
            lmz.compat.Graphics.exportAxes(axesHandle, temporary, ...
                resolution, forceFallback);
            imageData = imread(temporary);
            if ismatrix(imageData)
                imageData = repmat(imageData, 1, 1, 3);
            elseif size(imageData, 3) > 3
                imageData = imageData(:, :, 1:3);
            end
            clear cleanup
        end

        function exportFigure(figureHandle,path,forceFallback)
            %EXPORTFIGURE Capture a complete UIFigure with a legacy fallback.
            if nargin<3,forceFallback=false;end
            if isempty(figureHandle)||~isgraphics(figureHandle,'figure')
                error('lmz:Compatibility:Figure', ...
                    'A valid figure is required.');
            end
            [~,~,extension]=fileparts(path);
            if ~strcmpi(extension,'.png')
                error('lmz:Compatibility:FigureType', ...
                    'Complete application captures currently require PNG.');
            end
            modernExporter='exportapp';
            if ~forceFallback&&exist(modernExporter,'file')==2
                exporter=str2func(modernExporter);
                exporter(figureHandle,path);return
            end
            drawnow;frame=getframe(figureHandle);
            imwrite(frame.cdata,path);
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
            [~, ~, extension] = fileparts(path);
            device = lmz.compat.Graphics.printDevice(extension);
            [figureHandle, ~] = ...
                lmz.compat.Graphics.copyToClassicAxes(axesHandle);
            cleanup = onCleanup(@() delete(figureHandle));
            drawnow;
            set(figureHandle, 'PaperPositionMode', 'auto');
            print(figureHandle, path, device, sprintf('-r%d', resolution));
            clear cleanup
        end

        function device = printDevice(extension)
            switch lower(extension)
                case '.png'
                    device = '-dpng';
                case {'.jpg', '.jpeg'}
                    device = '-djpeg';
                case {'.tif', '.tiff'}
                    device = '-dtiff';
                case '.pdf'
                    device = '-dpdf';
                otherwise
                    error('lmz:Compatibility:GraphicsType', ...
                        ['Fallback export supports PNG, JPEG, TIFF, ' ...
                        'and PDF files.']);
            end
        end

        function [figureHandle, copyAxes] = copyToClassicAxes(sourceAxes)
            drawnow;
            position = getpixelposition(sourceAxes, true);
            width = max(320, round(position(3)));
            height = max(240, round(position(4)));
            background = sourceAxes.Color;
            if ~isnumeric(background) || numel(background) ~= 3
                background = [1 1 1];
            end
            figureHandle = figure('Visible', 'off', 'Color', background, ...
                'Units', 'pixels', 'Position', [50 50 width height]);
            copyAxes = axes('Parent', figureHandle, 'Units', 'normalized', ...
                'Position', [0.10 0.10 0.84 0.84]);
            lmz.compat.Graphics.copyAxesProperties(sourceAxes, copyAxes);
            children = allchild(sourceAxes);
            decorations = [sourceAxes.XLabel;sourceAxes.YLabel; ...
                sourceAxes.ZLabel;sourceAxes.Title];
            for index = 1:numel(decorations)
                children(children == decorations(index)) = [];
            end
            if ~isempty(children)
                copyobj(flipud(children(:)), copyAxes);
            end
            lmz.compat.Graphics.copyAxesText(sourceAxes.XLabel, copyAxes.XLabel);
            lmz.compat.Graphics.copyAxesText(sourceAxes.YLabel, copyAxes.YLabel);
            lmz.compat.Graphics.copyAxesText(sourceAxes.ZLabel, copyAxes.ZLabel);
            lmz.compat.Graphics.copyAxesText(sourceAxes.Title, copyAxes.Title);
        end

        function copyAxesProperties(sourceAxes, targetAxes)
            names = {'XLim','YLim','ZLim','XScale','YScale','ZScale', ...
                'XDir','YDir','ZDir','Color','XColor','YColor','ZColor', ...
                'Box','LineWidth','FontName','FontSize','FontWeight', ...
                'FontAngle','XGrid','YGrid','ZGrid','GridLineStyle', ...
                'XMinorGrid','YMinorGrid','ZMinorGrid','CLim','View', ...
                'DataAspectRatio','DataAspectRatioMode', ...
                'PlotBoxAspectRatio','PlotBoxAspectRatioMode','Visible'};
            for index = 1:numel(names)
                name = names{index};
                if isprop(sourceAxes, name) && isprop(targetAxes, name)
                    try
                        targetAxes.(name) = sourceAxes.(name);
                    catch
                        % Release-specific read-only/incompatible properties
                        % retain their classic-axes defaults.
                    end
                end
            end
            try
                colormap(targetAxes, colormap(sourceAxes));
            catch
            end
        end

        function copyAxesText(sourceText, targetText)
            names = {'String','Color','Interpreter','FontName','FontSize', ...
                'FontWeight','FontAngle','HorizontalAlignment', ...
                'VerticalAlignment','Visible'};
            for index = 1:numel(names)
                name = names{index};
                if isprop(sourceText, name) && isprop(targetText, name)
                    try
                        targetText.(name) = sourceText.(name);
                    catch
                    end
                end
            end
        end
    end
end

function deleteIfPresent(path)
if exist(path, 'file') == 2, delete(path); end
end
