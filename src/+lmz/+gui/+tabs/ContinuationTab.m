classdef ContinuationTab
    %CONTINUATIONTAB Declarative shell for branch tracing and checkpoints.
    methods (Static)
        function tab = create(parent)
            tab = uitab(parent,'Title','Continuation', ...
                'Tag','lmz-tab-continuation');
        end
        function value = descriptor()
            value = struct('Id','continuation','Title','Continuation', ...
                'Purpose','Trace, pause, resume, diagnose, and save branches.');
        end
    end
end
