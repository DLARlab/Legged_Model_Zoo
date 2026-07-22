classdef ShootingWorkspace < lmz.gui.workspace.SolveWorkspace
    %SHOOTINGWORKSPACE Compatibility host for advanced shooting controls.
    % The scientific shell uses its single SolveWorkspace instance rather
    % than constructing this alias, so presentation subscriptions stay unique.
    methods
        function obj=ShootingWorkspace(parent,controller,eventBus,preferences,varargin)
            obj@lmz.gui.workspace.SolveWorkspace(parent,controller,eventBus, ...
                preferences,varargin{:});
        end
    end
end
