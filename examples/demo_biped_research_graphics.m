%DEMO_BIPED_RESEARCH_GRAPHICS Render flight and contact biped frames.
projectRoot=fileparts(fileparts(mfilename('fullpath')));originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));cd(projectRoot);startup;cd(originalDirectory);
session=lmz.examples.ResearchGraphics.open('slip_biped','research_legacy','off');
sessionCleanup=onCleanup(@()lmz.examples.ResearchGraphics.close(session));
frames=lmz.examples.ResearchGraphics.renderFrames(session,[0 0.25 0.5 0.75 1]);
output=struct('Frames',frames,'SuccessMarker','LMZ_BIPED_RESEARCH_GRAPHICS_OK');
fprintf('%s frames=%d handles=%d\n',output.SuccessMarker, ...
    numel(frames.FrameIndices),frames.HandleCount);
clear sessionCleanup directoryCleanup
