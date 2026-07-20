%DEMO_RESEARCH_GRAPHICS_RECORDING Record selected-profile GIF with metadata.
projectRoot=fileparts(fileparts(mfilename('fullpath')));originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));cd(projectRoot);startup;cd(originalDirectory);
outputDirectory=tempname;mkdir(outputDirectory);outputCleanup=onCleanup(@()rmdir(outputDirectory,'s'));
session=lmz.examples.ResearchGraphics.open('slip_quadruped','research_legacy','off');
sessionCleanup=onCleanup(@()lmz.examples.ResearchGraphics.close(session));
frames=lmz.examples.ResearchGraphics.renderFrames(session,[0 0.5 1]);
target=fullfile(outputDirectory,'research_quadruped.gif');
metadata=struct('schemaVersion','1.0.0','modelId',session.ModelId, ...
    'problemId',session.ProblemId,'visualizationProfile',session.Profile.toStruct());
lmz.services.RecorderService().recordGif(session.Renderer,target, ...
    struct('FrameCount',3,'DelayTime',0.02,'Metadata',metadata));
metadataPath=[target '.lmz.json'];
if exist(target,'file')~=2||exist(metadataPath,'file')~=2
    error('lmz:Example:ResearchRecording','Recording or profile metadata is missing.');
end
output=struct('Frames',frames,'Format','gif','ProfileId',session.Profile.Id, ...
    'RecordedBytes',dir(target).bytes,'Metadata',lmz.compat.Json.read(metadataPath), ...
    'SuccessMarker','LMZ_RESEARCH_GRAPHICS_RECORDING_OK');
fprintf('%s profile=%s bytes=%d\n',output.SuccessMarker, ...
    output.ProfileId,output.RecordedBytes);
clear sessionCleanup outputCleanup directoryCleanup
