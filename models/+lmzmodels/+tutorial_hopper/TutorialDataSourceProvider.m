classdef TutorialDataSourceProvider < lmz.workflow.BranchCatalogProvider
    %TUTORIALDATASOURCEPROVIDER Deterministic exact analytic hop family.
    methods
        function records = list(~,descriptor,registry) %#ok<INUSD>
            records = struct('id','exact_hop_family', ...
                'label','Exact analytic hop family', ...
                'path','','sourcePath','','sourceHash','', ...
                'pointCount',3,'recommendedPointIndex',2);
        end

        function dataset = load(obj,descriptor,datasetId,registry)
            if ~strcmp(datasetId,'exact_hop_family')
                error('lmz:Tutorial:UnknownDataset', ...
                    'Unknown tutorial dataset: %s',datasetId);
            end
            model = registry.createModel(descriptor.ModelId);
            problem = model.createProblem(descriptor.ProblemId,struct());
            branch = exactBranch(problem,[0.9 1.0 1.1]);
            metadata = struct('DatasetId',datasetId, ...
                'PointCount',branch.pointCount(), ...
                'RecommendedPointIndex',2, ...
                'Status','generated-tutorial/read-only', ...
                'Construction','closed-form periodic hopper family');
            dataset = lmz.data.BranchDataset( ...
                'Exact analytic hop family',branch,'ReadOnly',true, ...
                'DisplayStyle',obj.displayStyle(descriptor,datasetId), ...
                'Metadata',metadata);
        end
    end
end

function branch = exactBranch(problem,speeds)
gravity = problem.getParameterSchema().defaults();
period = sqrt(8/gravity(1));
parameters = gravity;
solutions = lmz.data.Solution.empty(0,numel(speeds));
for index = 1:numel(speeds)
    decision = [1;period;gravity(1)*period;speeds(index); ...
        speeds(index)*period];
    solutions(index) = problem.makeSolution(decision,parameters,[]);
end
branch = lmz.data.SolutionBranch.fromSolutions(solutions);
end
