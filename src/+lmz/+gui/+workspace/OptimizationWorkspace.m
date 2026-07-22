classdef OptimizationWorkspace < lmz.gui.tabs.OptimizationTab
    %OPTIMIZATIONWORKSPACE Host-neutral optimization component.
    methods
        function obj=OptimizationWorkspace(parent,controller,eventBus,preferences,varargin)
            obj@lmz.gui.tabs.OptimizationTab(parent,controller,eventBus,preferences, ...
                varargin{:},'HostMode','workspace');
        end
    end
end
