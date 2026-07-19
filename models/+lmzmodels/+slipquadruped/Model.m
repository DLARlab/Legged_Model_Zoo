classdef Model < lmz.api.LeggedModel
    %MODEL SLIP quadruped integration boundary.
    % Numerical capabilities remain disabled until the legacy evaluator and
    % regression baselines are available inside this project.
    methods
        function value = getManifest(~)
            value = struct('id', 'slip.quadruped.planar.v2', ...
                'version', '2.0.0');
        end

        function value = getCapabilities(~)
            value = struct('simulate', false, 'solve', false, ...
                'continue', false, 'optimize', false, 'visualize', false);
        end

        function value = getPhysicalStateSchema(~)
            value = [];
        end

        function value = getParameterSchema(~)
            value = [];
        end

        function value = listProblems(~)
            value = {'periodic_apex'};
        end

        function value = createProblem(~, problemId, configuration)
            if ~strcmp(problemId, 'periodic_apex')
                error('lmz:SlipQuadruped:UnknownProblem', ...
                    'Unknown problem: %s', problemId);
            end
            value = struct('id', problemId, 'configuration', configuration, ...
                'status', 'not-implemented');
        end

        function value = simulate(~, ~, context)
            context.check();
            error('lmz:SlipQuadruped:Unavailable', ...
                'The quadruped evaluator has not yet been vendored.');
            value = []; %#ok<UNRCH>
        end

        function value = kinematics(~, frame)
            value = frame;
        end

        function value = getPlotDescriptors(~)
            value = struct([]);
        end
    end
end
