classdef SolveWorkspace < lmz.gui.tabs.SolveTab
    %SOLVEWORKSPACE Host-neutral root-solve and seed component.
    methods
        function obj=SolveWorkspace(parent,controller,eventBus,preferences,varargin)
            obj@lmz.gui.tabs.SolveTab(parent,controller,eventBus,preferences, ...
                varargin{:},'HostMode','workspace');
        end
    end
end
