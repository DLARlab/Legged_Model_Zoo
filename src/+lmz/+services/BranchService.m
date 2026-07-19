classdef BranchService
    %BRANCHSERVICE Generic branch operations plus manifest-driven RoadMap IO.
    methods
        function branch = loadBuiltInBranch(obj,registry,modelId)
            model=registry.createModel(modelId);
            if strcmp(modelId,'slip_quadruped')
                problem=model.createProblem('periodic_apex',struct());
                catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
                branch=obj.loadRoadMapBranch(problem,catalog.defaultBranchPath());
                return
            end
            if any(strcmp('periodic_apex',model.listProblems()))
                problem=model.createProblem('periodic_apex',struct());
                p=problem.getParameterSchema().defaults();speeds=linspace(0.7,1.5,7);
                solutions=lmz.data.Solution.empty(0,1);
                for index=1:numel(speeds)
                    u=[speeds(index);p(1)/speeds(index)];
                    evaluation=problem.evaluate(u,p,lmz.api.RunContext.synchronous(0),false);
                    solutions(index,1)=problem.makeSolution(u,p,evaluation);
                end
            else
                problem=model.createProblem('multi_stride_fit',struct());
                p=problem.getParameterSchema().defaults();target=p(:);
                defaults=problem.getDecisionSchema().defaults();solutions=lmz.data.Solution.empty(0,1);
                for index=1:7
                    u=defaults+(index-1)/6*(target-defaults);
                    solutions(index,1)=problem.makeSolution(u,p,[]);
                end
            end
            branch=lmz.data.SolutionBranch.fromSolutions(solutions);
        end
        function files = listRoadMapBranches(~)
            files=lmzmodels.slip_quadruped.RoadMapCatalog.default().listBranches();
        end
        function branch = loadRoadMapBranch(obj,problem,file)
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
            if isstruct(file), file=fullfile(catalog.RootPath,file.relativePath); end
            if ~catalog.validateSourceHash(file)
                error('lmz:RoadMap:HashMismatch','RoadMap source hash does not match the manifest.');
            end
            nativePath=catalog.nativePath(file);
            if exist(nativePath,'file')==2
                artifact=lmz.io.ArtifactStore.load(nativePath);
                expected=catalog.record(file).sha256;
                if isfield(artifact.diagnostics,'LegacySourceSHA256') && ...
                        strcmpi(artifact.diagnostics.LegacySourceSHA256,expected)
                    branch=lmz.data.SolutionBranch.fromArtifact(artifact);return
                end
            end
            branch=obj.reloadLegacySource(problem,file);
        end
        function datasets = loadAllRoadMapBranches(obj,problem)
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
            files=catalog.listBranches();datasets=cell(1,numel(files));
            for index=1:numel(files)
                branch=obj.loadRoadMapBranch(problem,files{index});record=catalog.record(files{index});
                style=obj.styleFor(branch.Classifications{min(2,branch.pointCount())});
                metadata=struct('PointCount',branch.pointCount(), ...
                    'ParameterSummary',record.parameterSummary,'GaitSummary',record.inferredGaitSummary, ...
                    'SourceHash',record.sha256,'NativePath',catalog.nativePath(files{index}), ...
                    'Status','built-in/read-only');
                [~,name,extension]=fileparts(files{index});
                datasets{index}=lmz.data.BranchDataset([name extension],branch, ...
                    'SourcePath',files{index},'ReadOnly',true, ...
                    'DisplayStyle',style,'Metadata',metadata);
            end
        end
        function branch = reloadLegacySource(~,problem,file)
            branch=lmzmodels.slip_quadruped.Results29Adapter.loadBranch(file,problem);
        end
        function matches = filterByFixedParameters(~,branches,name,value,tolerance)
            if nargin<5,tolerance=1e-10;end
            matches=lmzmodels.slip_quadruped.RoadMapCatalog.default(). ...
                filterByFixedParameters(branches,name,value,tolerance);
        end
        function names = identifyVaryingParameter(~,branch)
            names=lmzmodels.slip_quadruped.RoadMapCatalog.default().identifyVaryingParameter(branch);
        end
        function dataset = selectActiveDataset(~,datasets,datasetId)
            dataset=lmzmodels.slip_quadruped.RoadMapCatalog.default(). ...
                selectActiveDataset(datasets,datasetId);
        end
        function dataset=addDataset(~,name,branch),dataset=lmz.data.BranchDataset(name,branch);end
        function values=coordinateValues(~,dataset,name),values=dataset.Branch.coordinate(name);end
        function selection=selectPoint(~,dataset,index)
            solution=dataset.Branch.point(index);selection=lmz.data.Selection(dataset.Id,index,solution.Id,'branch');
        end
        function saveNativeBranch(~,path,branch),lmz.io.ArtifactStore.save(path,branch.toArtifact());end
        function branch=loadNativeBranch(~,path),artifact=lmz.io.ArtifactStore.load(path);branch=lmz.data.SolutionBranch.fromArtifact(artifact);end
        function exportLegacyBranch(~,path,branch)
            results=lmzmodels.slip_quadruped.Results29Adapter.encode(branch); %#ok<NASGU>
            save(path,'results');
        end
    end
    methods (Static, Access=private)
        function style=styleFor(classification)
            style=struct();
            if isfield(classification,'Color'),style.Color=classification.Color;end
            if isfield(classification,'LineStyle'),style.LineStyle=classification.LineStyle;end
            style.Marker='none';
        end
    end
end
