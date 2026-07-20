%DEMO_QUAD_LOAD_RESEARCH_GRAPHICS Render canonical load-transition frames.
projectRoot=fileparts(fileparts(mfilename('fullpath')));originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));cd(projectRoot);startup;cd(originalDirectory);
session=lmz.examples.ResearchGraphics.open('slip_quad_load','research_legacy','off');
sessionCleanup=onCleanup(@()lmz.examples.ResearchGraphics.close(session));
frames=lmz.examples.ResearchGraphics.renderFrames(session,[0 0.33 0.5 0.67 1]);
output=struct('Frames',frames,'SuccessMarker','LMZ_QUAD_LOAD_RESEARCH_GRAPHICS_OK');
fprintf('%s frames=%d handles=%d\n',output.SuccessMarker, ...
    numel(frames.FrameIndices),frames.HandleCount);
clear sessionCleanup directoryCleanup
