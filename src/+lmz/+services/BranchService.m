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
            if strcmp(modelId,'slip_biped')
                problem=model.createProblem('periodic_apex',struct());
                catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
                branch=catalog.loadBranch(catalog.defaultBranchPath(),problem,true);
                return
            elseif strcmp(modelId,'slip_quad_load')
                problem=model.createProblem('multi_stride_fit',struct());
                catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
                dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset( ...
                    catalog.defaultMultiPath());
                solution=lmzmodels.slip_quad_load.XAccumAdapter.toSolution(problem,dataset);
                branch=lmz.data.SolutionBranch.fromSolutions(solution);
                return
            else
                error('lmz:Branch:BuiltInModel', ...
                    'No built-in branch adapter is registered for %s.',modelId);
            end
        end

        function branch=loadGaitMapBranch(~,problem,file)
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
            if nargin<3||isempty(file),file=catalog.defaultBranchPath();end
            if ~catalog.validateSourceHash(file)
                error('lmz:GaitMap:HashMismatch', ...
                    'Biped GaitMap source hash does not match its manifest.');
            end
            branch=catalog.loadBranch(file,problem,true);
        end

        function datasets=loadAllGaitMapBranches(obj,problem)
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
            files=catalog.listBranches();datasets=cell(1,numel(files));
            for index=1:numel(files)
                branch=obj.loadGaitMapBranch(problem,files{index});
                record=catalog.record(files{index});style=obj.styleFor(branch.Classifications{ ...
                    min(record.recommendedDefaultIndex,branch.pointCount())});
                metadata=struct('PointCount',branch.pointCount(), ...
                    'ParameterSummary','offset_left/offset_right', ...
                    'GaitSummary',record.gait,'SourceHash',record.sha256, ...
                    'NativePath',catalog.nativePath(files{index}), ...
                    'Status','built-in/read-only');
                datasets{index}=lmz.data.BranchDataset(record.name,branch, ...
                    'SourcePath',files{index},'ReadOnly',true, ...
                    'DisplayStyle',style,'Metadata',metadata);
            end
        end

        function [branch,dataset]=loadQuadLoadDataset(~,problem,file)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            if nargin<3||isempty(file),file=catalog.defaultMultiPath();end
            dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(file);
            solution=lmzmodels.slip_quad_load.XAccumAdapter.toSolution(problem,dataset);
            branch=lmz.data.SolutionBranch.fromSolutions(solution);
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
            descriptor=problem.getDescriptor();variables=whos('-file',file);names={variables.name};
            if any(strcmp(names,'X_accum'))
                dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(file);
                solution=lmzmodels.slip_quad_load.XAccumAdapter.toSolution(problem,dataset);
                branch=lmz.data.SolutionBranch.fromSolutions(solution);
            elseif strcmp(descriptor.modelId,'slip_biped')
                branch=lmzmodels.slip_biped.Results14Adapter.loadBranch(file,problem);
            else
                branch=lmzmodels.slip_quadruped.Results29Adapter.loadBranch(file,problem);
            end
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
            switch branch.ModelId
                case 'slip_quadruped'
                    results=lmzmodels.slip_quadruped.Results29Adapter.encode(branch); %#ok<NASGU>
                    save(path,'results');
                case 'slip_biped'
                    results=lmzmodels.slip_biped.Results14Adapter.encode(branch); %#ok<NASGU>
                    save(path,'results');
                case 'slip_quad_load'
                    if branch.pointCount()~=1
                        error('lmz:QuadLoad:LegacyCardinality', ...
                            'A load-pulling X_accum export requires exactly one point.');
                    end
                    X_accum=branch.DecisionValues(:,1); %#ok<NASGU>
                    save(path,'X_accum');
                otherwise
                    error('lmz:Branch:LegacyModel', ...
                        'No legacy exporter is registered for %s.',branch.ModelId);
            end
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
