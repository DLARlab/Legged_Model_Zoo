classdef Model < lmz.api.LeggedModel
    methods
        function value = getManifest(~)
            value = struct('id', 'slip.quadruped.load', 'version', '1.0.0');
        end
        function value = getCapabilities(~)
            value = struct('simulate', false, 'solve', false, ...
                'continue', false, 'optimize', false, 'visualize', false);
        end
        function value = getPhysicalStateSchema(~), value = []; end
        function value = getParameterSchema(~), value = []; end
        function value = listProblems(~)
            value = {'single_stride_periodic', 'multi_stride_fit'};
        end
        function value = createProblem(~, problemId, configuration)
            value = struct('id', problemId, 'configuration', configuration, ...
                'status', 'not-implemented');
        end
        function value = simulate(~, ~, ~)
            error('lmz:QuadLoad:Unavailable', ...
                'Load-pulling simulation is not migrated.');
            value = []; %#ok<UNRCH>
        end
        function value = kinematics(~, frame), value = frame; end
        function value = getPlotDescriptors(~), value = struct([]); end
    end
end
