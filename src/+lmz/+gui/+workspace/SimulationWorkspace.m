classdef SimulationWorkspace < lmz.gui.tabs.SimulationTab
    %SIMULATIONWORKSPACE Host-neutral visualization component.
    methods
        function obj=SimulationWorkspace(parent,controller,eventBus,preferences,varargin)
            obj@lmz.gui.tabs.SimulationTab(parent,controller,eventBus,preferences, ...
                varargin{:},'HostMode','workspace');
        end
    end
end
