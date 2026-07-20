%DEMO_VISUAL_PROFILE_SWITCHING Rebuild one live quadruped view safely.
projectRoot=fileparts(fileparts(mfilename('fullpath')));originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));cd(projectRoot);startup;cd(originalDirectory);
ids={'research_legacy','clean_generic','high_contrast'};summaries=cell(1,numel(ids));
session=lmz.examples.ResearchGraphics.open('slip_quadruped',ids{1},'off');
preserved=zeros(numel(ids),2);rendererClasses=cell(1,numel(ids));
try
    for profileIndex=1:numel(ids)
        targetIndex=1+round(0.5*(session.Renderer.frameCount()-1));
        session.Renderer.updateFrame(targetIndex);preserved(profileIndex,1)=targetIndex;
        if profileIndex>1
            profileId=ids{profileIndex};ground='hatched';follow=true;
            if strcmp(profileId,'clean_generic'),ground='line';follow=false;end
            options=struct('ShowForces',false,'DetailedOverlay', ...
                ~strcmp(profileId,'clean_generic'),'GroundVisible',true, ...
                'CameraFollow',follow,'GroundStyle',ground,'Palette',profileId);
            session=lmz.examples.ResearchGraphics.switchProfile( ...
                session,profileId,options);
        end
        preserved(profileIndex,2)=session.Renderer.CurrentIndex;
        assert(preserved(profileIndex,1)==preserved(profileIndex,2));
        summaries{profileIndex}=lmz.examples.ResearchGraphics. ...
            renderFrames(session,[0 0.5 1]);
        rendererClasses{profileIndex}=class(session.Renderer);
    end
    output=struct('Profiles',{ids},'Summaries',{summaries}, ...
        'PreservedFrameIndices',preserved, ...
        'RendererClasses',{rendererClasses}, ...
        'SuccessMarker','LMZ_VISUAL_PROFILE_SWITCHING_OK');
    lmz.examples.ResearchGraphics.close(session);
catch exception
    lmz.examples.ResearchGraphics.close(session);rethrow(exception)
end
fprintf('%s profiles=%d frames_each=3\n',output.SuccessMarker,numel(ids));
clear directoryCleanup
