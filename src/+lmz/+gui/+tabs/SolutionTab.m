classdef SolutionTab
    %SOLUTIONTAB Declarative shell for schema-aware solution inspection.
    methods (Static)
        function tab = create(parent)
            tab = uitab(parent,'Title','Solution Inspector', ...
                'Tag','lmz-tab-solution');
        end
        function value = descriptor()
            value = struct('Id','solution','Title','Solution Inspector', ...
                'Purpose','Edit, validate, simulate, and persist a working solution.');
        end
    end
end
