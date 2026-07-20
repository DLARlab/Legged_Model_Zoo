classdef TestQuadLoadResearchPlots < matlab.unittest.TestCase
    methods (Test)
        function researchPlotsAreSelectableAndQualified(testCase)
            simulation=QuadLoadGraphicsTestSupport.simulation();
            figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));
            profile=QuadLoadGraphicsTestSupport.profile('research_legacy');

            footfallAxes=subplot(2,3,1,'Parent',figureHandle);
            experimental=simulation.Parameters.per_stride_parameters(:,1:8)./ ...
                simulation.Parameters.per_stride_parameters(:,9);
            footfall=lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotFootfall(footfallAxes,simulation,experimental,profile);
            testCase.verifyGreaterThanOrEqual(numel(footfall),8);
            qualification=getappdata(footfallAxes, ...
                'lmzResearchGraphicsQualifications');
            testCase.verifyTrue(qualification.sourceColorLegendMismatchPreserved);
            testCase.verifyEqual(pbaspect(footfallAxes),[4 1 1],'AbsTol',eps);

            legAxes=subplot(2,3,2,'Parent',figureHandle);
            legs=lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotLegTrajectories(legAxes,simulation,profile);
            testCase.verifyNumElements(legs,4);
            testCase.verifyEqual(legAxes.Title.String,'Leg Angular Velocities');

            tugAxes=subplot(2,3,3,'Parent',figureHandle);
            tug=lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotTugline( ...
                tugAxes,simulation,[.1;.2;.3;.2],profile);
            testCase.verifyNumElements(tug,2);
            testCase.verifyEqual(tugAxes.Title.String, ...
                'Loading Force Along the Tugline');

            sensitivity=struct('percs',[-10 -5 0 5 10], ...
                'C',[1.2 1.1 1 1.05 1.2;2.4 2.2 2 2.1 2.5; ...
                .55 .52 .5 .51 .53], ...
                'names',{{'$k_1$','$k_2$','$l_0$'}});
            sensitivityAxes=[subplot(2,3,4,'Parent',figureHandle), ...
                subplot(2,3,5,'Parent',figureHandle)];
            sensitivityHandles=lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotSensitivity(sensitivityAxes,sensitivity,profile);
            testCase.verifyGreaterThan(numel(sensitivityHandles),3);
            testCase.verifyEqual(sensitivityAxes(1).Title.String, ...
                'Objective vs %-Perturbation');

            r2Axes=subplot(2,3,6,'Parent',figureHandle);
            r2=struct('strideduration',.91,'footfalltiming',.82, ...
                'loadingforce',.73,'weighted',.86);
            r2Handles=lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotR2(r2Axes,r2,profile);
            testCase.verifyNumElements(r2Handles,8);
            qualification=getappdata(r2Axes,'lmzResearchGraphicsQualifications');
            testCase.verifyTrue(qualification.sourceLayoutsConsolidated);
            clear cleanup
        end

        function cleanPlotsRemainTheDefault(testCase)
            simulation=QuadLoadGraphicsTestSupport.simulation();
            figureHandle=figure('Visible','off');
            cleanup=onCleanup(@()closeIfValid(figureHandle));
            axesHandle=axes(figureHandle);
            handles=lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                plotLegTrajectories(axesHandle,simulation,[]);
            testCase.verifyNumElements(handles,13);
            testCase.verifyEqual(axesHandle.Title.String, ...
                'Quadruped body and leg states');
            clear cleanup
        end
    end
end

function closeIfValid(handle)
if ~isempty(handle)&&isgraphics(handle),delete(handle);end
end
