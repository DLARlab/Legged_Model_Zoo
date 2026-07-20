classdef XAccumAdapter
    %XACCUMADAPTER Central exact import/export for 44+13*(N-1) vectors.
    methods (Static)
        function count=strideCount(vector)
            count=lmzmodels.slip_quad_load.MultiStrideDecisionSchema.strideCount(vector);
        end
        function decoded=decode(vector)
            if ~isnumeric(vector)||~isreal(vector)||any(~isfinite(vector(:)))
                error('lmz:QuadLoad:XAccumType','X_accum must be finite real numeric data.');
            end
            vector=vector(:);count=lmzmodels.slip_quad_load.XAccumAdapter.strideCount(vector);
            firstLength=lmzmodels.slip_quad_load.FirstStrideLayout.Length;
            first=lmzmodels.slip_quad_load.FirstStrideLayout.decode(vector(1:firstLength));
            later=repmat(struct('StrideIndex',0,'Vector',[],'Named',struct(), ...
                'EventTiming',[],'PostSwingStiffness',[]),max(0,count-1),1);
            for stride=2:count
                indices=lmzmodels.slip_quad_load.LaterStrideLayout.globalIndices(stride);
                later(stride-1)=lmzmodels.slip_quad_load.LaterStrideLayout.decode( ...
                    vector(indices.Block),stride);
            end
            decoded=struct('SchemaVersion','1.0.0','StrideCount',count, ...
                'Vector',vector,'Schema',lmzmodels.slip_quad_load.MultiStrideDecisionSchema.create(count,vector), ...
                'FirstStride',first,'LaterStrides',later);
        end
        function vector=encode(value)
            if isa(value,'lmz.data.Solution'),vector=value.DecisionValues(:);
            elseif isnumeric(value),vector=value(:);
            elseif isstruct(value)&&isfield(value,'Vector'),vector=value.Vector(:);
            elseif isstruct(value)&&isfield(value,'FirstStride')&&isfield(value,'LaterStrides')
                vector=lmzmodels.slip_quad_load.FirstStrideLayout.encode(value.FirstStride);
                for index=1:numel(value.LaterStrides)
                    vector=[vector;lmzmodels.slip_quad_load.LaterStrideLayout.encode(value.LaterStrides(index))]; %#ok<AGROW>
                end
            else,error('lmz:QuadLoad:XAccumEncode','Unsupported X_accum representation.');end
            lmzmodels.slip_quad_load.XAccumAdapter.decode(vector);
        end
        function dataset=loadDataset(path)
            if exist(path,'file')~=2,error('lmz:QuadLoad:DatasetMissing','Dataset does not exist: %s',path);end
            variables=whos('-file',path);names={variables.name};
            loaded=lmz.io.SafeMat.loadVariables(path,names);
            if ~isfield(loaded,'X_accum'),error('lmz:QuadLoad:DatasetVariable','Dataset lacks X_accum.');end
            decoded=lmzmodels.slip_quad_load.XAccumAdapter.decode(loaded.X_accum);
            weights=struct('strideduration',10,'ft',10,'loadingforce',10);
            if isfield(loaded,'term_weights'),weights=loaded.term_weights;end
            experimental=struct('t_exp',[],'ft_exp',[],'loading_force_exp',[]);
            kind='unknown';gait='';sensitivity=struct();storedR2=struct();
            if isfield(loaded,'gait_data')
                kind='single_stride';source=loaded.gait_data;
                experimental.t_exp=source.t_exp;experimental.ft_exp=source.ft_exp;
                experimental.loading_force_exp=source.loading_force_mean;
                if isfield(loaded,'gait_type'),gait=loaded.gait_type;end
            elseif isfield(loaded,'TransitionTemplate_Normalized')
                kind='gait_transition';source=loaded.TransitionTemplate_Normalized;
                experimental.t_exp=source.t_exp;experimental.ft_exp=source.ft_exp;
                experimental.loading_force_exp=source.loading_force_exp;
                if isfield(loaded,'SensitivityStudyData'),sensitivity=loaded.SensitivityStudyData;end
                if isfield(loaded,'R2'),storedR2=loaded.R2;end
            else
                source=struct();
            end
            [~,name,extension]=fileparts(path);
            dataset=struct('Id',name,'Name',[name extension],'Path',path,'Kind',kind, ...
                'StrideCount',decoded.StrideCount,'XAccum',decoded.Vector,'Decoded',decoded, ...
                'Experimental',experimental,'TermWeights',weights,'GaitType',gait, ...
                'SensitivityStudyData',sensitivity,'StoredR2',storedR2, ...
                'SourceData',source,'RawFields',{fieldnames(loaded)}, ...
                'Provenance',struct('sourceRepository', ...
                'https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git', ...
                'sourceCommit','19f3133073c988cc0c3424a647b4adbb60a90b99', ...
                'sourcePath',path));
        end
        function solution=toSolution(problem,dataset)
            if ischar(dataset),dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(dataset);end
            if problem.getDecisionSchema().count()~=numel(dataset.XAccum)
                if dataset.StrideCount==1
                    problem=problem.Model.createProblem('single_stride', ...
                        struct('DatasetPath',dataset.Path));
                else
                    problem=problem.Model.createProblem('multi_stride_fit', ...
                        struct('DatasetPath',dataset.Path,'InitialPerturbation',0));
                end
            end
            parameterValues=[fieldOr(dataset.TermWeights,'strideduration',10); ...
                fieldOr(dataset.TermWeights,'ft',10);fieldOr(dataset.TermWeights,'loadingforce',10)];
            solution=problem.makeSolution(dataset.XAccum,parameterValues,[]);
        end
        function exportLegacy(path,dataset)
            if ischar(dataset),dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(dataset);end
            payload=struct('X_accum',dataset.XAccum);
            if strcmp(dataset.Kind,'single_stride')
                payload.gait_data=dataset.SourceData;payload.gait_type=dataset.GaitType;
            elseif strcmp(dataset.Kind,'gait_transition')
                payload.TransitionTemplate_Normalized=dataset.SourceData;
                if ~isempty(fieldnames(dataset.SensitivityStudyData)),payload.SensitivityStudyData=dataset.SensitivityStudyData;end
                if ~isempty(fieldnames(dataset.StoredR2)),payload.R2=dataset.StoredR2;end
            end
            payload.term_weights=dataset.TermWeights;
            save(path,'-struct','payload');
        end
    end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
