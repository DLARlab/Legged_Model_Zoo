classdef TestRound9WorkflowArtifacts < matlab.unittest.TestCase
    methods (Test)
        function contactTimingRoundTripAndReproduction(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            model=registry.createModel('tutorial_hopper');
            problem=model.createProblem('section_return_timing',struct());
            original=lmz.services.ContactTimingService().solve(problem, ...
                problem.InputSchedule,struct(), ...
                lmz.api.RunContext.synchronous(921));
            artifact=original.toArtifact();
            testCase.verifyEqual(artifact.artifactType,'contact-timing-run');
            testCase.verifyTrue(isfield(artifact,'poincareMetadata'));
            testCase.verifyEqual(artifact.contactTimingResult.FreeMask, ...
                original.FreeMask);
            [loaded,pathCleanup]=saveAndLoad(artifact); %#ok<ASGLU>
            restored=lmz.data.ContactTimingResult.fromArtifact(loaded);
            testCase.verifyEqual(restored.FixedInitialState, ...
                original.FixedInitialState);
            testCase.verifyEqual(restored.SolvedSchedule.times(), ...
                original.SolvedSchedule.times(),'AbsTol',0);
            [reproduced,report]=lmz.services.reproduceRun(loaded);
            testCase.verifyClass(reproduced,'lmz.data.ContactTimingResult');
            testCase.verifyEqual(report.RandomSeed,921);
            testCase.verifyEqual(reproduced.SolvedSchedule.times(), ...
                original.SolvedSchedule.times(),'AbsTol',1e-12);
            clear pathCleanup
        end

        function sectionTransferRoundTripAndReproduction(testCase)
            registry=lmz.registry.ModelRegistry.discover();
            model=registry.createModel('tutorial_hopper');
            problem=model.createProblem('periodic_hop',struct());
            decision=problem.getDecisionSchema().defaults();
            parameters=problem.getParameterSchema().defaults();
            context=lmz.api.RunContext.synchronous(922);
            evaluation=problem.evaluate(decision,parameters,context,true);
            source=problem.makeSolution(decision,parameters,evaluation);
            original=lmz.services.SectionTransferService().transfer( ...
                model,source,'ground_impact_post',context);
            artifact=original.toArtifact(922);
            testCase.verifyEqual(artifact.targetSectionId, ...
                'ground_impact_post');
            testCase.verifyTrue(isfield(artifact.poincareMetadata. ...
                Sections{2},'DescriptorHash'));
            testCase.verifyEqual(artifact.strideDefinition.StartSectionId, ...
                original.Lineage.SourceSectionId);
            testCase.verifyEqual(artifact.strideDefinition.StopSectionId, ...
                original.Lineage.TargetSectionId);
            testCase.verifyEqual(artifact.strideDefinitionHash, ...
                lmz.poincare.StrideDefinition( ...
                artifact.strideDefinition).fingerprint());
            [loaded,pathCleanup]=saveAndLoad(artifact); %#ok<ASGLU>
            restored=lmz.data.SectionTransferResult.fromArtifact(loaded);
            testCase.verifyEqual(restored.Crossing.SectionId, ...
                'ground_impact_post');
            testCase.verifyEqual(restored.Simulation.Time, ...
                original.Simulation.Time,'AbsTol',0);
            [reproduced,report]=lmz.services.reproduceRun(loaded);
            testCase.verifyClass(reproduced,'lmz.data.SectionTransferResult');
            testCase.verifyEqual(report.ArtifactType,'section-transfer-run');
            testCase.verifyEqual(reproduced.Crossing.SectionId, ...
                original.Crossing.SectionId);
            testCase.verifyEqual(reproduced.PhysicalOrbitMaxError, ...
                original.PhysicalOrbitMaxError,'AbsTol',1e-12);
            clear pathCleanup
        end

        function stridePlanAndPartialCompletionArtifactsRoundTrip(testCase)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            dataset=catalog.load('individual_1_tr_to_rl');
            plan=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan( ...
                dataset.XAccum);
            artifact=plan.toArtifact();
            testCase.verifyEqual(artifact.artifactType,'stride-plan');
            testCase.verifyEqual(numel(artifact.stridePlan.StrideSpecs),2);
            [loaded,planCleanup]=saveAndLoad(artifact); %#ok<ASGLU>
            restored=lmz.multistride.StridePlan.fromArtifact(loaded);
            testCase.verifyEqual( ...
                lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(restored), ...
                dataset.XAccum,'AbsTol',0);

            request=lmz.multistride.MultiStrideRequest( ...
                'NumberOfStrides',3,'InitialDecision',dataset.XAccum, ...
                'CompletionPolicy','request_user');
            original=lmz.services.MultiStrideSimulationService().simulate( ...
                registryModel('slip_quad_load'),request, ...
                lmz.api.RunContext.synchronous(923));
            testCase.verifyTrue(original.Partial);
            runArtifact=original.toArtifact(request,923);
            testCase.verifyEqual(runArtifact.artifactType, ...
                'stride-plan-completion-run');
            [loadedRun,runCleanup]=saveAndLoad(runArtifact); %#ok<ASGLU>
            restoredRun=lmz.multistride.MultiStrideResult.fromArtifact(loadedRun);
            testCase.verifyEqual(restoredRun.CompletedStrideCount,2);
            [reproduced,report]=lmz.services.reproduceRun(loadedRun);
            testCase.verifyTrue(reproduced.Partial);
            testCase.verifyEqual(reproduced.CompletionStatus, ...
                'missing_stride_specification');
            testCase.verifyEqual(report.RandomSeed,923);
            clear planCleanup runCleanup
        end

        function nStrideSimulationRoundTripAndReproduction(testCase)
            request=lmz.multistride.MultiStrideRequest( ...
                'NumberOfStrides',3);
            original=lmz.services.MultiStrideSimulationService().simulate( ...
                registryModel('tutorial_hopper'),request, ...
                lmz.api.RunContext.synchronous(924));
            artifact=original.toArtifact(request,924);
            testCase.verifyEqual(artifact.artifactType, ...
                'n-stride-simulation-run');
            testCase.verifyEqual(artifact.stridePlan.RequestedStrideCount,3);
            [loaded,pathCleanup]=saveAndLoad(artifact); %#ok<ASGLU>
            restored=lmz.multistride.MultiStrideResult.fromArtifact(loaded);
            testCase.verifyEqual(restored.Simulation.Time, ...
                original.Simulation.Time,'AbsTol',0);
            [reproduced,report]=lmz.services.reproduceRun(loaded);
            testCase.verifyClass(reproduced, ...
                'lmz.multistride.MultiStrideResult');
            testCase.verifyEqual(reproduced.CompletedStrideCount,3);
            testCase.verifyEqual(reproduced.Simulation.States, ...
                original.Simulation.States,'AbsTol',1e-12);
            testCase.verifyEqual(report.ArtifactType, ...
                'n-stride-simulation-run');
            clear pathCleanup
        end

        function nStridePeriodicProducerRoundTripAndReproduction(testCase)
            model=registryModel('slip_quad_load');
            problem=model.createProblem('n_stride_periodic',struct( ...
                'NumberOfStrides',2,'StartSectionId','apex', ...
                'StopSectionId','apex'));
            decision=problem.getDecisionSchema().defaults();
            parameters=problem.getParameterSchema().defaults();
            context=lmz.api.RunContext.synchronous(925);
            evaluated=problem.evaluate(decision,parameters,context,false);
            seed=problem.makeSolution(decision,parameters,evaluated);
            tolerance=evaluated.ScaledResidualNorm+ ...
                max(1,evaluated.ScaledResidualNorm);
            options=struct('AcceptExistingTolerance',tolerance);
            run=lmz.services.SolveService().solve( ...
                problem,seed,options,context);
            testCase.verifyEqual(run.Output.algorithm, ...
                'accepted-existing-seed');

            artifact=problem.toRunArtifact(run);
            testCase.verifyEqual(artifact.artifactType, ...
                'n-stride-periodic-run');
            testCase.verifyEqual(artifact.terminationReason, ...
                'accepted-existing-seed');
            testCase.verifyTrue( ...
                artifact.nStridePeriodicResult.AcceptedExistingSeed);
            testCase.verifyEqual(artifact.nStridePeriodicResult. ...
                Evaluation.ScaledResidualNorm, ...
                run.Evaluation.ScaledResidualNorm,'AbsTol',0);
            testCase.verifyGreaterThanOrEqual(tolerance, ...
                artifact.nStridePeriodicResult. ...
                Evaluation.ScaledResidualNorm);
            testCase.verifyEqual(artifact.stridePlan.RequestedStrideCount,2);
            testCase.verifyEqual(artifact.stridePlan.CompletedStrideCount,2);
            testCase.verifyEqual(artifact.stridePlanHash, ...
                lmz.io.ArtifactStore.dataHash(artifact.stridePlan));
            testCase.verifyEqual(artifact.problemConfigurationHash, ...
                lmz.io.ArtifactStore.dataHash( ...
                artifact.problemMetadata.configuration));
            testCase.verifyEqual(artifact.strideDefinitionHash, ...
                lmz.poincare.StrideDefinition( ...
                artifact.strideDefinition).fingerprint());
            corruptedPlan=artifact;
            corruptedPlan.stridePlan.FailurePolicy='error';
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate(corruptedPlan), ...
                'lmz:Artifact:StridePlanHash');
            corruptedConfiguration=artifact;
            corruptedConfiguration.problemMetadata.configuration. ...
                NumberOfStrides=1;
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate(corruptedConfiguration), ...
                'lmz:Artifact:ProblemConfigurationHash');

            [loaded,pathCleanup]=saveAndLoad(artifact); %#ok<ASGLU>
            restored=lmz.data.Solution.fromStruct( ...
                loaded.nStridePeriodicResult.Solution);
            testCase.verifyEqual(restored.DecisionValues, ...
                run.Solution.DecisionValues,'AbsTol',0);
            [reproduced,report]=lmz.services.reproduceRun(loaded);
            testCase.verifyClass(reproduced,'lmz.data.SolveResult');
            testCase.verifyEqual(reproduced.Output.algorithm, ...
                'accepted-existing-seed');
            testCase.verifyEqual(report.Options.AcceptExistingTolerance, ...
                tolerance,'AbsTol',0);
            testCase.verifyGreaterThanOrEqual(report.VerifiedHashCount,1);
            names={report.HashChecks.Name};
            catalogCheck=find(strcmp(names,'PoincareCatalog'),1);
            testCase.verifyNotEmpty(catalogCheck);
            testCase.verifyTrue(report.HashChecks(catalogCheck).Verified);
            testCase.verifyEqual(reproduced.Solution.DecisionValues, ...
                run.Solution.DecisionValues,'AbsTol',0);
            clear pathCleanup
        end

        function strideDefinitionMigrationAndExecutableRejection(testCase)
            artifact=tutorialTransferArtifact(926);
            testCase.verifyTrue(isfield(artifact,'strideDefinition'));
            testCase.verifyTrue(isfield(artifact,'strideDefinitionHash'));
            expectedRecord=artifact.strideDefinition;
            expectedHash=artifact.strideDefinitionHash;

            legacy=rmfield(artifact, ...
                {'strideDefinition','strideDefinitionHash'});
            [loaded,pathCleanup]=saveRawAndLoad(legacy); %#ok<ASGLU>
            testCase.verifyEqual(loaded.strideDefinition,expectedRecord);
            testCase.verifyEqual(loaded.strideDefinitionHash,expectedHash);

            malicious=artifact;
            malicious.strideDefinition.Callback=@sin;
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate(malicious), ...
                'lmz:Artifact:ExecutableWorkflowData');
            corrupted=artifact;
            corrupted.strideDefinition.StopSectionId='apex';
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate(corrupted), ...
                'lmz:Artifact:StrideDefinitionHash');
            corruptedDescriptor=artifact;
            corruptedDescriptor.poincareMetadata.Sections{1}. ...
                Descriptor.label='tampered';
            testCase.verifyError( ...
                @()lmz.io.ArtifactStore.validate(corruptedDescriptor), ...
                'lmz:Artifact:PoincareDescriptorHash');
            clear pathCleanup
        end
    end
end

function model=registryModel(modelId)
model=lmz.registry.ModelRegistry.discover().createModel(modelId);
end

function [loaded,cleanup]=saveAndLoad(artifact)
path=[tempname '.mat'];cleanup=onCleanup(@()deleteFile(path));
lmz.io.ArtifactStore.save(path,artifact);
loaded=lmz.io.ArtifactStore.load(path);
end

function [loaded,cleanup]=saveRawAndLoad(artifact)
path=[tempname '.mat'];cleanup=onCleanup(@()deleteFile(path));
save(path,'artifact');
loaded=lmz.io.ArtifactStore.load(path);
end

function artifact=tutorialTransferArtifact(randomSeed)
model=registryModel('tutorial_hopper');
problem=model.createProblem('periodic_hop',struct());
decision=problem.getDecisionSchema().defaults();
parameters=problem.getParameterSchema().defaults();
context=lmz.api.RunContext.synchronous(randomSeed);
evaluation=problem.evaluate(decision,parameters,context,true);
source=problem.makeSolution(decision,parameters,evaluation);
result=lmz.services.SectionTransferService().transfer( ...
    model,source,'ground_impact_post',context);
artifact=result.toArtifact(randomSeed);
end

function deleteFile(path)
if exist(path,'file')==2,delete(path);end
end
