classdef SolutionWorkspace < lmz.gui.tabs.SolutionTab
    %SOLUTIONWORKSPACE Host-neutral solution inspector.
    methods
        function obj=SolutionWorkspace(parent,controller,eventBus,preferences,varargin)
            obj@lmz.gui.tabs.SolutionTab(parent,controller,eventBus,preferences, ...
                varargin{:},'HostMode','workspace');
        end
    end
end
