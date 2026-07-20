classdef TestCompatibilityLayer < matlab.unittest.TestCase
    methods (Test)
        function timestampPreferredAndFallback(testCase)
            preferred = lmz.compat.Timestamp.current(false);
            fallback = lmz.compat.Timestamp.current(true);
            testCase.verifyNotEmpty(preferred);
            testCase.verifyNotEmpty(fallback);
            testCase.verifyNotEmpty(regexp(fallback, '^\d{8}T\d{6}$', 'once'));
        end

        function recursiveDiscoveryPreferredAndFallbackAgree(testCase)
            root = lmz.util.ProjectPaths.root();
            preferred = lmz.compat.Files.recursive( ...
                fullfile(root, 'src'), '*.m', false);
            fallback = lmz.compat.Files.recursive( ...
                fullfile(root, 'src'), '*.m', true);
            preferredNames = sort(arrayfun(@(item) fullfile( ...
                item.folder, item.name), preferred, 'UniformOutput', false));
            fallbackNames = sort(arrayfun(@(item) fullfile( ...
                item.folder, item.name), fallback, 'UniformOutput', false));
            testCase.verifyEqual(preferredNames, fallbackNames);
        end

        function atomicMovePreferredAndFallback(testCase)
            folder = tempname;
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, 's'));
            for forced = [false true]
                source = fullfile(folder, sprintf('source%d.txt', forced));
                target = fullfile(folder, sprintf('target%d.txt', forced));
                writeText(source, 'new');
                writeText(target, 'old');
                lmz.compat.Files.atomicMove(source, target, forced);
                testCase.verifyEqual(fileread(target), 'new');
                testCase.verifyEqual(exist(source, 'file'), 0);
            end
            clear cleanup
        end

        function jsonRoundTrip(testCase)
            expected = struct('name', 'compatibility', 'count', 2);
            actual = lmz.compat.Json.decode(lmz.compat.Json.encode(expected));
            testCase.verifyEqual(actual, expected);
        end

        function optimizationFallback(testCase)
            values = struct('Display', 'off', 'MaxIterations', 12, ...
                'FunctionTolerance', 1e-7, 'StepTolerance', 1e-8);
            options = lmz.compat.Optimization.fsolve(values, true);
            testCase.verifyEqual(options.MaxIter, 12);
            testCase.verifyEqual(options.TolFun, 1e-7);
            testCase.verifyEqual(options.TolX, 1e-8);
        end

        function graphicsStrategyCanBeForced(testCase)
            testCase.verifyFalse( ...
                lmz.compat.Graphics.preferredExporterAvailable(true));
            expected = exist('exportgraphics', 'file') == 2;
            testCase.verifyEqual( ...
                lmz.compat.Graphics.preferredExporterAvailable(false), expected);
        end

        function forcedGraphicsFallbackCapturesClassicAndUIAxes(testCase)
            folder=tempname;mkdir(folder);
            folderCleanup=onCleanup(@()removeFolder(folder));

            classicFigure=figure('Visible','off','Position',[20 20 420 300]);
            classicCleanup=onCleanup(@()deleteIfValid(classicFigure));
            classicAxes=axes('Parent',classicFigure);
            populateAxes(classicAxes);
            verifyFallbackCapture(testCase,classicAxes,folder,'classic');

            uiFigure=uifigure('Visible','off','Position',[20 20 420 300]);
            uiCleanup=onCleanup(@()deleteIfValid(uiFigure));
            uiAxes=uiaxes(uiFigure,'Position',[35 30 350 235]);
            populateAxes(uiAxes);axis(uiAxes,'off');
            originalLimits=[xlim(uiAxes) ylim(uiAxes)];
            originalChildren=numel(allchild(uiAxes));
            verifyFallbackCapture(testCase,uiAxes,folder,'ui');
            testCase.verifyEqual([xlim(uiAxes) ylim(uiAxes)],originalLimits);
            testCase.verifyEqual(numel(allchild(uiAxes)),originalChildren);
            clear uiCleanup classicCleanup folderCleanup
        end
    end
end

function writeText(path, value)
file = fopen(path, 'w');
cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s', value);
clear cleanup
end


function populateAxes(axesHandle)
hold(axesHandle,'on');
plot(axesHandle,[0 1 2],[0.2 1.1 0.4],'-o','LineWidth',2);
patch(axesHandle,[0.5 1.2 1.5],[0.1 0.7 0.1],[0.9 0.5 0.1], ...
    'FaceAlpha',0.5);
quiver(axesHandle,1,0.5,0.35,0.4,0,'Color',[0.8 0.1 0.1]);
text(axesHandle,0.1,1.25,'fallback','Interpreter','none');
xlabel(axesHandle,'x');ylabel(axesHandle,'y');title(axesHandle,'Legacy capture');
xlim(axesHandle,[-0.2 2.2]);ylim(axesHandle,[-0.1 1.5]);grid(axesHandle,'on');
end


function verifyFallbackCapture(testCase,axesHandle,folder,prefix)
pngPath=fullfile(folder,[prefix '.png']);
pdfPath=fullfile(folder,[prefix '.pdf']);
lmz.compat.Graphics.exportAxes(axesHandle,pngPath,72,true);
lmz.compat.Graphics.exportAxes(axesHandle,pdfPath,72,true);
testCase.verifyEqual(exist(pngPath,'file'),2);
testCase.verifyEqual(exist(pdfPath,'file'),2);
pngInfo=dir(pngPath);pdfInfo=dir(pdfPath);
testCase.verifyGreaterThan(pngInfo.bytes,500);
testCase.verifyGreaterThan(pdfInfo.bytes,500);
imageData=lmz.compat.Graphics.captureAxes(axesHandle,72,true);
testCase.verifyEqual(size(imageData,3),3);
testCase.verifyGreaterThan(double(max(imageData(:)))- ...
    double(min(imageData(:))),20);
end


function deleteIfValid(value)
if ~isempty(value)&&isgraphics(value),delete(value);end
end


function removeFolder(folder)
if exist(folder,'dir')==7,rmdir(folder,'s');end
end
