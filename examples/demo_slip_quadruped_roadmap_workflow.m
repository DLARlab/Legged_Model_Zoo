%DEMO_SLIP_QUADRUPED_ROADMAP_WORKFLOW Complete standalone scientific slice.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
startup;
registry=lmz.registry.ModelRegistry.discover();
model=registry.createModel('slip_quadruped');
problem=model.createProblem('periodic_apex',struct());
roadmap=lmzmodels.slip_quadruped.RoadMapCatalog.default();
files=roadmap.listBranches();
branch=lmz.services.BranchService().loadRoadMapBranch(problem,files{1});
index=roadmap.recommendedSeedIndex(files{1});seed=branch.point(index);
evaluation=problem.evaluate(seed.DecisionValues,seed.ParameterValues, ...
    lmz.api.RunContext.synchronous(100),true);simulation=evaluation.Simulation;
solveResult=lmz.services.SolveService().solve(problem,seed,struct(), ...
    lmz.api.RunContext.synchronous(101));
seedPair=lmz.services.SeedService().adjacentBranchPair(problem,branch,index,+1, ...
    struct(),lmz.api.RunContext.synchronous(102));
continuationResult=lmz.services.ContinuationService().run(problem,seedPair, ...
    struct('MaximumPoints',20,'BothDirections',true, ...
    'InitialStep',seedPair.AchievedRadius),lmz.api.RunContext.synchronous(102));
if ~exist('roadmapOutputDirectory','var')||isempty(roadmapOutputDirectory)
    roadmapOutputDirectory=pwd;
end
roadmapArtifactPath=fullfile(roadmapOutputDirectory,'roadmap_continuation.lmz.mat');
lmz.io.ArtifactStore.save(roadmapArtifactPath, ...
    continuationResult.Branch.toArtifact());

figures=struct();figures.Branch=figure('Name','RoadMap branch');
plot(branch.decision('dx'),branch.decision('dphi'),'LineWidth',1.7);hold on
plot(seed.decision('dx'),seed.decision('dphi'),'kp','MarkerFaceColor',[1 .85 0],'MarkerSize',11);grid on;xlabel('dx');ylabel('dphi');title('Built-in quadruped RoadMap');
figures.Animation=figure('Name','Selected physical frame');renderer= ...
    lmzmodels.slip_quadruped.QuadrupedRenderer(axes(figures.Animation),simulation);renderer.updateFrame(round(numel(simulation.Time)/2));
figures.Trajectories=figure('Name','Quadruped trajectories');layout=tiledlayout(figures.Trajectories,3,1);
lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotTorso(nexttile(layout),simulation);lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotBackLegs(nexttile(layout),simulation);lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotFrontLegs(nexttile(layout),simulation);
figures.GRF=figure('Name','Quadruped GRF');lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotGRF(axes(figures.GRF),simulation);
figures.Oscillator=figure('Name','Quadruped oscillator');lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotOscillator(axes(figures.Oscillator),simulation);
figures.Continuation=figure('Name','RoadMap continuation overlay');plot(branch.decision('dx'),branch.decision('dphi'),'Color',[.7 .7 .7]);hold on;plot(continuationResult.Branch.decision('dx'),continuationResult.Branch.decision('dphi'),'o-','LineWidth',1.7);grid on;xlabel('dx');ylabel('dphi');legend('Source RoadMap','Continued branch');
fprintf('LMZ_ROADMAP_WORKFLOW_OK seed=%d residual=%.3g solve=%s continuation=%d\n', ...
    index,evaluation.ScaledResidualNorm,solveResult.Output.algorithm, ...
    continuationResult.Branch.pointCount());
