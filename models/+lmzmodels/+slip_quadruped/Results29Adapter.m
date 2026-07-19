classdef Results29Adapter
    %RESULTS29ADAPTER Lossless boundary from legacy matrices to native branches.
    methods (Static)
        function branch = loadBranch(path,problem)
            if nargin < 2
                registry = lmz.registry.ModelRegistry.discover();
                problem = registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());
            end
            loaded = load(path,'results');
            if ~isfield(loaded,'results')
                error('lmz:slip_quadruped:LegacyFormat','Expected variable results.');
            end
            [~,name,extension] = fileparts(path);
            provenance = struct('SourcePath',path,'SourceFile',[name extension], ...
                'SourceHash',lmz.util.FileHash.sha256(path), ...
                'LegacyVariable','results','ImportedAt',datestr(now,30));
            branch = lmzmodels.slip_quadruped.Results29Adapter.decode( ...
                loaded.results,problem,provenance);
        end

        function branch = decode(results,problem,provenance)
            lmzmodels.slip_quadruped.Results29Layout.validate(results);
            if nargin < 2 || isempty(problem)
                registry = lmz.registry.ModelRegistry.discover();
                problem = registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());
            end
            if nargin < 3, provenance = struct(); end
            decisionSchema = problem.getDecisionSchema();
            parameterSchema = problem.getParameterSchema();
            expectedDecision = lmzmodels.slip_quadruped.PeriodicDecisionSchema.create().names();
            expectedParameters = lmzmodels.slip_quadruped.ParameterSchema.create().names();
            if ~isequal(decisionSchema.names(),expectedDecision) || ...
                    ~isequal(parameterSchema.names(),expectedParameters)
                error('lmz:slip_quadruped:SchemaMismatch', ...
                    'Results29 conversion requires the scientific periodic_apex schemas.');
            end
            decision = results(lmzmodels.slip_quadruped.Results29Layout.DecisionRows,:);
            parameters = results(lmzmodels.slip_quadruped.Results29Layout.ParameterRows,:);
            n = size(results,2); descriptor = problem.getDescriptor();
            metadataTemplate = struct('Id','','ModelVersion',descriptor.modelVersion, ...
                'ProblemVersion',descriptor.version,'CreatedAt',datestr(now,30), ...
                'ResidualBlocks',{{}},'Diagnostics',struct(), ...
                'Feasibility',struct('Valid',true),'Source',struct(), ...
                'Provenance',struct());
            metadata = repmat(metadataTemplate,1,n);
            observables = cell(1,n); classifications = cell(1,n);
            sourceFile = lmzmodels.slip_quadruped.Results29Adapter.fieldOr(provenance,'SourceFile','');
            sourcePath = lmzmodels.slip_quadruped.Results29Adapter.fieldOr(provenance,'SourcePath','');
            sourceHash = lmzmodels.slip_quadruped.Results29Adapter.fieldOr(provenance,'SourceHash','');
            sourceCommit = '2c106101383ecee1b2a9d695efe09fbd72d5718a';
            for index = 1:n
                gait = lmzmodels.slip_quadruped.GaitClassifier.classify(decision(:,index));
                classifications{index} = gait;
                period = decision(22,index); events = mod(decision(14:21,index),period);
                durations = mod(decision([15 17 19 21],index)- ...
                    decision([14 16 18 20],index),period);
                sortedEvents = sort(events);
                gaps = diff([sortedEvents;sortedEvents(1)+period]);
                observables{index} = struct('forward_speed',decision(1,index), ...
                    'stride_period',period,'duty_factors',durations(:).'/period, ...
                    'event_phases',events(:).'/period,'minimum_event_gap',min(gaps), ...
                    'gait_name',gait.Name,'gait_abbreviation',gait.Abbreviation);
                metadata(index).Id = lmz.util.Ids.new('solution');
                metadata(index).Source = struct('File',sourceFile,'Path',sourcePath, ...
                    'ColumnIndex',index,'SHA256',sourceHash,'LegacyVariable','results');
                metadata(index).Diagnostics = struct('ResidualEvaluated',false, ...
                    'ResidualNorm',NaN,'ImportedFromResults29',true);
                metadata(index).Provenance = struct('SourceCommit',sourceCommit);
            end
            chart = lmz.schema.VariableChart(decisionSchema);
            metric = lmz.schema.DiagonalMetric(arrayfun(@(x)x.Scale,decisionSchema.Specs(:)));
            arclength = zeros(1,n);
            for index = 2:n
                arclength(index) = arclength(index-1)+metric.norm( ...
                    chart.difference(decision(:,index),decision(:,index-1)));
            end
            branchProvenance = provenance;
            branchProvenance.SourceRepository = 'https://github.com/DLARlab/SLIP_Model_Zoo.git';
            branchProvenance.SourceCommit = sourceCommit;
            branchProvenance.Adapter = 'Results29Adapter-v2';
            data = struct('Id',lmz.util.Ids.new('branch'), ...
                'ModelId','slip_quadruped','ProblemId','periodic_apex', ...
                'DecisionSchema',decisionSchema,'ParameterSchema',parameterSchema, ...
                'DecisionValues',decision,'ParameterValues',parameters, ...
                'PointMetadata',metadata,'Observables',{observables}, ...
                'Classifications',{classifications},'Arclength',arclength, ...
                'Tangents',[],'Lineage',struct('Operation','legacy-import', ...
                'SourceBranchId',sourceFile),'Diagnostics',struct( ...
                'PointCount',n,'ExactLegacyRoundTrip',true), ...
                'Provenance',branchProvenance);
            branch = lmz.data.SolutionBranch(data);
        end

        function results = encode(branch)
            if ~isa(branch,'lmz.data.SolutionBranch')
                error('lmz:slip_quadruped:LegacyFormat', ...
                    'Legacy export requires a native SolutionBranch.');
            end
            expectedDecision = lmzmodels.slip_quadruped.PeriodicDecisionSchema.create().names();
            expectedParameters = lmzmodels.slip_quadruped.ParameterSchema.create().names();
            if ~isequal(branch.DecisionSchema.names(),expectedDecision) || ...
                    ~isequal(branch.ParameterSchema.names(),expectedParameters)
                error('lmz:slip_quadruped:SchemaMismatch', ...
                    'Branch schemas do not match Results29 order.');
            end
            results = [branch.DecisionValues;branch.ParameterValues];
            if size(results,1) ~= lmzmodels.slip_quadruped.Results29Layout.RowCount || ...
                    any(~isfinite(results(:)))
                error('lmz:slip_quadruped:LegacyFormat','Encoded branch is invalid.');
            end
        end

        function artifact = toNativeArtifact(path,problem)
            branch = lmzmodels.slip_quadruped.Results29Adapter.loadBranch(path,problem);
            artifact = branch.toArtifact();
            artifact.sourceCommitSHAs = struct('SLIP_Model_Zoo', ...
                '2c106101383ecee1b2a9d695efe09fbd72d5718a');
            artifact.diagnostics.LegacySourceSHA256 = lmz.util.FileHash.sha256(path);
        end
    end
    methods (Static, Access=private)
        function value = fieldOr(source,name,fallback)
            if isfield(source,name), value=source.(name); else, value=fallback; end
        end
    end
end
