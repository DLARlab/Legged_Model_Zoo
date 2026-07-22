classdef BranchOverlayController < handle
    %BRANCHOVERLAYCONTROLLER Persistent named layers on one branch axes.
    properties (SetAccess=private)
        Axes = []
        AxisNames = {'dx','dphi','y'}
        Is3D = false
        PaletteName = 'default'
    end
    properties (Access=private)
        Layers
    end

    methods
        function obj=BranchOverlayController(axesHandle)
            obj.Layers=containers.Map('KeyType','char','ValueType','any');
            if nargin>=1&&~isempty(axesHandle),obj.attachAxes(axesHandle);end
        end

        function attachAxes(obj,value)
            if ~isempty(value)&&~isgraphics(value)
                error('lmz:GUI:OverlayAxes','Overlay target must be valid axes.');
            end
            obj.Axes=value;obj.renderAll();
        end

        function setAxisContext(obj,names,is3)
            if isstring(names),names=cellstr(names);end
            obj.AxisNames=names(:).';obj.Is3D=logical(is3);obj.renderAll();
        end

        function setSolution(obj,name,solution)
            obj.setPayload(name,struct('Type','solutions','Values',solution));
        end

        function setSolutions(obj,name,solutions)
            obj.setPayload(name,struct('Type','solutions','Values',solutions));
        end

        function setBranch(obj,name,branch)
            obj.setPayload(name,struct('Type','branch','Value',branch));
        end

        function setDecisions(obj,name,values,reference)
            obj.setPayload(name,struct('Type','decisions', ...
                'Values',values,'Reference',reference));
        end

        function setCoordinates(obj,name,values)
            obj.setPayload(name,struct('Type','coordinates','Values',values));
        end

        function setPair(obj,pair)
            obj.setSolution('first_seed',pair.First);
            obj.setSolution('second_seed',pair.Second);
            obj.setSolutions('continuation_predictor',[pair.First pair.Second]);
        end

        function setPalette(obj,value)
            if isstruct(value)&&isfield(value,'Name'),value=value.Name;end
            value=char(value);
            if ~any(strcmp(value,{'default','high-contrast'}))
                error('lmz:GUI:OverlayPalette', ...
                    'Unknown overlay palette %s.',value);
            end
            obj.PaletteName=value;names=obj.Layers.keys();
            for index=1:numel(names)
                layer=obj.Layers(names{index});
                layer.setStyle(layerStyle(names{index},obj.PaletteName));
            end
            obj.renderAll();
        end

        function clearLayer(obj,name)
            name=char(name);
            if ~isKey(obj.Layers,name),return,end
            layer=obj.Layers(name);remove(obj.Layers,name);delete(layer);
        end

        function clearRunLayers(obj)
            names={'edited_candidate','noise_candidate','predicted_seed', ...
                'current_solver_iterate','solved_point','first_seed', ...
                'second_seed','continuation_predictor', ...
                'accepted_continuation','rejected_continuation', ...
                'homotopy_result','family_branches'};
            for index=1:numel(names),obj.clearLayer(names{index});end
        end

        function clearAll(obj)
            names=obj.Layers.keys();
            for index=1:numel(names),obj.clearLayer(names{index});end
        end

        function axesWasCleared(obj),obj.renderAll();end

        function names=layerNames(obj),names=sort(obj.Layers.keys());end

        function value=layerHandle(obj,name)
            value=[];name=char(name);
            if isKey(obj.Layers,name)
                layer=obj.Layers(name);value=layer.Handle;
            end
        end

        function renderAll(obj)
            if isempty(obj.Axes)||~isgraphics(obj.Axes),return,end
            holdState=ishold(obj.Axes);hold(obj.Axes,'on');
            names=obj.Layers.keys();
            for index=1:numel(names)
                layer=obj.Layers(names{index});
                layer.render(obj.Axes,obj.AxisNames,obj.Is3D);
            end
            if ~holdState,hold(obj.Axes,'off');end
        end

        function delete(obj),obj.clearAll();obj.Axes=[];end
    end

    methods (Access=private)
        function setPayload(obj,name,payload)
            name=char(name);
            if isKey(obj.Layers,name)
                layer=obj.Layers(name);
            else
                layer=lmz.gui.branch.BranchOverlayLayer( ...
                    name,layerStyle(name,obj.PaletteName));
                obj.Layers(name)=layer;
            end
            layer.setPayload(payload);
            if isempty(obj.Axes)||~isgraphics(obj.Axes),return,end
            holdState=ishold(obj.Axes);hold(obj.Axes,'on');
            layer.render(obj.Axes,obj.AxisNames,obj.Is3D);
            if ~holdState,hold(obj.Axes,'off');end
        end
    end
end

function value=layerStyle(name,paletteName)
styles=struct();
styles.source_branches=style([0.45 0.45 0.45], ...
    'none','-',5,'none','source branches');
styles.hover_point=style([0.95 0.65 0.10],'o','none',7,'none','hover point');
styles.locked_point=style([0.12 0.12 0.12],'s','none',10,[1 0.84 0.1],'locked point');
styles.edited_candidate=style([0.55 0.25 0.78],'d','none',9,'none','edited candidate');
styles.noise_candidate=style([0.88 0.40 0.12],'^','none',9,'none','noise candidate');
styles.predicted_seed=style([0.1 0.55 0.75],'x','none',10,'none','predicted seed');
styles.current_solver_iterate=style([0.75 0.25 0.25],'+','none',11,'none','solver iterate');
styles.solved_point=style([0.05 0.55 0.22],'p','none',11,[0.05 0.55 0.22],'solved point');
styles.first_seed=style([0.1 0.3 0.85],'o','none',9,[0.1 0.3 0.85],'first seed');
styles.second_seed=style([0.85 0.2 0.2],'s','none',9,[0.85 0.2 0.2],'second seed');
styles.continuation_predictor=style([0.1 0.1 0.1],'none','--',6,'none','predictor');
styles.accepted_continuation=style([0.65 0.05 0.65],'o','-',6,'none','accepted continuation');
styles.rejected_continuation=style([0.85 0.25 0.1],'x','none',8,'none','rejected continuation');
styles.homotopy_result=style([0.1 0.55 0.65],'d','-',6,'none','homotopy result');
styles.family_branches=style([0.2 0.55 0.25],'.','-',6,'none','family branches');
if strcmp(paletteName,'high-contrast')
    styles.source_branches=style([0.78 0.78 0.78], ...
        '.','-',6,'none','source branches');
    styles.hover_point=style([0 1 1],'d','none',8,'none','hover point');
    styles.locked_point=style([1 1 0],'p','none',11,[1 1 0],'locked point');
    styles.edited_candidate=style([1 0.25 1],'d','none',10,'none','edited candidate');
    styles.noise_candidate=style([1 0.55 0],'^','none',10,'none','noise candidate');
    styles.predicted_seed=style([0.2 0.9 1],'x','none',11,'none','predicted seed');
    styles.current_solver_iterate=style([1 0.3 0.3],'+','none',12,'none','solver iterate');
    styles.solved_point=style([0.25 1 0.3],'p','none',12,[0.25 1 0.3],'solved point');
    styles.first_seed=style([0.3 0.65 1],'o','none',10,[0.3 0.65 1],'first seed');
    styles.second_seed=style([1 0.35 0.35],'s','none',10,[1 0.35 0.35],'second seed');
    styles.continuation_predictor=style([1 1 1],'none','--',6,'none','predictor');
    styles.accepted_continuation=style([1 0.35 1],'o','-',7,'none','accepted continuation');
    styles.rejected_continuation=style([1 0.45 0.1],'x','none',9,'none','rejected continuation');
    styles.homotopy_result=style([0.2 1 1],'d','-',7,'none','homotopy result');
    styles.family_branches=style([0.3 1 0.4],'.','-',7,'none','family branches');
end
if isfield(styles,name),value=styles.(name);else,value=style( ...
        [0.2 0.2 0.2],'o','none',8,'none',strrep(name,'_',' '));end
end
function value=style(color,marker,lineStyle,markerSize,face,label)
value=struct('Color',color,'Marker',marker,'LineStyle',lineStyle, ...
    'LineWidth',1.6,'MarkerSize',markerSize, ...
    'MarkerFaceColor',face,'DisplayName',label);
end
