classdef TestQuadLoadResearchQuadrupedGeometry < matlab.unittest.TestCase
    methods (Test)
        function rendererReusesSharedCompoundGeometryAndStableHandles(testCase)
            simulation=QuadLoadGraphicsTestSupport.simulation();
            profile=QuadLoadGraphicsTestSupport.profile('research_legacy');
            figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));
            axesHandle=axes(figureHandle);
            renderer=lmzmodels.slip_quad_load.ResearchRenderer( ...
                axesHandle,simulation,profile,struct());
            rendererCleanup=onCleanup(@()delete(renderer));

            testCase.verifyTrue(isa(renderer,'lmz.viz.ResearchRenderer'));
            testCase.verifyEqual(renderer.ActiveStrideIndex,1);
            testCase.verifyEqual(get(renderer.Handles.Load,'Type'),'patch');
            testCase.verifyEqual(size(renderer.Handles.Load.Vertices),[4 2]);
            testCase.verifyEqual(size(renderer.Handles.Rope.Vertices),[4 2]);
            testCase.verifyEqual(renderer.Handles.Load.FaceAlpha,.3, ...
                'AbsTol',eps);
            testCase.verifyEqual(renderer.Handles.Load.LineWidth,2, ...
                'AbsTol',eps);
            testCase.verifyEqual(char(axesHandle.Visible),'off');
            testCase.verifyEqual(xlim(axesHandle), ...
                renderer.FrameGeometry.BodyFrame(1)+[-3 1.5], ...
                'AbsTol',2e-14);
            testCase.verifyEqual(ylim(axesHandle),[-.1 2],'AbsTol',eps);
            testCase.verifyEqual(pbaspect(axesHandle),[2 1 1],'AbsTol',eps);
            testCase.verifyEqual(axesHandle.Title.String, ...
                'SLIP Quad-Load Animation');

            expectedOrder=[renderer.Handles.Rope;renderer.Handles.Load; ...
                legChildOrder(renderer.Handles.Leg_FR); ...
                legChildOrder(renderer.Handles.Leg_BR); ...
                renderer.Handles.COM.Inner;renderer.Handles.COM.Outer; ...
                renderer.Handles.Body.Outline;renderer.Handles.Body.Shading; ...
                renderer.Handles.Body.Background; ...
                renderer.Handles.Ground.Hatch;renderer.Handles.Ground.Field; ...
                legChildOrder(renderer.Handles.Leg_FL); ...
                legChildOrder(renderer.Handles.Leg_BL)];
            testCase.verifyEqual(numel(expectedOrder),33);
            testCase.verifyEqual(axesHandle.Children,expectedOrder);

            loadHandle=renderer.Handles.Load;
            ropeHandle=renderer.Handles.Rope;
            bodyHandle=renderer.Handles.Body.Background;
            legHandle=renderer.Handles.Leg_BL.Lower;
            renderer.updateFrame(2);
            testCase.verifyEqual(renderer.ActiveStrideIndex,2);
            testCase.verifyEqual(renderer.Handles.Load,loadHandle);
            testCase.verifyEqual(renderer.Handles.Rope,ropeHandle);
            testCase.verifyEqual(renderer.Handles.Body.Background,bodyHandle);
            testCase.verifyEqual(renderer.Handles.Leg_BL.Lower,legHandle);
            testCase.verifyEqual(axesHandle.Children,expectedOrder);

            expectedBody=lmzmodels.slip_quadruped.ResearchBodyGeometry.compute( ...
                renderer.FrameGeometry.BodyFrame, ...
                renderer.FrameGeometry.BackFraction);
            expectedLeg=lmzmodels.slip_quadruped.ResearchLegGeometry.compute( ...
                renderer.FrameGeometry.Attachments(1,:), ...
                renderer.FrameGeometry.Lengths(1), ...
                renderer.FrameGeometry.RestLength, ...
                renderer.FrameGeometry.Angles(1));
            testCase.verifyEqual(renderer.FrameGeometry.Body.PerimeterVertices, ...
                expectedBody.PerimeterVertices,'AbsTol',2e-14);
            testCase.verifyEqual(renderer.FrameGeometry.Legs{1}.Lower.Vertices, ...
                expectedLeg.Lower.Vertices,'AbsTol',2e-14);
            testCase.verifyEqual(renderer.FrameGeometry.Body.Metadata.sourceCommit, ...
                lmzmodels.slip_quadruped.ResearchBodyGeometry.SourceCommit);
            expectedLoad=lmzmodels.slip_quad_load.ResearchLoadGeometry.compute( ...
                renderer.FrameGeometry.LoadCenter);
            testCase.verifyEqual(renderer.Handles.Load.Vertices, ...
                expectedLoad.Vertices,'AbsTol',eps);
            clear rendererCleanup cleanup
        end

        function catalogDefaultsAndCleanRendererRemainSelectable(testCase)
            root=fullfile(lmz.util.ProjectPaths.catalog(),'slip_quad_load');
            config=lmz.viz.GraphicsConfig.fromJson( ...
                fullfile(root,'graphics.lmz.json'),root, ...
                lmz.util.ProjectPaths.models(),'lmzmodels');
            testCase.verifyEqual(config.defaultForMaturity('validated'), ...
                'research_legacy');
            testCase.verifyEqual(config.defaultForMaturity('tutorial'), ...
                'clean_generic');
            testCase.verifyEqual(config.defaultForMaturity('compatibility'), ...
                'clean_generic');
            testCase.verifyEqual(config.defaultForMaturity('experimental'), ...
                'clean_generic');
            testCase.verifyEqual(config.getProfile('high_contrast').RendererClass, ...
                'lmzmodels.slip_quad_load.ResearchRenderer');
            testCase.verifyEqual(config.getProfile('research_legacy').Maturities, ...
                {'validated'});
            testCase.verifyEqual(config.getProfile('high_contrast').Maturities, ...
                {'validated'});

            figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));
            renderer=lmzmodels.slip_quad_load.QuadLoadRenderer( ...
                axes(figureHandle),QuadLoadGraphicsTestSupport.simulation(), ...
                config.getProfile('clean_generic'),struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            loadHandle=renderer.Handles.Load;renderer.updateFrame(.5);
            testCase.verifyEqual(renderer.Handles.Load,loadHandle);
            testCase.verifyEqual(get(renderer.Handles.Load,'Marker'),'square');
            testCase.verifyTrue(isa(renderer,'lmz.viz.Renderer'));
            clear rendererCleanup cleanup
        end

        function highContrastRetainsResearchGeometryAndCamera(testCase)
            profile=QuadLoadGraphicsTestSupport.profile('high_contrast');
            figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));
            axesHandle=axes(figureHandle);
            renderer=lmzmodels.slip_quad_load.ResearchRenderer( ...
                axesHandle,QuadLoadGraphicsTestSupport.simulation(), ...
                profile,struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            testCase.verifyTrue(isa(renderer,'lmz.viz.ResearchRenderer'));
            testCase.verifyEqual(get(renderer.Handles.Load,'Type'),'patch');
            testCase.verifyGreaterThan(size( ...
                renderer.Handles.Leg_BL.Lower.Vertices,1),50);
            testCase.verifyEqual(renderer.Handles.Load.FaceColor,[1 .85 0], ...
                'AbsTol',eps);
            testCase.verifyEqual(renderer.Handles.Rope.EdgeColor,[0 .25 1], ...
                'AbsTol',eps);
            testCase.verifyEqual(xlim(axesHandle), ...
                renderer.FrameGeometry.BodyFrame(1)+[-3 1.5], ...
                'AbsTol',2e-14);
            testCase.verifyEqual(ylim(axesHandle),[-.1 2],'AbsTol',eps);
            testCase.verifyEqual(pbaspect(axesHandle),[2 1 1],'AbsTol',eps);
            clear rendererCleanup cleanup
        end

        function profileCameraAndAxisOverridesAreHonored(testCase)
            baseProfile=QuadLoadGraphicsTestSupport.profile('research_legacy');
            value=baseProfile.toStruct();
            value.camera=struct('xLimits',[-4 4],'yLimits',[-.25 1.75], ...
                'dataAspectRatio',[1 2 1],'follow',false, ...
                'followWindow',[-2 .75]);
            value.axis=struct('equal',false,'grid',true,'visible',true, ...
                'xLabel','distance','yLabel','height', ...
                'title','Profile camera override', ...
                'backgroundColor',[.92 .94 .96]);
            profile=lmz.viz.VisualizationProfile(value, ...
                baseProfile.ScenePath,baseProfile.StylePath,baseProfile.Style);
            figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));
            axesHandle=axes(figureHandle);
            renderer=lmzmodels.slip_quad_load.ResearchRenderer( ...
                axesHandle,QuadLoadGraphicsTestSupport.simulation(), ...
                profile,struct());
            rendererCleanup=onCleanup(@()delete(renderer));

            testCase.verifyFalse(renderer.CameraFollow);
            testCase.verifyEqual(xlim(axesHandle),[-4 4],'AbsTol',eps);
            testCase.verifyEqual(ylim(axesHandle),[-.25 1.75],'AbsTol',eps);
            testCase.verifyEqual(daspect(axesHandle),[1 2 1],'AbsTol',eps);
            testCase.verifyEqual(axesHandle.Color,[.92 .94 .96], ...
                'AbsTol',eps);
            testCase.verifyEqual(char(axesHandle.Visible),'on');
            testCase.verifyEqual(char(axesHandle.XGrid),'on');
            testCase.verifyEqual(char(axesHandle.YGrid),'on');
            testCase.verifyEqual(axesHandle.XLabel.String,'distance');
            testCase.verifyEqual(axesHandle.YLabel.String,'height');
            testCase.verifyEqual(axesHandle.Title.String, ...
                'Profile camera override');

            renderer.setOptions(struct('CameraFollow',true));
            renderer.updateFrame(2);
            testCase.verifyEqual(xlim(axesHandle), ...
                renderer.FrameGeometry.BodyFrame(1)+[-2 .75], ...
                'AbsTol',2e-14);
            testCase.verifyEqual(ylim(axesHandle),[-.25 1.75], ...
                'AbsTol',eps);
            clear rendererCleanup cleanup
        end

        function hiddenUIAxesLifecycle(testCase)
            testCase.assumeTrue(exist('uifigure','file')==2, ...
                'UI figures are unavailable in this MATLAB release.');
            try
                figureHandle=uifigure('Visible','off');
                axesHandle=uiaxes(figureHandle);
            catch exception
                testCase.assumeTrue(false,['UIAxes unavailable: ' exception.message]);
            end
            cleanup=onCleanup(@()closeIfValid(figureHandle));
            renderer=lmzmodels.slip_quad_load.ResearchRenderer( ...
                axesHandle,QuadLoadGraphicsTestSupport.simulation(), ...
                QuadLoadGraphicsTestSupport.profile('research_legacy'),struct());
            rendererCleanup=onCleanup(@()delete(renderer));
            renderer.updateFrame(2);
            testCase.verifyEqual(renderer.CurrentIndex,2);
            testCase.verifyEqual(renderer.ActiveStrideIndex,2);
            testCase.verifyTrue(isgraphics(renderer.Handles.Load));
            testCase.verifyTrue(isgraphics(renderer.Handles.Body.Outline));
            clear rendererCleanup cleanup
        end
    end
end

function closeIfValid(handle)
if ~isempty(handle)&&isgraphics(handle),delete(handle);end
end

function value=legChildOrder(handles)
value=[handles.Spring2;handles.Lower;handles.UpperOutline; ...
    handles.UpperShading;handles.UpperBackground;handles.Spring1];
end
