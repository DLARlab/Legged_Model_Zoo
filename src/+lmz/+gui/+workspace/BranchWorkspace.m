classdef BranchWorkspace < lmz.gui.tabs.BranchTab
    %BRANCHWORKSPACE Host-neutral branch component for workbench layouts.
    methods
        function obj=BranchWorkspace(parent,controller,eventBus,preferences,varargin)
            obj@lmz.gui.tabs.BranchTab(parent,controller,eventBus,preferences, ...
                varargin{:},'HostMode','workspace');
        end
    end
end
