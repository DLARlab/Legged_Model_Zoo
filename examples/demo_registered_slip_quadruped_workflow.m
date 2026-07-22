%DEMO_REGISTERED_SLIP_QUADRUPED_WORKFLOW Run the registered RoadMap workflow.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
if ~exist('registeredWorkflowOutputDirectory','var')|| ...
        isempty(registeredWorkflowOutputDirectory)
    registeredWorkflowOutputDirectory=tempname(tempdir);
end
if exist(registeredWorkflowOutputDirectory,'dir')~=7
    [created,message]=mkdir(registeredWorkflowOutputDirectory);
    if ~created,error('lmz:Example:OutputDirectory','%s',message);end
end

registry=lmz.registry.ModelRegistry.discover();
workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
descriptor=workflows.get( ...
    'slip_quadruped','roadmap_root_continuation');
context=lmz.api.RunContext.synchronous(1401);
session=lmz.workflow.WorkflowRunner().initialize(descriptor,context);

solveResult=session.solve(struct());
pair=session.makeAdjacentSeedPair(+1,struct());
% CONTINUE is a MATLAB language keyword, so the public session method is
% named continueBranch while preserving the workflow step ID "continuation".
continuationResult=session.continueBranch(struct( ...
    'MaximumPoints',20,'DirectionMode','both'));
if continuationResult.Branch.pointCount()<3||solveResult.ExitFlag<=0
    error('lmz:Example:RegisteredWorkflow', ...
        'The registered quadruped workflow did not complete successfully.');
end

artifactPath=fullfile(registeredWorkflowOutputDirectory, ...
    'registered_slip_quadruped_continuation.lmz.mat');
lmz.io.ArtifactStore.save(artifactPath,continuationResult.toArtifact());
artifact=lmz.io.ArtifactStore.load(artifactPath);
roundTripBranch=lmz.data.SolutionBranch.fromArtifact(artifact);
if roundTripBranch.pointCount()~=continuationResult.Branch.pointCount()
    error('lmz:Example:RegisteredWorkflowArtifact', ...
        'The registered-workflow artifact did not round trip exactly.');
end

output=struct('Descriptor',descriptor,'Session',session, ...
    'SolveResult',solveResult,'SeedPair',pair, ...
    'ContinuationResult',continuationResult, ...
    'ArtifactPath',artifactPath, ...
    'OutputDirectory',registeredWorkflowOutputDirectory, ...
    'SuccessMarker','LMZ_REGISTERED_QUADRUPED_WORKFLOW_OK');
fprintf('%s dataset=%s seed=%d residual=%.3g points=%d\n', ...
    output.SuccessMarker,descriptor.DefaultDatasetId, ...
    descriptor.DefaultPointIndex,solveResult.Evaluation.ScaledResidualNorm, ...
    continuationResult.Branch.pointCount());
clear directoryCleanup
