classdef BranchOverlayLayer < handle
    %BRANCHOVERLAYLAYER One named, update-in-place branch graphics layer.
    properties (SetAccess=private)
        Name
        Payload = struct()
        Style = struct()
        Handle = []
    end

    methods
        function obj=BranchOverlayLayer(name,style)
            obj.Name=char(name);obj.Style=style;
        end

        function setPayload(obj,value),obj.Payload=value;end
        function setStyle(obj,value),obj.Style=value;end

        function render(obj,axesHandle,names,is3)
            if isempty(obj.Payload)||~isstruct(obj.Payload)|| ...
                    ~isfield(obj.Payload,'Type')
                obj.clearGraphics();return
            end
            values=obj.coordinates(names);
            if isempty(values)||size(values,1)<2||all(~isfinite(values(:)))
                obj.clearGraphics();return
            end
            x=values(1,:);y=values(2,:);z=zeros(size(x));
            if is3&&size(values,1)>=3,z=values(3,:);end
            if isempty(obj.Handle)||~isgraphics(obj.Handle)
                obj.Handle=line(axesHandle,'XData',x,'YData',y,'ZData',z, ...
                    'Tag',['lmz-overlay-' strrep(obj.Name,'_','-')]);
            else
                set(obj.Handle,'XData',x,'YData',y,'ZData',z);
            end
            applyStyle(obj.Handle,obj.Style,obj.Name);
            if ~is3,obj.Handle.ZData=zeros(size(x));end
        end

        function clearGraphics(obj)
            if ~isempty(obj.Handle)&&isgraphics(obj.Handle),delete(obj.Handle);end
            obj.Handle=[];
        end

        function delete(obj),obj.clearGraphics();end
    end

    methods (Access=private)
        function values=coordinates(obj,names)
            source=obj.Payload;
            switch source.Type
                case 'solutions'
                    values=lmz.gui.branch.BranchCoordinateMapper.solutions( ...
                        source.Values,names);
                case 'branch'
                    values=lmz.gui.branch.BranchCoordinateMapper.branch( ...
                        source.Value,names);
                case 'decisions'
                    values=lmz.gui.branch.BranchCoordinateMapper.decisions( ...
                        source.Values,source.Reference,names);
                case 'coordinates'
                    values=source.Values;
                otherwise
                    values=[];
            end
        end
    end
end

function applyStyle(handle,style,name)
defaults=struct('Color',[0.2 0.2 0.2],'LineStyle','none', ...
    'LineWidth',1.5,'Marker','o','MarkerSize',8, ...
    'MarkerFaceColor','none','DisplayName',strrep(name,'_',' '));
fields=fieldnames(defaults);
for index=1:numel(fields)
    field=fields{index};value=defaults.(field);
    if isfield(style,field),value=style.(field);end
    if isprop(handle,field),handle.(field)=value;end
end
end
