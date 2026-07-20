%DEMO_GRAPHICS_COMPARISON_GALLERY Compare every built-in visual profile.
projectRoot=fileparts(fileparts(mfilename('fullpath')));originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));cd(projectRoot);startup;cd(originalDirectory);
models={'slip_quadruped','slip_biped','slip_quad_load'};
profiles={'research_legacy','clean_generic','high_contrast'};
gallery=cell(numel(models),numel(profiles));
sourceComparisons=cell(1,numel(models));
for modelIndex=1:numel(models)
    session=lmz.examples.ResearchGraphics.open( ...
        models{modelIndex},'research_legacy','off');
    try
        for profileIndex=1:numel(profiles)
            profileId=profiles{profileIndex};
            if profileIndex>1
                groundStyle='hatched';cameraFollow=true;
                if strcmp(profileId,'clean_generic')
                    groundStyle='line';cameraFollow=false;
                end
                options=struct('ShowForces',false,'DetailedOverlay', ...
                    ~strcmp(profileId,'clean_generic'),'GroundVisible',true, ...
                    'CameraFollow',cameraFollow,'GroundStyle',groundStyle, ...
                    'Palette',profileId);
                session=lmz.examples.ResearchGraphics.switchProfile( ...
                    session,profileId,options);
            end
            gallery{modelIndex,profileIndex}= ...
                lmz.examples.ResearchGraphics.renderFrames(session,[0 0.5 1]);
        end
        lmz.examples.ResearchGraphics.close(session);
    catch exception
        lmz.examples.ResearchGraphics.close(session);rethrow(exception)
    end
    reportPath=fullfile(projectRoot,'docs','graphics-comparison', ...
        models{modelIndex},'batch_metrics_r2025b_macos_arm64.json');
    sourceComparisons{modelIndex}=lmz.compat.Json.read(reportPath);
    assert(sourceComparisons{modelIndex}.passed);
end
output=struct('Models',{models},'Profiles',{profiles},'Gallery',{gallery}, ...
    'SourceComparisonReports',{sourceComparisons}, ...
    'SuccessMarker','LMZ_GRAPHICS_COMPARISON_GALLERY_OK');
frameCounts=cellfun(@(item)numel(item.FrameIndices),gallery);
fprintf('%s models=%d profiles=%d canonical_frames=%d source_reports=%d\n', ...
    output.SuccessMarker,numel(models),numel(profiles), ...
    sum(frameCounts(:)), ...
    numel(sourceComparisons));
clear directoryCleanup
