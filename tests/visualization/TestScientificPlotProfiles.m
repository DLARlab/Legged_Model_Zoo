classdef TestScientificPlotProfiles < matlab.unittest.TestCase
    %TESTSCIENTIFICPLOTPROFILES Model-owned source plot selection.
    methods (Test)
        function quadrupedResearchProfileUsesSourceChannelsAndLabels(testCase)
            [figureHandle,axesMap]=makeAxes();
            cleanup=onCleanup(@()deleteIfValid(figureHandle));
            registry=lmz.registry.ModelRegistry.discover();
            registryCleanup=onCleanup(@()delete(registry));
            profiles=lmz.viz.VisualizationProfileRegistry(registry);
            profile=profiles.resolve( ...
                'slip_quadruped','periodic_apex','research_legacy');
            factory=lmz.viz.RendererFactory(registry,profiles);
            rendered=factory.renderPlots(axesMap, ...
                QuadrupedGraphicsTestSupport.simulation(), ...
                'slip_quadruped',profile);
            testCase.verifyTrue(rendered);
            testCase.verifyEqual(numel(findobj(axesMap.Torso,'Type','line')),5);
            testCase.verifyEqual(numel(findobj(axesMap.Back,'Type','line')),4);
            testCase.verifyEqual(numel(findobj(axesMap.Front,'Type','line')),4);
            testCase.verifyEqual(numel(findobj(axesMap.Forces,'Type','line')),4);
            testCase.verifyEqual(axesMap.Forces.Title.String, ...
                'Ground Reaction Forces');
            testCase.verifyEqual(axesMap.Forces.XLabel.Interpreter,'latex');
            qualification=getappdata(axesMap.Forces, ...
                'lmzResearchGraphicsQualifications');
            testCase.verifyTrue(qualification.sourceUpdateSwapCorrected);
            testCase.verifyEqual(axesMap.Auxiliary.Title.String, ...
                'Oscillator Cycles');
            clear registryCleanup cleanup
        end

        function bipedResearchAndCleanProfilesSelectDifferentForceViews(testCase)
            [figureHandle,axesMap]=makeAxes();
            cleanup=onCleanup(@()deleteIfValid(figureHandle));
            registry=lmz.registry.ModelRegistry.discover();
            registryCleanup=onCleanup(@()delete(registry));
            profiles=lmz.viz.VisualizationProfileRegistry(registry);
            factory=lmz.viz.RendererFactory(registry,profiles);
            simulation=bipedSimulationWithForces();
            research=profiles.resolve( ...
                'slip_biped','periodic_apex','research_legacy');
            factory.renderPlots(axesMap,simulation,'slip_biped',research);
            testCase.verifyEqual(numel(findobj(axesMap.Forces,'Type','line')),2);
            testCase.verifyEqual(axesMap.Forces.Title.String, ...
                'Left/right vertical ground reaction forces');
            qualification=getappdata(axesMap.Front, ...
                'lmzResearchGraphicsQualifications');
            testCase.verifyFalse(qualification.sourceEquivalent);
            testCase.verifyEqual(axesMap.Auxiliary.Title.String, ...
                'Energy and gait classification');
            gaitLabel=findobj(axesMap.Auxiliary,'Type','text', ...
                'Tag','lmz.biped.gait_label');
            testCase.verifyEqual(gaitLabel.String,'Gait: Run (R)');
            energyLine=findobj(axesMap.Auxiliary,'Type','line');
            testCase.verifyEqual(energyLine.YData,1.25*ones(1,3), ...
                'AbsTol',eps);
            enrichment=getappdata(axesMap.Auxiliary, ...
                'lmzResearchGraphicsQualifications');
            testCase.verifyFalse(enrichment.sourceEquivalent);
            clean=profiles.resolve('slip_biped','periodic_apex','clean_generic');
            factory.renderPlots(axesMap,simulation,'slip_biped',clean);
            testCase.verifyEqual(numel(findobj(axesMap.Forces,'Type','line')),6);
            testCase.verifyEqual(axesMap.Forces.Title.String, ...
                'Ground reaction forces');
            clear registryCleanup cleanup
        end
    end
end

function [figureHandle,axesMap]=makeAxes()
figureHandle=figure('Visible','off','Position',[10 10 900 600]);
axesMap=struct('Torso',subplot(2,3,1,'Parent',figureHandle), ...
    'Back',subplot(2,3,2,'Parent',figureHandle), ...
    'Front',subplot(2,3,3,'Parent',figureHandle), ...
    'Forces',subplot(2,3,4,'Parent',figureHandle), ...
    'Auxiliary',subplot(2,3,5,'Parent',figureHandle));
end

function simulation=bipedSimulationWithForces()
time=[0;.3;1];states=[2 0 .9 0 .2 0 -.3 0; ...
    2.1 0 .92 0 .15 0 -.2 0;2.2 0 .95 0 .1 0 -.1 0];
modes=struct('left',[false;true;false], ...
    'right',[true;false;true],'period',1);
names={'L_TD','L_LO','R_TD','R_LO','APEX'};times=[.2 .6 .7 .1 1];
records=repmat(struct('Name','','Time',0),5,1);
for index=1:5
    records(index).Name=names{index};records(index).Time=times(index);
end
forces=repmat(1:6,numel(time),1);
observables=struct('total_energy',1.25,'gait_name','Run', ...
    'gait_abbreviation','R');
simulation=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_biped.PhysicalStateSchema.create(),states,modes, ...
    observables,struct(),struct(),struct(),'EventRecords',records, ...
    'GroundReactionForces',forces);
end

function deleteIfValid(value)
if ~isempty(value)&&isgraphics(value),delete(value);end
end
