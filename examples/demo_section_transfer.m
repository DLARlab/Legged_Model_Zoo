%DEMO_SECTION_TRANSFER Rephase a hopper orbit to post-impact coordinates.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
if ~exist('round9OutputDirectory','var')||isempty(round9OutputDirectory)
    round9OutputDirectory=tempname(tempdir);
end
if exist(round9OutputDirectory,'dir')~=7
    [created,message]=mkdir(round9OutputDirectory);
    if ~created,error('lmz:Example:OutputDirectory','%s',message);end
end

registry=lmz.registry.ModelRegistry.discover();
model=registry.createModel('tutorial_hopper');
problem=model.createProblem('periodic_hop',struct());
decision=problem.getDecisionSchema().defaults();
parameters=problem.getParameterSchema().defaults();
context=lmz.api.RunContext.synchronous(902);
evaluation=problem.evaluate(decision,parameters,context,true);
sourceSolution=problem.makeSolution(decision,parameters,evaluation);
transferred=lmz.services.SectionTransferService().transfer( ...
    model,sourceSolution,'ground_impact_post',context);

periodError=abs(transferred.Simulation.Time(end)- ...
    evaluation.Simulation.Time(end));
if ~transferred.PhaseInvariantObservablesPreserved|| ...
        transferred.PhysicalOrbitMaxError>1e-12||periodError>1e-12
    error('lmz:Example:SectionTransfer', ...
        'Section transfer changed a phase-invariant orbit quantity.');
end
artifactPath=fullfile(round9OutputDirectory, ...
    'section_transfer_solution.lmz.mat');
lmz.io.ArtifactStore.save(artifactPath,transferred.toArtifact());
output=struct('TransferResult',transferred, ...
    'TargetSectionId','ground_impact_post', ...
    'PeriodError',periodError,'ArtifactPath',artifactPath, ...
    'OutputDirectory',round9OutputDirectory, ...
    'SuccessMarker','LMZ_SECTION_TRANSFER_OK');
fprintf('%s target=%s orbit_error=%.3g period_error=%.3g\n', ...
    output.SuccessMarker,output.TargetSectionId, ...
    transferred.PhysicalOrbitMaxError,periodError);
clear directoryCleanup
