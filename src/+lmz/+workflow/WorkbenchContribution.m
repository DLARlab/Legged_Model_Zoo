classdef WorkbenchContribution
    %WORKBENCHCONTRIBUTION Declarative model/workflow presentation metadata.
    properties (SetAccess = private)
        SchemaVersion
        Id
        Label
        ModelId
        LayoutProfileId
        CentralViews
        SidebarPanels
        AxisPresets
        ParameterFilters
        AnalysisPlugins
        DirectionLabels
        DefaultSolveOptions
        DefaultContinuationOptions
        SourcePath
        SourceHash
    end
    methods
        function obj = WorkbenchContribution(value, modelId, varargin)
            if nargin < 2, modelId = ''; end
            parser=inputParser;
            addRequired(parser,'value',@(x)isstruct(x)&&isscalar(x));
            addRequired(parser,'modelId',@ischar);
            addParameter(parser,'SourcePath','',@ischar);
            addParameter(parser,'SourceHash','',@ischar);
            parse(parser,value,modelId,varargin{:});
            if ~strcmp(fieldOr(value,'schemaVersion','1.0.0'),'1.0.0')
                error('lmz:Workflow:WorkbenchSchema', ...
                    'Unsupported workbench schema version.');
            end
            obj.SchemaVersion='1.0.0';
            obj.Id=fieldOr(value,'id','default');
            obj.Label=fieldOr(value,'label','Default workbench');
            obj.ModelId=fieldOr(value,'modelId',modelId);
            obj.LayoutProfileId=fieldOr(value,'layoutProfileId','classic_tabs');
            obj.CentralViews=textList(fieldOr(value,'centralViews', ...
                {'branch_state','run_overlay'}));
            obj.SidebarPanels=textList(fieldOr(value,'sidebarPanels', ...
                {'info_selection','visualization','solve_seeds','continuation'}));
            obj.ParameterFilters=fieldOr(value,'parameterFilters',struct());
            obj.AnalysisPlugins=textList(fieldOr(value,'analysisPlugins',{}));
            obj.DirectionLabels=fieldOr(value,'directionLabels', ...
                struct('backward','backward','forward','forward'));
            obj.DefaultSolveOptions=fieldOr(value,'defaultSolveOptions',struct());
            obj.DefaultContinuationOptions=fieldOr(value, ...
                'defaultContinuationOptions',struct());
            obj.SourcePath=parser.Results.SourcePath;
            obj.SourceHash=parser.Results.SourceHash;
            rawAxes=fieldOr(value,'axisPresets',struct([]));
            rawAxes=objectCells(rawAxes);
            obj.AxisPresets=lmz.workflow.AxisPreset.empty(0,1);
            for index=1:numel(rawAxes)
                obj.AxisPresets(index,1)=lmz.workflow.AxisPreset(rawAxes{index});
            end
            validateId(obj.Id,'workbench');
            validateId(obj.ModelId,'model');
            validateId(obj.LayoutProfileId,'layout profile');
            if ~ischar(obj.Label)||isempty(obj.Label)|| ...
                    ~isstruct(obj.ParameterFilters)|| ...
                    ~isstruct(obj.DirectionLabels)|| ...
                    ~isstruct(obj.DefaultSolveOptions)|| ...
                    ~isstruct(obj.DefaultContinuationOptions)
                error('lmz:Workflow:Workbench','Workbench metadata is invalid.');
            end
            ids=arrayfun(@(item)item.Id,obj.AxisPresets,'UniformOutput',false);
            if numel(unique(ids))~=numel(ids)
                error('lmz:Workflow:DuplicateAxisPreset', ...
                    'Axis-preset IDs must be unique within a workbench.');
            end
        end

        function preset=axisPreset(obj,id)
            ids=arrayfun(@(item)item.Id,obj.AxisPresets,'UniformOutput',false);
            index=find(strcmp(id,ids),1);
            if isempty(index)
                error('lmz:Workflow:UnknownAxisPreset', ...
                    'Unknown axis preset %s for %s.',id,obj.ModelId);
            end
            preset=obj.AxisPresets(index);
        end

        function value=hasAxisPreset(obj,id)
            ids=arrayfun(@(item)item.Id,obj.AxisPresets,'UniformOutput',false);
            value=any(strcmp(id,ids));
        end

        function value=toStruct(obj)
            axes=cell(numel(obj.AxisPresets),1);
            for index=1:numel(axes),axes{index}=obj.AxisPresets(index).toStruct();end
            value=struct('schemaVersion',obj.SchemaVersion,'id',obj.Id, ...
                'label',obj.Label,'modelId',obj.ModelId, ...
                'layoutProfileId',obj.LayoutProfileId, ...
                'centralViews',{obj.CentralViews}, ...
                'sidebarPanels',{obj.SidebarPanels}, ...
                'axisPresets',{axes},'parameterFilters',obj.ParameterFilters, ...
                'analysisPlugins',{obj.AnalysisPlugins}, ...
                'directionLabels',obj.DirectionLabels, ...
                'defaultSolveOptions',obj.DefaultSolveOptions, ...
                'defaultContinuationOptions',obj.DefaultContinuationOptions, ...
                'sourcePath',obj.SourcePath,'sourceHash',obj.SourceHash);
        end
    end
    methods (Static)
        function obj=generic(modelId)
            value=struct('schemaVersion','1.0.0','id','generic', ...
                'label','Generic model workbench','modelId',modelId, ...
                'layoutProfileId','classic_tabs','centralViews', ...
                {{'branch_state','run_overlay'}},'sidebarPanels', ...
                {{'info_selection','visualization','solve_seeds', ...
                'continuation'}},'axisPresets',struct([]));
            obj=lmz.workflow.WorkbenchContribution(value,modelId);
        end
    end
end

function values=objectCells(value)
if isempty(value),values={};elseif iscell(value),values=value(:)'; ...
elseif isstruct(value),values=num2cell(value(:)');else
    error('lmz:Workflow:Workbench','axisPresets must be an object list.');
end
end
function values=textList(value)
if isempty(value),values={};elseif ischar(value),values={value}; ...
elseif iscell(value)&&all(cellfun(@ischar,value)),values=value(:)';else
    error('lmz:Workflow:Workbench','Workbench lists must contain text.');
end
end
function validateId(value,description)
if ~ischar(value)||isempty(regexp(value,'^[a-z][a-z0-9_]*$','once'))
    error('lmz:Workflow:InvalidId','%s ID is invalid.',description);
end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
