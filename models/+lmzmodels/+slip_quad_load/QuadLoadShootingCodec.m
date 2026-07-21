classdef QuadLoadShootingCodec < lmz.shooting.SectionDecisionCodec
    %QUADLOADSHOOTINGCODEC Named apex-node, schedule, and control bindings.
    properties (SetAccess=private)
        Horizon
        ShootingSchema
        DecisionSchema
        FreeControlMask
        FreeNodeMask
    end

    methods
        function obj=QuadLoadShootingCodec(horizon,configuration)
            if nargin<2,configuration=struct();end
            if ~isa(horizon,'lmz.shooting.ShootingHorizon')|| ...
                    ~strcmp(horizon.ModelId,'slip_quad_load')
                error('lmz:QuadLoad:ShootingCodecHorizon', ...
                    'QuadLoadShootingCodec requires a quad-load horizon.');
            end
            controlMask=controlMaskFor(configuration,horizon.segmentCount());
            nodeMask=nodeMaskFor(configuration,horizon);
            [schema,shooting]=createSchema(horizon,nodeMask,controlMask,configuration);
            obj.Horizon=horizon;obj.ShootingSchema=shooting;
            obj.DecisionSchema=schema;obj.FreeControlMask=controlMask;
            obj.FreeNodeMask=nodeMask;
        end

        function value=decisionSchema(obj,varargin)
            value=obj.DecisionSchema;
        end

        function value=encode(obj,varargin)
            value=obj.ShootingSchema.defaults();
        end

        function value=decode(obj,decision,horizon)
            if nargin<3||isempty(horizon),horizon=obj.Horizon;end
            value=obj.ShootingSchema.decode(decision,horizon);
        end

        function value=decisionDefaults(obj),value=obj.ShootingSchema.defaults();end
        function value=unknownCount(obj),value=obj.DecisionSchema.count();end

        function value=toStruct(obj)
            value=struct('Class',class(obj),'Version','1.0.0', ...
                'SegmentCount',obj.Horizon.segmentCount(), ...
                'NodeCount',obj.Horizon.nodeCount(), ...
                'UnknownCount',obj.unknownCount(), ...
                'FreeControlMask',obj.FreeControlMask, ...
                'FreeNodeMask',obj.FreeNodeMask, ...
                'ShootingSchema',obj.ShootingSchema.toStruct());
        end
    end
end

function [schema,shooting]=createSchema(horizon,nodeMask,controlMask,configuration)
specs=lmz.schema.VariableSpec.empty(0,1);bindings=emptyBindings();cursor=0;
for nodeIndex=1:horizon.nodeCount()
    node=horizon.Nodes{nodeIndex};coordinates=node.SectionCoordinates;
    names=node.StateSchema.CoordinateNames;coordinateSchema= ...
        node.StateSchema.coordinateSchema();
    for localIndex=1:numel(names)
        if ~nodeMask(nodeIndex,localIndex),continue,end
        cursor=cursor+1;source=coordinateSchema.Specs(localIndex);
        decisionName=sprintf('node_%d_%s',nodeIndex,names{localIndex});
        [lower,upper,topology]=nodeBounds(configuration, ...
            coordinates(localIndex),names{localIndex});
        specs(cursor,1)=lmz.schema.VariableSpec(decisionName, ...
            'Label',sprintf('Node %d %s',nodeIndex,source.Label), ...
            'Group','interface_states','Unit',source.Unit, ...
            'DefaultValue',coordinates(localIndex), ...
            'LowerBound',lower,'UpperBound',upper, ...
            'Topology',topology, ...
            'Scale',max(1,abs(coordinates(localIndex))), ...
            'Role','derived','EnergyEffect','invariant');
        bindings(cursor,1)=binding(decisionName,'node_coordinate', ...
            nodeIndex,names{localIndex},localIndex);
    end
end
for segmentIndex=1:horizon.segmentCount()
    schedule=horizon.Segments{segmentIndex}.EventSchedule;
    chart=lmz.schedule.EventScheduleChart(schedule);
    scheduleSchema=chart.DecisionSchema;
    for localIndex=1:scheduleSchema.count()
        cursor=cursor+1;source=scheduleSchema.Specs(localIndex);
        decisionName=sprintf('segment_%d_schedule_q_%d', ...
            segmentIndex,localIndex);
        radius=fieldOr(configuration,'ScheduleCoordinateRadius',Inf);
        lower=-Inf;upper=Inf;topology='euclidean';
        if isfinite(radius)
            if ~isscalar(radius)||radius<=0
                error('lmz:QuadLoad:ShootingScheduleBounds', ...
                    'ScheduleCoordinateRadius must be positive.');
            end
            lower=source.DefaultValue-radius;upper=source.DefaultValue+radius;
            topology='bounded';
        end
        specs(cursor,1)=lmz.schema.VariableSpec(decisionName, ...
            'Label',sprintf('Segment %d schedule coordinate %d', ...
            segmentIndex,localIndex),'Group','event_schedules', ...
            'DefaultValue',source.DefaultValue, ...
            'LowerBound',lower,'UpperBound',upper,'Topology',topology, ...
            'Scale',max(1,abs(source.DefaultValue)), ...
            'Role','schedule','EnergyEffect','invariant');
        bindings(cursor,1)=binding(decisionName,'schedule_coordinate', ...
            segmentIndex,source.Name,localIndex);
    end
    controls=horizon.Segments{segmentIndex}.ControlParameters(:);
    unbounded=logical(fieldOr(configuration,'UnboundedControls',false));
    if unbounded
        lower=-Inf(size(controls));upper=Inf(size(controls));
    else
        lower=controlBound(configuration,'ControlLowerBound',0, ...
            segmentIndex,numel(controls));
        fallback=max(100,2*abs(controls)+10);
        upper=controlBound(configuration,'ControlUpperBound',fallback, ...
            segmentIndex,numel(controls));
    end
    for localIndex=1:numel(controls)
        if ~controlMask(segmentIndex,localIndex),continue,end
        cursor=cursor+1;
        decisionName=sprintf('segment_%d_post_swing_%d', ...
            segmentIndex,localIndex);
        topology='bounded';
        if unbounded,topology='euclidean';end
        specs(cursor,1)=lmz.schema.VariableSpec(decisionName, ...
            'Label',sprintf('Segment %d post-swing stiffness %d', ...
            segmentIndex,localIndex),'Group','controls', ...
            'DefaultValue',controls(localIndex), ...
            'LowerBound',lower(localIndex), ...
            'UpperBound',upper(localIndex), ...
            'Scale',max(1,abs(controls(localIndex))), ...
            'Topology',topology,'Role','control', ...
            'EnergyEffect','state_dependent');
        bindings(cursor,1)=binding(decisionName,'control', ...
            segmentIndex,'',localIndex);
    end
end
schema=lmz.schema.VariableSchema(specs,'1.0.0');
shooting=lmz.shooting.ShootingDecisionSchema(schema,bindings);
end

function [lower,upper,topology]=nodeBounds(configuration,defaultValue,~)
radius=fieldOr(configuration,'NodeTrustRadius',Inf);
lower=-Inf;upper=Inf;topology='euclidean';
if isfinite(radius)
    if ~isscalar(radius)||radius<=0
        error('lmz:QuadLoad:ShootingNodeBounds', ...
            'NodeTrustRadius must be positive.');
    end
    width=radius*max(1,abs(defaultValue));
    lower=defaultValue-width;upper=defaultValue+width;topology='bounded';
end
end

function value=controlMaskFor(configuration,count)
source=fieldOr(configuration,'FreeControlMask',false(count,4));
if islogical(source)&&isscalar(source),source=repmat(source,count,4);end
if ~islogical(source)||~isequal(size(source),[count 4])
    error('lmz:QuadLoad:ShootingControlMask', ...
        'FreeControlMask must be NumberOfStrides-by-4 logical data.');
end
value=source;
end

function value=nodeMaskFor(configuration,horizon)
count=horizon.nodeCount();width=horizon.Nodes{1}.StateSchema.count();
source=fieldOr(configuration,'FreeNodeMask',[]);
if isempty(source)
    value=true(count,width);value(1,:)=false;return
end
if islogical(source)&&isscalar(source),source=repmat(source,count,width);end
if ~islogical(source)||~isequal(size(source),[count width])
    error('lmz:QuadLoad:ShootingNodeMask', ...
        'FreeNodeMask must be NumberOfNodes-by-%d logical data.',width);
end
value=source;
end

function value=controlBound(configuration,name,fallback,stride,count)
source=fieldOr(configuration,name,fallback);
if isscalar(source)
    value=repmat(source,count,1);
elseif isvector(source)&&numel(source)==count
    value=source(:);
elseif isnumeric(source)&&size(source,1)>=stride&&size(source,2)==count
    value=source(stride,:).';
else
    error('lmz:QuadLoad:ShootingControlBounds', ...
        '%s does not match the control layout.',name);
end
if any(~isfinite(value))
    error('lmz:QuadLoad:ShootingControlBounds', ...
        '%s must contain finite bounds.',name);
end
end

function value=emptyBindings()
value=struct('DecisionName',{},'Kind',{},'OwnerIndex',{}, ...
    'LocalName',{},'LocalIndex',{});
end

function value=binding(name,kind,owner,localName,localIndex)
value=struct('DecisionName',name,'Kind',kind,'OwnerIndex',owner, ...
    'LocalName',localName,'LocalIndex',localIndex);
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
