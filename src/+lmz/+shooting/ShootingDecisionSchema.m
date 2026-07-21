classdef ShootingDecisionSchema
    %SHOOTINGDECISIONSCHEMA Named bindings for nodes, schedules, and controls.
    properties (SetAccess=private)
        VariableSchema
        Bindings
    end

    methods
        function obj=ShootingDecisionSchema(variableSchema,bindings)
            if ~isa(variableSchema,'lmz.schema.VariableSchema')
                error('lmz:Shooting:DecisionSchema', ...
                    'ShootingDecisionSchema requires a VariableSchema.');
            end
            bindings=normalizeBindings(bindings);
            if numel(bindings)~=variableSchema.count()
                error('lmz:Shooting:DecisionBindings', ...
                    'There must be exactly one binding per decision variable.');
            end
            names=variableSchema.names();
            for index=1:numel(bindings)
                if ~strcmp(bindings(index).DecisionName,names{index})
                    error('lmz:Shooting:DecisionBindingOrder', ...
                        'Decision binding order must match VariableSchema.');
                end
                validateBinding(bindings(index));
            end
            obj.VariableSchema=variableSchema;
            obj.Bindings=bindings(:);
        end

        function value=count(obj),value=obj.VariableSchema.count();end
        function value=defaults(obj),value=obj.VariableSchema.defaults();end
        function value=names(obj),value=obj.VariableSchema.names();end

        function value=decode(obj,decision,horizon)
            obj.VariableSchema.validateVector(decision);
            if ~isa(horizon,'lmz.shooting.ShootingHorizon')
                error('lmz:Shooting:DecisionHorizon', ...
                    'Decision decoding requires a ShootingHorizon.');
            end
            nodes=horizon.Nodes;schedules=cell(horizon.segmentCount(),1);
            controls=cell(horizon.segmentCount(),1);
            scheduleCoordinates=cell(horizon.segmentCount(),1);
            for index=1:horizon.segmentCount()
                schedules{index}=horizon.Segments{index}.EventSchedule;
                controls{index}=horizon.Segments{index}.ControlParameters;
                if isa(schedules{index},'lmz.schedule.EventSchedule')
                    adapter=lmz.shooting.SectionScheduleAdapter(schedules{index});
                    scheduleCoordinates{index}=adapter.encode(schedules{index});
                else
                    scheduleCoordinates{index}=[];
                end
            end
            physical=struct();target=horizon.Target;gauges=struct();
            for index=1:obj.count()
                binding=obj.Bindings(index);item=decision(index);
                switch binding.Kind
                    case 'node_coordinate'
                        node=nodes{binding.OwnerIndex};
                        local=node.StateSchema.CoordinateNames;
                        coordinateIndex=find(strcmp(binding.LocalName,local),1);
                        coordinates=node.SectionCoordinates;
                        coordinates(coordinateIndex)=item;
                        nodes{binding.OwnerIndex}=node.withCoordinates(coordinates);
                    case 'schedule_coordinate'
                        scheduleCoordinates{binding.OwnerIndex}( ...
                            binding.LocalIndex)=item;
                    case 'control'
                        controls{binding.OwnerIndex}=setPlainValue( ...
                            controls{binding.OwnerIndex},binding,item);
                    case 'physical_parameter'
                        physical.(binding.LocalName)=item;
                    case 'target'
                        target.(binding.LocalName)=item;
                    case 'gauge'
                        gauges.(binding.LocalName)=item;
                end
            end
            for index=1:horizon.segmentCount()
                if isa(schedules{index},'lmz.schedule.EventSchedule')
                    schedules{index}=lmz.shooting.SectionScheduleAdapter( ...
                        schedules{index}).decode(scheduleCoordinates{index});
                end
            end
            value=struct('RawDecision',decision(:),'Nodes',{nodes}, ...
                'Schedules',{schedules},'ScheduleCoordinates', ...
                {scheduleCoordinates},'Controls',{controls}, ...
                'PhysicalParameters',physical,'Target',target, ...
                'Gauges',gauges);
        end

        function value=toStruct(obj)
            bindings=num2cell(obj.Bindings);
            value=struct('VariableSchema',obj.VariableSchema.toStruct(), ...
                'Bindings',{bindings});
        end
    end

    methods (Static)
        function obj=fromHorizon(horizon)
            if ~isa(horizon,'lmz.shooting.ShootingHorizon')
                error('lmz:Shooting:DecisionHorizon', ...
                    'fromHorizon requires a ShootingHorizon.');
            end
            specs=lmz.schema.VariableSpec.empty(0,1);bindings=emptyBindings();
            cursor=0;
            for nodeIndex=1:horizon.nodeCount()
                node=horizon.Nodes{nodeIndex};coordinateSpecs= ...
                    node.StateSchema.coordinateSchema().Specs;
                for localIndex=1:numel(coordinateSpecs)
                    if ~node.FreeCoordinateMask(localIndex),continue,end
                    cursor=cursor+1;source=coordinateSpecs(localIndex);
                    name=sprintf('node_%d_%s',nodeIndex,source.Name);
                    specs(cursor,1)=lmz.schema.VariableSpec(name, ...
                        'Label',sprintf('Node %d %s',nodeIndex,source.Label), ...
                        'Group','interface_states','Unit',source.Unit, ...
                        'Note',source.Note,'DefaultValue', ...
                        node.SectionCoordinates(localIndex), ...
                        'LowerBound',source.LowerBound, ...
                        'UpperBound',source.UpperBound,'Scale',source.Scale, ...
                        'Topology',safeTopology(source.Topology), ...
                        'Role','derived','EnergyEffect','invariant');
                    bindings(cursor,1)=binding(name,'node_coordinate', ...
                        nodeIndex,source.Name,localIndex);
                end
            end
            for segmentIndex=1:horizon.segmentCount()
                segment=horizon.Segments{segmentIndex};
                if isa(segment.EventSchedule,'lmz.schedule.EventSchedule')
                    scheduleSchema=lmz.shooting.SectionScheduleAdapter( ...
                        segment.EventSchedule).schema();
                    for localIndex=1:scheduleSchema.count()
                        cursor=cursor+1;source=scheduleSchema.Specs(localIndex);
                        name=sprintf('segment_%d_schedule_%d', ...
                            segmentIndex,localIndex);
                        specs(cursor,1)=lmz.schema.VariableSpec(name, ...
                            'Label',sprintf('Segment %d schedule %d', ...
                            segmentIndex,localIndex), ...
                            'Group','event_schedules','DefaultValue', ...
                            source.DefaultValue,'Scale',source.Scale, ...
                            'Role','schedule','EnergyEffect','invariant');
                        bindings(cursor,1)=binding(name, ...
                            'schedule_coordinate',segmentIndex, ...
                            source.Name,localIndex);
                    end
                end
                controls=segment.ControlParameters;
                if isnumeric(controls)
                    for localIndex=1:numel(controls)
                        cursor=cursor+1;
                        name=sprintf('segment_%d_control_%d', ...
                            segmentIndex,localIndex);
                        specs(cursor,1)=lmz.schema.VariableSpec(name, ...
                            'Label',sprintf('Segment %d control %d', ...
                            segmentIndex,localIndex), ...
                            'Group','controls','DefaultValue',controls(localIndex), ...
                            'Scale',max(1,abs(controls(localIndex))), ...
                            'Role','control','EnergyEffect','unknown');
                        bindings(cursor,1)=binding(name,'control', ...
                            segmentIndex,'',localIndex);
                    end
                end
            end
            obj=lmz.shooting.ShootingDecisionSchema( ...
                lmz.schema.VariableSchema(specs,'1.0.0'),bindings);
        end

        function obj=fromStruct(value)
            if ~isstruct(value)||~isfield(value,'VariableSchema')|| ...
                    ~isfield(value,'Bindings')
                error('lmz:Shooting:DecisionSchemaStruct', ...
                    'Stored shooting decision schema is incomplete.');
            end
            obj=lmz.shooting.ShootingDecisionSchema( ...
                lmz.schema.VariableSchema.fromStruct(value.VariableSchema), ...
                value.Bindings);
        end
    end
end

function values=normalizeBindings(source)
if isempty(source),values=emptyBindings();return,end
if iscell(source),source=[source{:}];end
if ~isstruct(source),error('lmz:Shooting:DecisionBindings', ...
        'Decision bindings must be structs.');end
values=source(:);
end
function value=emptyBindings()
value=struct('DecisionName',{},'Kind',{},'OwnerIndex',{}, ...
    'LocalName',{},'LocalIndex',{});
end
function value=binding(name,kind,owner,localName,localIndex)
value=struct('DecisionName',name,'Kind',kind,'OwnerIndex',owner, ...
    'LocalName',localName,'LocalIndex',localIndex);
end
function validateBinding(value)
required={'DecisionName','Kind','OwnerIndex','LocalName','LocalIndex'};
kinds={'node_coordinate','schedule_coordinate','control', ...
    'physical_parameter','target','gauge'};
if ~all(isfield(value,required))||~ischar(value.DecisionName)|| ...
        ~any(strcmp(value.Kind,kinds))||~ischar(value.LocalName)|| ...
        ~isnumeric(value.OwnerIndex)||~isscalar(value.OwnerIndex)|| ...
        value.OwnerIndex<0||value.OwnerIndex~=fix(value.OwnerIndex)|| ...
        ~isnumeric(value.LocalIndex)||~isscalar(value.LocalIndex)|| ...
        value.LocalIndex<0||value.LocalIndex~=fix(value.LocalIndex)
    error('lmz:Shooting:DecisionBinding','A decision binding is invalid.');
end
if strcmp(value.Kind,'node_coordinate')&&isempty(value.LocalName)
    error('lmz:Shooting:DecisionBinding', ...
        'Node-coordinate bindings require a local name.');
end
end
function value=setPlainValue(source,binding,item)
if isnumeric(source)
    value=source;value(binding.LocalIndex)=item;
elseif isstruct(source)&&~isempty(binding.LocalName)
    value=source;value.(binding.LocalName)=item;
else
    error('lmz:Shooting:ControlBinding', ...
        'Control binding does not match the segment control representation.');
end
end
function value=safeTopology(source)
if any(strcmp(source,{'euclidean','positive','bounded'})),value=source;else,value='euclidean';end
end
