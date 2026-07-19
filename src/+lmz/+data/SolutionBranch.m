classdef SolutionBranch
    %SOLUTIONBRANCH Schema-aware branch with lossless per-point metadata.
    properties (SetAccess=private)
        Id; ModelId; ProblemId; DecisionSchema; ParameterSchema
        DecisionValues; ParameterValues; PointMetadata; Observables
        Classifications; Arclength; Tangents; Lineage; Diagnostics; Provenance
    end
    methods
        function obj = SolutionBranch(value)
            value = lmz.data.SolutionBranch.normalize(value);
            names = properties(obj);
            for index = 1:numel(names), obj.(names{index}) = value.(names{index}); end
            obj.validate();
        end
        function value = pointCount(obj), value = size(obj.DecisionValues,2); end
        function solution = point(obj,index)
            if index < 1 || index > obj.pointCount() || index ~= fix(index)
                error('lmz:Branch:PointIndex','Point index is out of range.');
            end
            metadata = obj.PointMetadata(index);
            provenance = obj.Provenance;
            provenance.PointSource = metadata.Source;
            value = struct('Id',metadata.Id,'ModelId',obj.ModelId, ...
                'ModelVersion',metadata.ModelVersion,'ProblemId',obj.ProblemId, ...
                'ProblemVersion',metadata.ProblemVersion, ...
                'DecisionSchema',obj.DecisionSchema,'ParameterSchema',obj.ParameterSchema, ...
                'DecisionValues',obj.DecisionValues(:,index), ...
                'ParameterValues',obj.ParameterValues(:,index), ...
                'Observables',obj.Observables{index}, ...
                'ResidualBlocks',lmz.data.SolutionBranch.decodeBlocks(metadata.ResidualBlocks), ...
                'Diagnostics',metadata.Diagnostics, ...
                'Classification',obj.Classifications{index}, ...
                'Feasibility',metadata.Feasibility,'Lineage',obj.Lineage, ...
                'Provenance',provenance,'CreatedAt',metadata.CreatedAt);
            solution = lmz.data.Solution(value);
        end
        function obj = append(obj,solution,metadata)
            if nargin < 3, metadata = struct(); end
            obj.assertCompatible(solution);
            obj.DecisionValues(:,end+1) = solution.DecisionValues;
            obj.ParameterValues(:,end+1) = solution.ParameterValues;
            obj.PointMetadata(end+1) = lmz.data.SolutionBranch.completeMetadata(metadata,solution);
            obj.Observables{end+1} = solution.Observables;
            obj.Classifications{end+1} = solution.Classification;
            if isempty(obj.Arclength)
                obj.Arclength = 0;
            else
                delta = lmz.schema.VariableChart(obj.DecisionSchema).difference( ...
                    solution.DecisionValues,obj.DecisionValues(:,end-1));
                distance = lmz.schema.DiagonalMetric(obj.scale()).norm(delta);
                obj.Arclength(end+1) = obj.Arclength(end)+distance;
            end
            obj.validate();
        end
        function obj = replacePoint(obj,index,solution)
            obj.assertCompatible(solution);
            obj.DecisionValues(:,index) = solution.DecisionValues;
            obj.ParameterValues(:,index) = solution.ParameterValues;
            obj.PointMetadata(index) = lmz.data.SolutionBranch.completeMetadata(struct(),solution);
            obj.Observables{index} = solution.Observables;
            obj.Classifications{index} = solution.Classification;
            obj.Arclength = obj.computeArclength();
            obj.validate();
        end
        function value = subset(obj,indices)
            data = obj.raw();
            data.DecisionValues = data.DecisionValues(:,indices);
            data.ParameterValues = data.ParameterValues(:,indices);
            data.PointMetadata = data.PointMetadata(indices);
            data.Observables = data.Observables(indices);
            data.Classifications = data.Classifications(indices);
            data.Arclength = data.Arclength(indices);
            if ~isempty(data.Tangents), data.Tangents = data.Tangents(:,indices); end
            value = lmz.data.SolutionBranch(data);
        end
        function value = reverse(obj), value = obj.subset(obj.pointCount():-1:1); end
        function value = decision(obj,name)
            value = obj.DecisionValues(obj.DecisionSchema.indexOf(name),:);
        end
        function value = parameter(obj,name)
            value = obj.ParameterValues(obj.ParameterSchema.indexOf(name),:);
        end
        function value = observable(obj,name)
            value = obj.collectObservable(name);
        end
        function names = coordinateNames(obj)
            decisionNames=obj.DecisionSchema.names();parameterNames=obj.ParameterSchema.names();
            names = [reshape(decisionNames,1,[]),reshape(parameterNames,1,[])];
            if ~isempty(obj.Observables)
                candidates = fieldnames(obj.Observables{1});
                for index = 1:numel(candidates)
                    try
                        values = obj.collectObservable(candidates{index});
                        if isnumeric(values) && isvector(values) && numel(values)==obj.pointCount()
                            names{end+1} = candidates{index}; %#ok<AGROW>
                        end
                    catch
                    end
                end
            end
        end
        function value = coordinate(obj,name)
            if any(strcmp(name,obj.DecisionSchema.names()))
                value = obj.decision(name);
            elseif any(strcmp(name,obj.ParameterSchema.names()))
                value = obj.parameter(name);
            else
                value = obj.observable(name);
            end
        end
        function index = nearestPoint(obj,coordinates,target)
            if ischar(coordinates), coordinates = {coordinates}; end
            if numel(target) ~= numel(coordinates)
                error('lmz:Branch:NearestDimension','Target dimension does not match coordinates.');
            end
            distanceSquared = zeros(1,obj.pointCount());
            for k = 1:numel(coordinates)
                values = obj.coordinate(coordinates{k});
                scale = obj.coordinateScale(coordinates{k},values);
                difference = values-target(k);
                if any(strcmp(coordinates{k},obj.DecisionSchema.names()))
                    spec = obj.DecisionSchema.Specs(obj.DecisionSchema.indexOf(coordinates{k}));
                    if strcmp(spec.Topology,'cyclic_time')
                        periods = obj.decision(spec.PeriodSource);
                        difference = mod(difference+periods/2,periods)-periods/2;
                    end
                end
                distanceSquared = distanceSquared+(difference./scale).^2;
            end
            [~,index] = min(distanceSquared);
        end
        function value = concatenate(obj,other)
            if ~strcmp(obj.ModelId,other.ModelId) || ~strcmp(obj.ProblemId,other.ProblemId) || ...
                    ~isequal(obj.DecisionSchema.names(),other.DecisionSchema.names()) || ...
                    ~isequal(obj.ParameterSchema.names(),other.ParameterSchema.names())
                error('lmz:Branch:IncompatibleBranch','Branches are incompatible.');
            end
            data = obj.raw();
            data.Id = lmz.util.Ids.new('branch');
            data.DecisionValues = [obj.DecisionValues,other.DecisionValues];
            data.ParameterValues = [obj.ParameterValues,other.ParameterValues];
            data.PointMetadata = [obj.PointMetadata,other.PointMetadata];
            data.Observables = [obj.Observables,other.Observables];
            data.Classifications = [obj.Classifications,other.Classifications];
            data.Tangents = [];
            data.Lineage = struct('Parents',{{obj.Id,other.Id}}, ...
                'Operation','concatenate');
            data.Arclength = zeros(1,size(data.DecisionValues,2));
            value = lmz.data.SolutionBranch(data);
            data = value.raw(); data.Arclength = value.computeArclength();
            value = lmz.data.SolutionBranch(data);
        end
        function validate(obj)
            n = obj.pointCount();
            if size(obj.DecisionValues,1) ~= obj.DecisionSchema.count() || ...
                    size(obj.ParameterValues,1) ~= obj.ParameterSchema.count() || ...
                    size(obj.ParameterValues,2) ~= n
                error('lmz:Branch:DimensionMismatch', ...
                    'Branch matrices do not match schemas/points.');
            end
            if any(~isfinite(obj.DecisionValues(:))) || ...
                    any(~isfinite(obj.ParameterValues(:))) || ...
                    numel(obj.PointMetadata) ~= n || numel(obj.Observables) ~= n || ...
                    numel(obj.Classifications) ~= n || numel(obj.Arclength) ~= n
                error('lmz:Branch:InvalidValues','Branch values or metadata are invalid.');
            end
            if ~iscell(obj.Observables) || ~iscell(obj.Classifications) || ...
                    ~all(cellfun(@isstruct,obj.Observables)) || ...
                    ~all(cellfun(@isstruct,obj.Classifications))
                error('lmz:Branch:InvalidPointData','Per-point data must be struct cells.');
            end
        end
        function value = toStruct(obj)
            value = obj.raw();
            value.DecisionSchema = obj.DecisionSchema.toStruct();
            value.ParameterSchema = obj.ParameterSchema.toStruct();
        end
        function artifact = toArtifact(obj)
            if obj.pointCount() < 1, error('lmz:Branch:EmptyArtifact','Cannot save an empty branch.'); end
            artifact = obj.point(1).toArtifact();
            artifact.artifactType = 'branch';
            artifact.decisionValues = obj.DecisionValues;
            artifact.parameterValues = obj.ParameterValues;
            artifact.branch = obj.toStruct();
            artifact.codeVersion = 'round6';
        end
    end
    methods (Static)
        function obj = fromSolutions(solutions)
            first = solutions(1); n = numel(solutions);
            decision = zeros(first.DecisionSchema.count(),n);
            parameters = zeros(first.ParameterSchema.count(),n);
            metadata = repmat(lmz.data.SolutionBranch.emptyMetadata(),1,n);
            observables = cell(1,n); classifications = cell(1,n);
            for index = 1:n
                decision(:,index) = solutions(index).DecisionValues;
                parameters(:,index) = solutions(index).ParameterValues;
                metadata(index) = lmz.data.SolutionBranch.completeMetadata(struct(),solutions(index));
                observables{index} = solutions(index).Observables;
                classifications{index} = solutions(index).Classification;
            end
            data = struct('Id',lmz.util.Ids.new('branch'),'ModelId',first.ModelId, ...
                'ProblemId',first.ProblemId,'DecisionSchema',first.DecisionSchema, ...
                'ParameterSchema',first.ParameterSchema,'DecisionValues',decision, ...
                'ParameterValues',parameters,'PointMetadata',metadata, ...
                'Observables',{observables},'Classifications',{classifications}, ...
                'Arclength',zeros(1,n),'Tangents',[],'Lineage',struct(), ...
                'Diagnostics',struct(),'Provenance',struct('source','native'));
            obj = lmz.data.SolutionBranch(data);
            data = obj.raw(); data.Arclength = obj.computeArclength();
            obj = lmz.data.SolutionBranch(data);
        end
        function obj = fromStruct(value)
            if isstruct(value.DecisionSchema), value.DecisionSchema=lmz.schema.VariableSchema.fromStruct(value.DecisionSchema); end
            if isstruct(value.ParameterSchema), value.ParameterSchema=lmz.schema.VariableSchema.fromStruct(value.ParameterSchema); end
            obj = lmz.data.SolutionBranch(value);
        end
        function obj = fromArtifact(artifact), obj = lmz.data.SolutionBranch.fromStruct(artifact.branch); end
    end
    methods (Access=private)
        function assertCompatible(obj,solution)
            if ~strcmp(solution.ModelId,obj.ModelId) || ...
                    ~strcmp(solution.ProblemId,obj.ProblemId) || ...
                    ~isequal(solution.DecisionSchema.names(),obj.DecisionSchema.names()) || ...
                    ~isequal(solution.ParameterSchema.names(),obj.ParameterSchema.names())
                error('lmz:Branch:IncompatibleSolution','Solution is incompatible with branch.');
            end
        end
        function value = scale(obj)
            value = arrayfun(@(s)s.Scale,obj.DecisionSchema.Specs(:));
        end
        function value = raw(obj)
            value = struct(); names = properties(obj);
            for index = 1:numel(names), value.(names{index})=obj.(names{index}); end
        end
        function arc = computeArclength(obj)
            n = obj.pointCount(); arc = zeros(1,n);
            metric = lmz.schema.DiagonalMetric(obj.scale());
            chart = lmz.schema.VariableChart(obj.DecisionSchema);
            for index = 2:n
                arc(index) = arc(index-1)+metric.norm(chart.difference( ...
                    obj.DecisionValues(:,index),obj.DecisionValues(:,index-1)));
            end
        end
        function value = collectObservable(obj,name)
            value = cell(1,obj.pointCount());
            for index = 1:obj.pointCount()
                if ~isfield(obj.Observables{index},name)
                    error('lmz:Branch:UnknownObservable','Unknown observable: %s',name);
                end
                value{index} = obj.Observables{index}.(name);
            end
            if all(cellfun(@(x)isnumeric(x)&&isscalar(x),value))
                value = cell2mat(value);
            end
        end
        function scale = coordinateScale(obj,name,values)
            if any(strcmp(name,obj.DecisionSchema.names()))
                scale = obj.DecisionSchema.Specs(obj.DecisionSchema.indexOf(name)).Scale;
            elseif any(strcmp(name,obj.ParameterSchema.names()))
                scale = obj.ParameterSchema.Specs(obj.ParameterSchema.indexOf(name)).Scale;
            else
                finiteValues = values(isfinite(values));
                if isempty(finiteValues), scale = 1; else, scale = max(max(finiteValues)-min(finiteValues),1e-12); end
            end
        end
    end
    methods (Static, Access=private)
        function value = normalize(value)
            required = {'Id','ModelId','ProblemId','DecisionSchema','ParameterSchema', ...
                'DecisionValues','ParameterValues','PointMetadata'};
            for index = 1:numel(required)
                if ~isfield(value,required{index}), error('lmz:Branch:MissingField','Missing branch field %s.',required{index}); end
            end
            n = size(value.DecisionValues,2);
            if ~isfield(value,'Observables') || isempty(value.Observables)
                value.Observables = repmat({struct()},1,n);
            elseif isstruct(value.Observables) && isscalar(value.Observables)
                old = value.Observables; value.Observables = repmat({struct()},1,n);
                fields = fieldnames(old);
                for k = 1:numel(fields)
                    data = old.(fields{k});
                    if isnumeric(data) && size(data,2)==n
                        for j=1:n, value.Observables{j}.(fields{k})=data(:,j); end
                    end
                end
            end
            value.Observables = reshape(value.Observables,1,[]);
            if ~isfield(value,'Classifications') || isempty(value.Classifications)
                value.Classifications = repmat({struct()},1,n);
            elseif isstruct(value.Classifications)
                value.Classifications = num2cell(reshape(value.Classifications,1,[]));
            end
            value.Classifications = reshape(value.Classifications,1,[]);
            oldMetadata = value.PointMetadata;
            metadata = repmat(lmz.data.SolutionBranch.emptyMetadata(),1,n);
            for index = 1:n
                source = oldMetadata(index); template = metadata(index);
                names = fieldnames(template);
                for k = 1:numel(names)
                    if isfield(source,names{k}), template.(names{k})=source.(names{k}); end
                end
                metadata(index)=template;
            end
            value.PointMetadata = metadata;
            defaults = struct('Arclength',zeros(1,n),'Tangents',[], ...
                'Lineage',struct(),'Diagnostics',struct(),'Provenance',struct());
            names = fieldnames(defaults);
            for index = 1:numel(names)
                if ~isfield(value,names{index}) || isempty(value.(names{index}))
                    value.(names{index}) = defaults.(names{index});
                end
            end
            value.Arclength = reshape(value.Arclength,1,[]);
        end
        function metadata = emptyMetadata()
            metadata = struct('Id','','ModelVersion','1.0.0', ...
                'ProblemVersion','1.0.0','CreatedAt',datestr(now,30), ...
                'ResidualBlocks',{{}},'Diagnostics',struct(), ...
                'Feasibility',struct('Valid',true),'Source',struct(), ...
                'Provenance',struct());
        end
        function metadata = completeMetadata(metadata,solution)
            complete = lmz.data.SolutionBranch.emptyMetadata();
            names = fieldnames(complete);
            for index=1:numel(names)
                if isfield(metadata,names{index}), complete.(names{index})=metadata.(names{index}); end
            end
            complete.Id=solution.Id; complete.ModelVersion=solution.ModelVersion;
            complete.ProblemVersion=solution.ProblemVersion; complete.CreatedAt=solution.CreatedAt;
            blocks=cell(numel(solution.ResidualBlocks),1);
            for index=1:numel(blocks), blocks{index}=solution.ResidualBlocks(index).toStruct(); end
            complete.ResidualBlocks=blocks; complete.Diagnostics=solution.Diagnostics;
            complete.Feasibility=solution.Feasibility; complete.Provenance=solution.Provenance;
            metadata=complete;
        end
        function blocks = decodeBlocks(values)
            blocks = lmz.data.ResidualBlock.empty(0,1);
            if isempty(values), return, end
            if isa(values,'lmz.data.ResidualBlock'), blocks=values; return, end
            for index=1:numel(values)
                item=values{index}; blocks(index,1)=lmz.data.ResidualBlock(item.Name,item.Values,item.Scale); %#ok<AGROW>
            end
        end
    end
end
