classdef LeggedModelZooApp < handle
    properties, Figure; Tabs; Controller; State; Status; end
    methods
        function obj=LeggedModelZooApp(varargin)
            registry=lmz.core.ModelRegistry();obj.State=lmz.gui.AppState(registry);obj.Controller=lmz.gui.AppController(obj.State);
            visible='on';if nargin>0,visible=varargin{1};end;obj.Figure=uifigure('Name','Legged Model Zoo','Visible',visible,'Position',[100 100 1280 760]);root=uigridlayout(obj.Figure,[2 1]);root.RowHeight={'1x',28};obj.Tabs=uitabgroup(root);
            names={'Models','Problem','Solve / Search','Continuation','Visualization','Results / Logs'};for i=1:numel(names),tab=uitab(obj.Tabs,'Title',names{i});g=uigridlayout(tab,[1 1]);uilabel(g,'Text',[names{i} ' workspace'],'HorizontalAlignment','center');end
            obj.Status=uilabel(root,'Text','Ready');obj.buildModelsTab();
        end
        function buildModelsTab(obj),tab=obj.Tabs.Children(end);delete(tab.Children);g=uigridlayout(tab,[2 2]);g.RowHeight={30,'1x'};uilabel(g,'Text','Discovered models');ids=obj.State.Registry.ids();dd=uidropdown(g,'Items',ids,'ValueChangedFcn',@(s,~)obj.onModel(s.Value));dd.Layout.Row=1;dd.Layout.Column=2;info=uitextarea(g,'Editable','off');info.Layout.Row=2;info.Layout.Column=[1 2];if ~isempty(ids),obj.onModel(ids{1});m=obj.State.Registry.manifest(ids{1});info.Value={m.display_name,['Version ' m.model_version],['Capabilities: ' strjoin(m.capabilities,', ')]};end,end
        function onModel(obj,id),try,obj.Controller.selectModel(id);obj.Status.Text=['Selected ' id];catch ME,obj.Status.Text=ME.message;end,end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
    end
end
