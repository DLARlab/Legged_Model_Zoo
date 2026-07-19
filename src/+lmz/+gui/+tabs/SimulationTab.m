classdef SimulationTab
    %SIMULATIONTAB Declarative shell for the physical-simulation workspace.
    methods (Static)
        function tab = create(parent)
            tab = uitab(parent,'Title','Physical Simulation', ...
                'Tag','lmz-tab-simulation');
        end
        function value = descriptor()
            value = struct('Id','simulation','Title','Physical Simulation', ...
                'Purpose','Animate and inspect model-specific physical output.');
        end
    end
end
