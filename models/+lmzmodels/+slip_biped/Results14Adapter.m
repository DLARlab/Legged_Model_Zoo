classdef Results14Adapter
    %RESULTS14ADAPTER Lossless Results14/native SolutionBranch boundary.
    methods (Static)
        function branch=loadBranch(path,problem,gaitLabel)
            if nargin<2||isempty(problem)
                registry=lmz.registry.ModelRegistry.discover();
                problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());
            end
            if nargin<3,gaitLabel=lmzmodels.slip_biped.Results14Adapter.labelFromPath(path);end
            loaded=load(path,'results');
            if ~isfield(loaded,'results')
                error('lmz:slip_biped:LegacyFormat','Expected variable results.');
            end
            [~,name,extension]=fileparts(path);
            provenance=struct('SourcePath',path,'SourceFile',[name extension], ...
                'SourceHash',lmz.util.FileHash.sha256(path), ...
                'LegacyVariable','results','ImportedAt',datestr(now,30), ...
                'GaitLabel',gaitLabel);
            branch=lmzmodels.slip_biped.Results14Adapter.decode(loaded.results,problem,provenance);
        end
        function branch=decode(results,problem,provenance)
            lmzmodels.slip_biped.Results14Layout.validate(results);
            if nargin<2||isempty(problem)
                registry=lmz.registry.ModelRegistry.discover();
                problem=registry.createModel('slip_biped').createProblem('periodic_apex',struct());
            end
            if nargin<3,provenance=struct();end
            decisionSchema=problem.getDecisionSchema();parameterSchema=problem.getParameterSchema();
            expectedDecision=reshape(lmzmodels.slip_biped.Results14Layout.DecisionNames,[],1);
            expectedParameters=reshape(lmzmodels.slip_biped.Results14Layout.ParameterNames,[],1);
            if ~isequal(decisionSchema.names(),expectedDecision) || ...
                    ~isequal(parameterSchema.names(),expectedParameters)
                error('lmz:slip_biped:SchemaMismatch', ...
                    'Results14 conversion requires scientific periodic_apex schemas.');
            end
            decision=results(1:12,:);parameters=results(13:14,:);n=size(results,2);
            modelManifest=problem.Model.getManifest();
            template=struct('Id','','ModelVersion',modelManifest.version, ...
                'ProblemVersion',problem.Version,'CreatedAt',datestr(now,30), ...
                'ResidualBlocks',{{}},'Diagnostics',struct(), ...
                'Feasibility',struct('Valid',true),'Source',struct(),'Provenance',struct());
            metadata=repmat(template,1,n);observables=cell(1,n);classifications=cell(1,n);
            sourceFile=lmzmodels.slip_biped.Results14Adapter.fieldOr(provenance,'SourceFile','');
            sourcePath=lmzmodels.slip_biped.Results14Adapter.fieldOr(provenance,'SourcePath','');
            sourceHash=lmzmodels.slip_biped.Results14Adapter.fieldOr(provenance,'SourceHash','');
            gaitLabel=lmzmodels.slip_biped.Results14Adapter.fieldOr(provenance,'GaitLabel','');
            for index=1:n
                gait=lmzmodels.slip_biped.GaitClassifier.classify(decision(:,index),gaitLabel);
                classifications{index}=gait;period=decision(12,index);
                events=mod(decision(8:11,index),period);
                durations=mod(decision([9 11],index)-decision([8 10],index),period);
                sortedEvents=sort(events);gaps=diff([sortedEvents;sortedEvents(1)+period]);
                observables{index}=struct('apex_forward_velocity',decision(1,index), ...
                    'stride_period',period,'duty_factors',durations(:).'/period, ...
                    'event_phases',events(:).'/period,'minimum_event_gap',min(gaps), ...
                    'gait_code',gait.Code,'gait_name',gait.Name, ...
                    'gait_abbreviation',gait.Abbreviation);
                metadata(index).Id=lmz.util.Ids.new('solution');
                metadata(index).Source=struct('File',sourceFile,'Path',sourcePath, ...
                    'ColumnIndex',index,'SHA256',sourceHash,'LegacyVariable','results');
                metadata(index).Diagnostics=struct('ResidualEvaluated',false, ...
                    'ResidualNorm',NaN,'ImportedFromResults14',true, ...
                    'GaitLabel',gaitLabel);
                metadata(index).Provenance=struct('SourceCommit', ...
                    '4595146c5881a5313bc8fe92de85099193ef9be9');
            end
            chart=lmz.schema.VariableChart(decisionSchema);
            metric=lmz.schema.DiagonalMetric(arrayfun(@(x)x.Scale,decisionSchema.Specs(:)));
            arclength=zeros(1,n);
            for index=2:n
                arclength(index)=arclength(index-1)+metric.norm( ...
                    chart.difference(decision(:,index),decision(:,index-1)));
            end
            branchProvenance=provenance;
            branchProvenance.SourceRepository= ...
                'https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git';
            branchProvenance.SourceCommit='4595146c5881a5313bc8fe92de85099193ef9be9';
            branchProvenance.Adapter='Results14Adapter-v1';
            data=struct('Id',lmz.util.Ids.new('branch'),'ModelId','slip_biped', ...
                'ProblemId','periodic_apex','DecisionSchema',decisionSchema, ...
                'ParameterSchema',parameterSchema,'DecisionValues',decision, ...
                'ParameterValues',parameters,'PointMetadata',metadata, ...
                'Observables',{observables},'Classifications',{classifications}, ...
                'Arclength',arclength,'Tangents',[],'Lineage',struct( ...
                'Operation','legacy-import','SourceBranchId',sourceFile), ...
                'Diagnostics',struct('PointCount',n,'ExactLegacyRoundTrip',true), ...
                'Provenance',branchProvenance);
            branch=lmz.data.SolutionBranch(data);
        end
        function results=encode(branch)
            expectedDecision=reshape(lmzmodels.slip_biped.Results14Layout.DecisionNames,[],1);
            expectedParameters=reshape(lmzmodels.slip_biped.Results14Layout.ParameterNames,[],1);
            if ~isa(branch,'lmz.data.SolutionBranch') || ...
                    ~isequal(branch.DecisionSchema.names(),expectedDecision) || ...
                    ~isequal(branch.ParameterSchema.names(),expectedParameters)
                error('lmz:slip_biped:SchemaMismatch','Branch does not use Results14 schemas.');
            end
            results=[branch.DecisionValues;branch.ParameterValues];
            lmzmodels.slip_biped.Results14Layout.validate(results);
        end
        function artifact=toNativeArtifact(path,problem,gaitLabel)
            if nargin<3,gaitLabel=lmzmodels.slip_biped.Results14Adapter.labelFromPath(path);end
            branch=lmzmodels.slip_biped.Results14Adapter.loadBranch(path,problem,gaitLabel);
            artifact=branch.toArtifact();
            artifact.sourceCommitSHAs=struct('JerboaBiped', ...
                '4595146c5881a5313bc8fe92de85099193ef9be9');
            artifact.diagnostics.LegacySourceSHA256=lmz.util.FileHash.sha256(path);
        end
    end
    methods (Static, Access=private)
        function value=fieldOr(source,name,fallback)
            if isfield(source,name),value=source.(name);else,value=fallback;end
        end
        function value=labelFromPath(path)
            [~,name]=fileparts(path);
            switch upper(name)
                case 'W1',value='walking';case 'R1',value='running';
                case 'HP1',value='hopping';case {'SK1','SK2'},value='skipping';
                case 'AR1',value='asymmetric running';otherwise,value='';
            end
        end
    end
end
