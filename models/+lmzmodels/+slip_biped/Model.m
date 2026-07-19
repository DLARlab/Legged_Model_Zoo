classdef Model < lmz.api.LeggedModel
    %MODEL Standalone analytic SLIP biped demonstration model.
    methods
        function value = getManifest(~)
            value = struct('id', 'slip_biped', 'version', '1.0.0');
        end

        function value = getCapabilities(~)
            value = struct('simulate', true, 'solve', false, ...
                'continue', false, 'optimize', false, 'visualize', true, ...
                'animate', true, 'parameterHomotopy', false, ...
                'branchFamilyScan', false);
        end

        function schema = getPhysicalStateSchema(~)
            names = {'x', 'y', 'body_pitch', 'foot_left_x', ...
                'foot_left_y', 'foot_right_x', 'foot_right_y'};
            units = {'m', 'm', 'rad', 'm', 'm', 'm', 'm'};
            schema = lmzmodels.slip_biped.Model.makeSchema(names, units);
        end

        function schema = getParameterSchema(~)
            schema = lmz.schema.VariableSchema([ ...
                lmz.schema.VariableSpec('speed', 'Unit', 'm/s', ...
                    'DefaultValue', 1, 'Scale', 1); ...
                lmz.schema.VariableSpec('stride_period', 'Unit', 's', ...
                    'DefaultValue', 0.8, 'LowerBound', 0, ...
                    'Topology', 'positive', 'Scale', 1)]);
        end

        function value = listProblems(~)
            value = {'demo_stride'};
        end

        function problem = createProblem(obj, problemId, configuration)
            if ~strcmp(problemId, 'demo_stride')
                error('lmz:slip_biped:UnknownProblem', ...
                    'Unknown problem: %s', problemId);
            end
            problem = lmz.api.SimulationProblem(obj, problemId, configuration);
        end

        function result = simulate(obj, request, context)
            context.check();
            parameters = lmzmodels.slip_biped.Model.parameters(request, 1, 0.8);
            time = linspace(0, parameters.stride_period, 241)';
            phase = 2 * pi * time / parameters.stride_period;
            x = parameters.speed * time;
            y = 1 + 0.06 * cos(2 * phase);
            pitch = 0.04 * sin(phase);
            step = 0.35;
            leftX = x - step * cos(phase);
            rightX = x - step * cos(phase + pi);
            leftY = max(0, 0.12 * sin(phase));
            rightY = max(0, 0.12 * sin(phase + pi));
            states = [x, y, pitch, leftX, leftY, rightX, rightY];
            result = lmz.api.SimulationResult(time, obj.getPhysicalStateSchema(), ...
                states, struct('contact_left', leftY == 0, ...
                'contact_right', rightY == 0), struct(), parameters, ...
                struct('source', 'standalone-analytic-demo'), ...
                struct('modelId', 'slip_biped', 'problemId', request.ProblemId));
            context.progress(1, 'SLIP biped demonstration simulated.');
        end

        function frames = kinematics(~, frame)
            frames = frame;
        end

        function value = getPlotDescriptors(~)
            value = struct('id', 'trajectory', 'label', 'Body and feet');
        end
    end

    methods (Static, Access=private)
        function schema = makeSchema(names, units)
            specs = lmz.schema.VariableSpec.empty(0, 1);
            for index = 1:numel(names)
                specs(index, 1) = lmz.schema.VariableSpec(names{index}, ...
                    'Unit', units{index}); %#ok<AGROW>
            end
            schema = lmz.schema.VariableSchema(specs);
        end

        function value = parameters(request, speed, period)
            value = struct('speed', speed, 'stride_period', period);
            if isfield(request.Options, 'speed'), value.speed = request.Options.speed; end
            if isfield(request.Options, 'stride_period'), value.stride_period = request.Options.stride_period; end
        end
    end
end
