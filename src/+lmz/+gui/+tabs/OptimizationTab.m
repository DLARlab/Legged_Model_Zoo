classdef OptimizationTab
    %OPTIMIZATIONTAB Declarative shell for scientific fitting workflows.
    methods (Static)
        function tab = create(parent)
            tab = uitab(parent,'Title','Optimization', ...
                'Tag','lmz-tab-optimization');
        end
        function value = descriptor()
            value = struct('Id','optimization','Title','Optimization', ...
                'Purpose','Configure, run, cancel, compare, and save scientific fits.');
        end
    end
end
