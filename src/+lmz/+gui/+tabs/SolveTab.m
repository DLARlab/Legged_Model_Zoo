classdef SolveTab
    %SOLVETAB Declarative shell for root solving and seed construction.
    methods (Static)
        function tab = create(parent)
            tab = uitab(parent,'Title','Solve / Seeds', ...
                'Tag','lmz-tab-solve');
        end
        function value = descriptor()
            value = struct('Id','solve','Title','Solve / Seeds', ...
                'Purpose','Build reproducible seeds and refine equation solutions.');
        end
    end
end
