classdef RoadMapBranchTab < lmz.gui.tabs.BranchTab
    %ROADMAPBRANCHTAB Compatibility name for the complete BranchTab component.
    methods
        function obj=RoadMapBranchTab(varargin)
            obj@lmz.gui.tabs.BranchTab(varargin{:});
        end
    end
    methods (Static)
        function tab=create(parent)
            % Legacy shell factory retained for internal Round 5/6 callers.
            tab=uitab(parent,'Title','Scientific Branches','Tag','lmz-tab-branches');
        end
        function value=descriptor()
            value=struct('Id','branches','Title','Scientific Branches', ...
                'Purpose','Load, compare, select, and export scientific branches.');
        end
    end
end
