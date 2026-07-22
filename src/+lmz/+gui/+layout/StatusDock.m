classdef StatusDock < handle
    %STATUSDOCK Placement wrapper for persistent status and run progress.
    properties (SetAccess=private)
        Root
        Panel
    end
    methods
        function obj=StatusDock(parent)
            obj.Root=uipanel(parent,'BorderType','none','Tag','lmz-status-dock');
            grid=uigridlayout(obj.Root,[1 1]);grid.Padding=[0 0 0 0];
            obj.Panel=lmz.gui.components.StatusPanel(grid);
        end
        function delete(obj)
            if ~isempty(obj.Panel)&&isvalid(obj.Panel),delete(obj.Panel);end
            obj.Panel=[];
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];
        end
    end
end
