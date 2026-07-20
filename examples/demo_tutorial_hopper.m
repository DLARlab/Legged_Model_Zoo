%DEMO_TUTORIAL_HOPPER Run the built-in analytic hybrid-model workflow.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
originalDirectory = pwd;
directoryCleanup = onCleanup(@() cd(originalDirectory));
cd(projectRoot);
startup;
cd(originalDirectory);

registry = lmz.registry.ModelRegistry.discover();
model = registry.createModel('tutorial_hopper');
context = lmz.api.RunContext.synchronous(17);

demoProblem = model.createProblem('demo_hop', struct());
simulation = lmz.services.SimulationService().simulate( ...
    demoProblem, struct(), struct(), context);

periodicProblem = model.createProblem('periodic_hop', struct());
decision = periodicProblem.getDecisionSchema().defaults();
parameters = periodicProblem.getParameterSchema().defaults();
seedDecision = decision;
seedDecision(5) = seedDecision(5) + 0.08;
seed = periodicProblem.makeSolution(seedDecision, parameters, []);
solveResult = lmz.services.SolveService().solve( ...
    periodicProblem, seed, struct('MaxIterations', 100, ...
    'MaxFunctionEvaluations', 500), context);

secondDecision = decision;
secondDecision(4) = secondDecision(4) + 0.02;
secondDecision(5) = secondDecision(4) * secondDecision(2);
firstSolution = periodicProblem.makeSolution(decision, parameters, ...
    periodicProblem.evaluate(decision, parameters, context, false));
secondSolution = periodicProblem.makeSolution(secondDecision, parameters, ...
    periodicProblem.evaluate(secondDecision, parameters, context, false));
metric = lmz.schema.DiagonalMetric(periodicProblem.scale(decision));
radius = metric.norm(periodicProblem.difference(secondDecision, decision));
pair = lmz.data.SolutionPair(firstSolution, secondSolution, ...
    radius, radius, struct('source', 'analytic-tutorial-pair'));
continuation = lmz.services.ContinuationService().run( ...
    periodicProblem, pair, struct('MaximumPoints', 4, ...
    'BothDirections', false, 'InitialStep', radius, ...
    'MaximumStep', radius), context);

if solveResult.ExitFlag <= 0 || continuation.Branch.pointCount() ~= 4
    error('lmz:Example:TutorialHopper', ...
        'The tutorial solve or continuation did not complete.');
end
output = struct('Simulation', simulation, 'SolveResult', solveResult, ...
    'ContinuationResult', continuation, ...
    'ResidualNorm', solveResult.Evaluation.ScaledResidualNorm, ...
    'PointCount', continuation.Branch.pointCount(), ...
    'SuccessMarker', 'LMZ_TUTORIAL_HOPPER_OK');
fprintf('%s residual=%.3g points=%d\n', output.SuccessMarker, ...
    output.ResidualNorm, output.PointCount);
clear directoryCleanup
