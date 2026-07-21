classdef ShootingSegment
    %SHOOTINGSEGMENT One direct propagation between section nodes.
    properties (SetAccess=private)
        Index
        StartNode
        StopNode
        EventSchedule
        ContactConstraints
        PhysicalParameters
        ControlParameters
        EnergyWorkSpecification
        SimulationOptions
        SourceLineage
    end

    methods
        function obj=ShootingSegment(varargin)
            parser=inputParser;
            addParameter(parser,'Index',1,@isPositiveInteger);
            addParameter(parser,'StartNode',[],@isNode);
            addParameter(parser,'StopNode',[],@isNode);
            addParameter(parser,'EventSchedule',struct(),@isSchedule);
            addParameter(parser,'ContactConstraints',{},@isNameList);
            addParameter(parser,'PhysicalParameters',struct(),@isPlainData);
            addParameter(parser,'ControlParameters',struct(),@isPlainData);
            addParameter(parser,'EnergyWorkSpecification', ...
                struct('Mode','energy_neutral','DeclaredWork',0, ...
                'Tolerance',1e-8),@isstruct);
            addParameter(parser,'SimulationOptions',struct(),@isstruct);
            addParameter(parser,'SourceLineage',struct(),@isstruct);
            parse(parser,varargin{:});value=parser.Results;
            if isempty(value.StartNode)||isempty(value.StopNode)
                error('lmz:Shooting:SegmentNodes', ...
                    'A shooting segment requires start and stop nodes.');
            end
            validatePlain(value.PhysicalParameters,'physical parameters');
            validatePlain(value.ControlParameters,'control parameters');
            validateEnergy(value.EnergyWorkSpecification);
            obj.Index=value.Index;obj.StartNode=value.StartNode;
            obj.StopNode=value.StopNode;obj.EventSchedule=value.EventSchedule;
            obj.ContactConstraints=reshape(value.ContactConstraints,[],1);
            obj.PhysicalParameters=value.PhysicalParameters;
            obj.ControlParameters=value.ControlParameters;
            obj.EnergyWorkSpecification=value.EnergyWorkSpecification;
            obj.SimulationOptions=value.SimulationOptions;
            obj.SourceLineage=value.SourceLineage;
        end

        function value=withNodes(obj,startNode,stopNode)
            if ~isNode(startNode)||~isNode(stopNode)
                error('lmz:Shooting:SegmentNodes','Segment nodes are invalid.');
            end
            value=obj;value.StartNode=startNode;value.StopNode=stopNode;
        end

        function value=toStruct(obj)
            schedule=obj.EventSchedule;
            if isobject(schedule)&&ismethod(schedule,'toStruct')
                schedule=schedule.toStruct();
            end
            value=struct('Index',obj.Index, ...
                'StartNode',obj.StartNode.toStruct(), ...
                'StopNode',obj.StopNode.toStruct(), ...
                'EventSchedule',schedule, ...
                'ContactConstraints',{obj.ContactConstraints}, ...
                'PhysicalParameters',obj.PhysicalParameters, ...
                'ControlParameters',obj.ControlParameters, ...
                'EnergyWorkSpecification',obj.EnergyWorkSpecification, ...
                'SimulationOptions',obj.SimulationOptions, ...
                'SourceLineage',obj.SourceLineage);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            required={'Index','StartNode','StopNode','EventSchedule', ...
                'ContactConstraints','PhysicalParameters', ...
                'ControlParameters','EnergyWorkSpecification', ...
                'SimulationOptions','SourceLineage'};
            if ~isstruct(value)||~isscalar(value)|| ...
                    ~all(isfield(value,required))
                error('lmz:Shooting:SegmentStruct', ...
                    'Stored shooting segment is incomplete.');
            end
            schedule=value.EventSchedule;
            if isstruct(schedule)&&isfield(schedule,'Occurrences')&& ...
                    isfield(schedule,'ReturnTime')
                schedule=lmz.schedule.EventSchedule.fromStruct(schedule);
            end
            constraints=value.ContactConstraints;
            if ischar(constraints),constraints={constraints};end
            obj=lmz.shooting.ShootingSegment('Index',value.Index, ...
                'StartNode',lmz.shooting.ShootingNode.fromStruct( ...
                value.StartNode),'StopNode', ...
                lmz.shooting.ShootingNode.fromStruct(value.StopNode), ...
                'EventSchedule',schedule, ...
                'ContactConstraints',constraints, ...
                'PhysicalParameters',value.PhysicalParameters, ...
                'ControlParameters',value.ControlParameters, ...
                'EnergyWorkSpecification',value.EnergyWorkSpecification, ...
                'SimulationOptions',value.SimulationOptions, ...
                'SourceLineage',value.SourceLineage);
        end
    end
end

function value=isPositiveInteger(source)
value=isnumeric(source)&&isscalar(source)&&isfinite(source)&& ...
    source>=1&&source==fix(source);
end
function value=isNode(source)
value=isa(source,'lmz.shooting.ShootingNode')&&isscalar(source);
end
function value=isSchedule(source)
value=isstruct(source)||isa(source,'lmz.schedule.EventSchedule');
end
function value=isNameList(source)
value=isempty(source)||(iscell(source)&&all(cellfun(@ischar,source)));
end
function value=isPlainData(source)
value=isnumeric(source)||islogical(source)||isstruct(source)||isempty(source);
end
function validatePlain(source,label)
if isa(source,'function_handle')
    error('lmz:Shooting:ExecutableData','%s cannot be executable.',label);
elseif isnumeric(source)&&(~isreal(source)||any(~isfinite(source(:))))
    error('lmz:Shooting:SegmentData','%s must be finite real data.',label);
elseif isstruct(source)
    names=fieldnames(source);
    for item=1:numel(source)
        for index=1:numel(names),validatePlain(source(item).(names{index}),label);end
    end
end
end
function validateEnergy(source)
required={'Mode','DeclaredWork','Tolerance'};
if ~all(isfield(source,required))|| ...
        ~any(strcmp(source.Mode,{'energy_neutral','bounded_work', ...
        'prescribed_work','diagnostic_only'}))|| ...
        ~isnumeric(source.DeclaredWork)||any(~isfinite(source.DeclaredWork(:)))|| ...
        ~isnumeric(source.Tolerance)||~isscalar(source.Tolerance)|| ...
        ~isfinite(source.Tolerance)||source.Tolerance<0
    error('lmz:Shooting:EnergySpecification', ...
        'Segment energy/work specification is invalid.');
end
end
