classdef ShootingHorizon
    %SHOOTINGHORIZON Ordered nodes and direct-propagation segments.
    properties (SetAccess=private)
        ModelId
        ProblemId
        Nodes
        Segments
        Formulation
        Target
        Lineage
    end

    methods
        function obj=ShootingHorizon(varargin)
            parser=inputParser;
            addParameter(parser,'ModelId','',@ischar);
            addParameter(parser,'ProblemId','multiple_shooting',@ischar);
            addParameter(parser,'Nodes',{},@iscell);
            addParameter(parser,'Segments',{},@iscell);
            addParameter(parser,'Formulation','periodic',@isFormulation);
            addParameter(parser,'Target',struct(),@isstruct);
            addParameter(parser,'Lineage',struct(),@isstruct);
            parse(parser,varargin{:});value=parser.Results;
            obj.ModelId=value.ModelId;obj.ProblemId=value.ProblemId;
            obj.Nodes=reshape(value.Nodes,[],1);
            obj.Segments=reshape(value.Segments,[],1);
            obj.Formulation=value.Formulation;obj.Target=value.Target;
            obj.Lineage=value.Lineage;obj.validate();
        end

        function value=segmentCount(obj),value=numel(obj.Segments);end
        function value=nodeCount(obj),value=numel(obj.Nodes);end

        function report=validate(obj)
            count=obj.segmentCount();
            if count<1||obj.nodeCount()~=count+1
                error('lmz:Shooting:HorizonSize', ...
                    'A shooting horizon requires N segments and N+1 nodes.');
            end
            for index=1:obj.nodeCount()
                if ~isa(obj.Nodes{index},'lmz.shooting.ShootingNode')
                    error('lmz:Shooting:HorizonNode','Horizon node %d is invalid.',index);
                end
            end
            for index=1:count
                segment=obj.Segments{index};
                if ~isa(segment,'lmz.shooting.ShootingSegment')|| ...
                        segment.Index~=index
                    error('lmz:Shooting:HorizonSegment', ...
                        'Horizon segment %d is invalid.',index);
                end
                if ~strcmp(segment.StartNode.SectionId, ...
                        obj.Nodes{index}.SectionId)|| ...
                        ~strcmp(segment.StopNode.SectionId, ...
                        obj.Nodes{index+1}.SectionId)
                    error('lmz:Shooting:HorizonContinuity', ...
                        'Segment %d section endpoints do not match the nodes.',index);
                end
            end
            report=struct('Valid',true,'NodeCount',obj.nodeCount(), ...
                'SegmentCount',count,'Formulation',obj.Formulation);
        end

        function value=withNode(obj,index,node)
            if index<1||index>obj.nodeCount()|| ...
                    ~isa(node,'lmz.shooting.ShootingNode')
                error('lmz:Shooting:HorizonNode','Replacement node is invalid.');
            end
            value=obj;value.Nodes{index}=node;
            if index>1
                value.Segments{index-1}=value.Segments{index-1}.withNodes( ...
                    value.Nodes{index-1},node);
            end
            if index<=value.segmentCount()
                value.Segments{index}=value.Segments{index}.withNodes( ...
                    node,value.Nodes{index+1});
            end
            value.validate();
        end

        function value=append(obj,node,segment)
            expected=obj.segmentCount()+1;
            if ~isa(node,'lmz.shooting.ShootingNode')|| ...
                    ~isa(segment,'lmz.shooting.ShootingSegment')|| ...
                    segment.Index~=expected
                error('lmz:Shooting:HorizonAppend', ...
                    'Appended node or segment is invalid.');
            end
            value=obj;value.Nodes{end+1,1}=node;
            value.Segments{end+1,1}=segment;value.validate();
        end

        function value=toStruct(obj)
            nodes=cell(obj.nodeCount(),1);segments=cell(obj.segmentCount(),1);
            for index=1:numel(nodes),nodes{index}=obj.Nodes{index}.toStruct();end
            for index=1:numel(segments),segments{index}=obj.Segments{index}.toStruct();end
            value=struct('ModelId',obj.ModelId,'ProblemId',obj.ProblemId, ...
                'Nodes',{nodes},'Segments',{segments}, ...
                'Formulation',obj.Formulation,'Target',obj.Target, ...
                'Lineage',obj.Lineage);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            required={'ModelId','ProblemId','Nodes','Segments', ...
                'Formulation','Target','Lineage'};
            if ~isstruct(value)||~isscalar(value)|| ...
                    ~all(isfield(value,required))
                error('lmz:Shooting:HorizonStruct', ...
                    'Stored shooting horizon is incomplete.');
            end
            storedNodes=value.Nodes;
            if isstruct(storedNodes),storedNodes=num2cell(storedNodes);end
            storedSegments=value.Segments;
            if isstruct(storedSegments)
                storedSegments=num2cell(storedSegments);
            end
            if ~iscell(storedNodes)||~iscell(storedSegments)
                error('lmz:Shooting:HorizonStruct', ...
                    'Stored shooting nodes and segments must be record lists.');
            end
            nodes=cell(numel(storedNodes),1);
            for index=1:numel(nodes)
                nodes{index}=lmz.shooting.ShootingNode.fromStruct( ...
                    storedNodes{index});
            end
            segments=cell(numel(storedSegments),1);
            for index=1:numel(segments)
                record=storedSegments{index};
                record.StartNode=nodes{index}.toStruct();
                record.StopNode=nodes{index+1}.toStruct();
                segments{index}=lmz.shooting.ShootingSegment.fromStruct(record);
            end
            obj=lmz.shooting.ShootingHorizon('ModelId',value.ModelId, ...
                'ProblemId',value.ProblemId,'Nodes',nodes, ...
                'Segments',segments,'Formulation',value.Formulation, ...
                'Target',value.Target,'Lineage',value.Lineage);
        end
    end
end

function value=isFormulation(source)
value=ischar(source)&&any(strcmp(source,{'periodic','transition','feasibility'}));
end
