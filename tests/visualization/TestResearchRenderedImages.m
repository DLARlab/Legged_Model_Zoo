classdef TestResearchRenderedImages < matlab.unittest.TestCase
    %TESTRESEARCHRENDEREDIMAGES Batch-render regression on canonical frames.
    % Committed reports preserve maintainer-only source comparison evidence;
    % local renders additionally verify repeatability and palette behavior.
    methods (Test)
        function committedReportsCoverCanonicalSourceComparisonMatrix(testCase)
            models={'slip_quadruped','slip_biped','slip_quad_load'};
            commits={'2c106101383ecee1b2a9d695efe09fbd72d5718a', ...
                '4595146c5881a5313bc8fe92de85099193ef9be9', ...
                '19f3133073c988cc0c3424a647b4adbb60a90b99'};
            expected={{'flight_apex','one_leg_stance','two_leg_stance', ...
                'asymmetric_body_morphology','detailed_phase_overlay'}, ...
                {'flight','left_stance','right_stance', ...
                'double_stance_wrapped_contact','walk_representative', ...
                'run_representative','hop_representative'}, ...
                {'single_stride_stance','rope_slack_low_force', ...
                'stride_boundary_before','stride_boundary_exact', ...
                'stride_boundary_after','rope_loaded'}};
            for modelIndex=1:numel(models)
                folder=fullfile(lmz.util.ProjectPaths.root(),'docs', ...
                    'graphics-comparison',models{modelIndex});
                path=fullfile(folder, ...
                    'batch_metrics_r2025b_macos_arm64.json');
                report=lmz.io.SafeJson.read(path,'Root',folder);
                testCase.verifyEqual(report.modelId,models{modelIndex});
                testCase.verifyEqual(report.sourceCommit,commits{modelIndex});
                testCase.verifyTrue(report.passed,models{modelIndex});
                testCase.verifyFalse(report.sourceImagesStored);
                testCase.verifyFalse(report.differenceImagesStored);
                testCase.verifyFalse(report.humanApproved);
                frames=objectCells(report.frames);
                labels=cellfun(@(frame)frame.caseLabel,frames, ...
                    'UniformOutput',false);
                testCase.verifyEqual(labels,expected{modelIndex});
                testCase.verifyEqual(reshape(report.canonicalCaseLabels,1,[]), ...
                    expected{modelIndex});
                verifyReportThresholds(testCase,report,frames);
                testCase.verifyGreaterThan( ...
                    numel(report.dataContract.stateNames),0);
                testCase.verifyGreaterThan( ...
                    numel(report.dataContract.parameterNames),0);
                for frameIndex=1:numel(frames)
                    frame=frames{frameIndex};
                    testCase.verifyEqual(numel(frame.state), ...
                        numel(report.dataContract.stateNames),frame.caseLabel);
                    testCase.verifyEqual(numel(frame.parameters), ...
                        numel(report.dataContract.parameterNames),frame.caseLabel);
                    testCase.verifyTrue(isfield(frame.caseMetadata,'coverageTags'));
                    testCase.verifyEqual(frame.reviewOutcome, ...
                        'batch_metrics_pass');
                    testCase.verifyTrue(frame.passed,frame.caseLabel);
                end
                testCase.verifyEmpty(committedRasters(folder),models{modelIndex});
                verifyModelSpecificEvidence(testCase,models{modelIndex}, ...
                    report,frames);
            end
        end

        function canonicalResearchFramesAreRepeatable(testCase)
            models={'slip_quadruped','slip_biped','slip_quad_load'};
            for index=1:numel(models)
                first=renderCanonical(models{index},'research_legacy');
                second=renderCanonical(models{index},'research_legacy');
                metrics=lmz.viz.ImageMetrics.compare(first,second);
                testCase.verifyLessThanOrEqual(metrics.NormalizedRMSE,0.005, ...
                    models{index});
                testCase.verifyGreaterThanOrEqual(metrics.EdgeMapOverlap,0.98, ...
                    models{index});
                testCase.verifyGreaterThanOrEqual( ...
                    metrics.ForegroundBoundingBoxAgreement,0.99,models{index});
                testCase.verifyGreaterThanOrEqual( ...
                    metrics.ColorClusterAgreement,0.99,models{index});
            end
        end

        function highContrastChangesPaletteButRetainsSilhouette(testCase)
            models={'slip_quadruped','slip_biped','slip_quad_load'};
            for index=1:numel(models)
                research=renderCanonical(models{index},'research_legacy');
                contrast=renderCanonical(models{index},'high_contrast');
                metrics=lmz.viz.ImageMetrics.compare(research,contrast);
                testCase.verifyGreaterThan(metrics.NormalizedRMSE,0,models{index});
                testCase.verifyGreaterThan(metrics.EdgeMapOverlap,0.70,models{index});
                testCase.verifyGreaterThan( ...
                    metrics.ForegroundBoundingBoxAgreement,0.90,models{index});
            end
        end
    end
end

function values=objectCells(value)
if isstruct(value)
    values=num2cell(value(:).');
elseif iscell(value)
    values=reshape(value,1,[]);
else
    error('lmz:Test:GraphicsReportObjects', ...
        'Comparison report objects have an unexpected representation.');
end
end

function verifyReportThresholds(testCase,report,frames)
thresholds=report.thresholds;
testCase.verifyEqual(thresholds.normalizedRMSEMaximum,.35, ...
    'AbsTol',eps);
testCase.verifyEqual(thresholds.edgeMapOverlapMinimum,.60, ...
    'AbsTol',eps);
testCase.verifyEqual(thresholds.foregroundBoundingBoxAgreementMinimum,.84, ...
    'AbsTol',eps);
testCase.verifyEqual(thresholds.colorClusterAgreementMinimum,.65, ...
    'AbsTol',eps);
nrmse=zeros(1,numel(frames));edge=nrmse;bbox=nrmse;color=nrmse;
for index=1:numel(frames)
    metrics=frames{index}.metrics;
    nrmse(index)=metrics.NormalizedRMSE;
    edge(index)=metrics.EdgeMapOverlap;
    bbox(index)=metrics.ForegroundBoundingBoxAgreement;
    color(index)=metrics.ColorClusterAgreement;
    testCase.verifyLessThanOrEqual(nrmse(index), ...
        thresholds.normalizedRMSEMaximum,frames{index}.caseLabel);
    testCase.verifyGreaterThanOrEqual(edge(index), ...
        thresholds.edgeMapOverlapMinimum,frames{index}.caseLabel);
    testCase.verifyGreaterThanOrEqual(bbox(index), ...
        thresholds.foregroundBoundingBoxAgreementMinimum, ...
        frames{index}.caseLabel);
    testCase.verifyGreaterThanOrEqual(color(index), ...
        thresholds.colorClusterAgreementMinimum,frames{index}.caseLabel);
end
testCase.verifyEqual(report.summary.normalizedRMSEMaximum,max(nrmse), ...
    'AbsTol',1e-12);
testCase.verifyEqual(report.summary.edgeMapOverlapMinimum,min(edge), ...
    'AbsTol',1e-12);
testCase.verifyEqual( ...
    report.summary.foregroundBoundingBoxAgreementMinimum,min(bbox), ...
    'AbsTol',1e-12);
testCase.verifyEqual(report.summary.colorClusterAgreementMinimum,min(color), ...
    'AbsTol',1e-12);
end

function verifyModelSpecificEvidence(testCase,modelId,report,frames)
switch modelId
    case 'slip_quadruped'
        testCase.verifyEqual([frames{1}.caseMetadata.expectedContactCount, ...
            frames{2}.caseMetadata.expectedContactCount, ...
            frames{3}.caseMetadata.expectedContactCount],[0 1 2]);
        testCase.verifyEqual(frames{4}.caseMetadata.morphology, ...
            'pitched_body_l_b_0_35');
        testCase.verifyTrue(frames{5}.caseMetadata.detailedOverlay);
        regression=report.lmzRegressions.forceVectorsOffOn;
        testCase.verifyEqual(regression.caseLabel,'force_vectors_off_on');
        testCase.verifyEqual(regression.referenceCaseLabel,'two_leg_stance');
        testCase.verifyFalse(regression.sourceRendererHasForceLayer);
        testCase.verifyEqual(regression.forceOff.visibleHandleCount,0);
        testCase.verifyEqual(regression.forceOff.nonzeroVectorCount,0);
        testCase.verifyEqual(regression.forceOn.visibleHandleCount,4);
        testCase.verifyGreaterThanOrEqual( ...
            regression.forceOn.nonzeroVectorCount,2);
        testCase.verifyGreaterThan( ...
            regression.differenceMetrics.NormalizedRMSE,0);
        testCase.verifyNotEqual(regression.forceOff.imageChecksum, ...
            regression.forceOn.imageChecksum);
        testCase.verifyFalse(regression.rastersStored);
        testCase.verifyTrue(regression.passed);
    case 'slip_biped'
        testCase.verifyEqual([frames{1}.caseMetadata.expectedContactCount, ...
            frames{2}.caseMetadata.expectedContactCount, ...
            frames{3}.caseMetadata.expectedContactCount, ...
            frames{4}.caseMetadata.expectedContactCount],[0 1 1 2]);
        testCase.verifyTrue(frames{4}.caseMetadata.wrappedContact);
        gaitLabels=cellfun(@(frame)frame.caseMetadata.gaitLabel, ...
            frames(5:7),'UniformOutput',false);
        testCase.verifyEqual(gaitLabels,{'walking','running','hopping'});
        for index=5:7
            testCase.verifyNotEmpty(frames{index}.caseMetadata.sourceSupport);
        end
    case 'slip_quad_load'
        testCase.verifyEqual(frames{3}.caseMetadata.boundaryRelation,'before');
        testCase.verifyEqual(frames{4}.caseMetadata.boundaryRelation,'exact');
        testCase.verifyEqual(frames{5}.caseMetadata.boundaryRelation,'after');
        testCase.verifyEqual([frames{3}.caseMetadata.expectedStrideIndex, ...
            frames{4}.caseMetadata.expectedStrideIndex, ...
            frames{5}.caseMetadata.expectedStrideIndex],[1 2 2]);
        testCase.verifyNotEqual(frames{3}.parameters(1:9), ...
            frames{4}.parameters(1:9));
        testCase.verifyEqual(frames{4}.parameters(1:9), ...
            frames{5}.parameters(1:9),'AbsTol',eps);
        testCase.verifyLessThan(frames{2}.caseMetadata.tuglineForce, ...
            frames{6}.caseMetadata.tuglineForce);
        testCase.verifyLessThan(frames{2}.caseMetadata.ropeLength, ...
            frames{6}.caseMetadata.ropeLength);
end
end

function paths=committedRasters(folder)
extensions={'*.png','*.jpg','*.jpeg','*.tif','*.tiff','*.gif'};
paths={};
for index=1:numel(extensions)
    files=dir(fullfile(folder,extensions{index}));
    for fileIndex=1:numel(files)
        paths{end+1}=files(fileIndex).name; %#ok<AGROW>
    end
end
end

function imageData=renderCanonical(modelId,profileId)
figureHandle=figure('Visible','off','Color','white', ...
    'Position',[10 10 640 480]);
cleanup=onCleanup(@()deleteIfValid(figureHandle));
axesHandle=axes('Parent',figureHandle,'Units','pixels', ...
    'Position',[50 40 540 400]);
switch modelId
    case 'slip_quadruped'
        simulation=QuadrupedGraphicsTestSupport.simulation();
        profile=QuadrupedGraphicsTestSupport.profile(profileId);
        renderer=lmzmodels.slip_quadruped.ResearchRenderer( ...
            axesHandle,simulation,profile,struct());
        frame=2;
    case 'slip_biped'
        simulation=bipedSimulation();profile=bipedProfile(profileId);
        renderer=lmzmodels.slip_biped.ResearchRenderer( ...
            axesHandle,simulation,profile,struct());
        frame=2;
    case 'slip_quad_load'
        simulation=QuadLoadGraphicsTestSupport.simulation();
        profile=QuadLoadGraphicsTestSupport.profile(profileId);
        renderer=lmzmodels.slip_quad_load.ResearchRenderer( ...
            axesHandle,simulation,profile,struct());
        frame=2;
    otherwise
        error('lmz:Test:GraphicsModel','Unknown graphics model.');
end
rendererCleanup=onCleanup(@()delete(renderer));
renderer.updateFrame(frame);drawnow;imageData=renderer.captureFrame();
clear rendererCleanup cleanup
end

function profile=bipedProfile(profileId)
root=fullfile(lmz.util.ProjectPaths.catalog(),'slip_biped');
config=lmz.viz.GraphicsConfig.fromJson(fullfile(root,'graphics.lmz.json'), ...
    root,lmz.util.ProjectPaths.models(),'lmzmodels');
profile=config.getProfile(profileId);
end

function simulation=bipedSimulation()
time=[0;0.3;1];states=[2 0 .9 0 .2 0 -.3 0; ...
    2.1 0 .92 0 .15 0 -.2 0;2.2 0 .95 0 .1 0 -.1 0];
modes=struct('left',[false;true;false],'right',[true;false;true], ...
    'period',1);names={'L_TD','L_LO','R_TD','R_LO','APEX'};
times=[0.2 0.6 0.7 0.1 1];
records=repmat(struct('Name','','Time',0),5,1);
for index=1:5
    records(index).Name=names{index};records(index).Time=times(index);
end
simulation=lmz.api.SimulationResult(time, ...
    lmzmodels.slip_biped.PhysicalStateSchema.create(),states,modes, ...
    struct(),struct(),struct(),struct(),'EventRecords',records);
kinematics=lmzmodels.slip_biped.KinematicsProvider.compute(simulation);
simulation=lmz.api.SimulationResult(simulation.Time, ...
    simulation.StateSchema,simulation.States,simulation.Modes, ...
    simulation.Observables,simulation.Parameters,simulation.Diagnostics, ...
    simulation.Provenance,'EventRecords',simulation.EventRecords, ...
    'Kinematics',kinematics);
end

function deleteIfValid(value)
if ~isempty(value)&&isgraphics(value),delete(value);end
end
