classdef RoadMapBranchTab
    %ROADMAPBRANCHTAB Declarative shell for scientific branch datasets.
    methods (Static)
        function tab = create(parent)
            tab = uitab(parent,'Title','Scientific Branches', ...
                'Tag','lmz-tab-branches');
        end
        function value = descriptor()
            value = struct('Id','branches','Title','Scientific Branches', ...
                'Purpose','Load, compare, select, and export scientific branches.');
        end
    end
end
