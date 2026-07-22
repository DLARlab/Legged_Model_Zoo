classdef ContinuationWorkspace < lmz.gui.tabs.ContinuationTab
    %CONTINUATIONWORKSPACE Host-neutral continuation component.
    methods
        function obj=ContinuationWorkspace(parent,controller,eventBus,preferences,varargin)
            obj@lmz.gui.tabs.ContinuationTab(parent,controller,eventBus,preferences, ...
                varargin{:},'HostMode','workspace');
        end
    end
end
