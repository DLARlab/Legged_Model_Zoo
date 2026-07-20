classdef ResearchLegGeometry
    %RESEARCHLEGGEOMETRY Pure compound-leg geometry and named frame data.
    properties (Constant)
        SourceCommit = '2c106101383ecee1b2a9d695efe09fbd72d5718a'
        SourcePath = ['SLIP_Quadruped/2_Graphic_ToolBox/' ...
            'SLIP_Quadrupedal_Graphics/GraphicFunctions/' ...
            'ComputeLegGraphics.m']
        JointSourcePath = ['SLIP_Quadruped/2_Graphic_ToolBox/' ...
            'SLIP_Quadrupedal_Graphics/GraphicFunctions/' ...
            'ComputeJoint_LegLA.m']
    end

    methods (Static)
        function value = compute(attachment, currentLength, restLength, angle)
            if ~isnumeric(attachment) || ~isreal(attachment) || ...
                    numel(attachment) ~= 2 || ...
                    any(~isfinite(attachment(:))) || ...
                    ~isnumeric(currentLength) || ~isscalar(currentLength) || ...
                    ~isreal(currentLength) || ~isfinite(currentLength) || ...
                    ~isnumeric(restLength) || ~isscalar(restLength) || ...
                    ~isreal(restLength) || ~isfinite(restLength) || ...
                    restLength <= 0 || ~isnumeric(angle) || ~isscalar(angle) || ...
                    ~isreal(angle) || ~isfinite(angle)
                error('lmz:slip_quadruped:LegGeometryInput', ...
                    'Attachment, finite length/angle, and positive rest length are required.');
            end
            attachment = reshape(attachment, 1, []);

            compression = (currentLength-restLength)/restLength;
            springWidth = 0.09;
            springX = [repmat([-springWidth, springWidth], 1, 7), ...
                -springWidth];
            springY = [-0.4, linspace(-0.4, -0.8-compression, 13), ...
                -0.8-compression] * restLength;
            springVertices = transform([springX.', springY.'], angle, attachment);
            spring1Faces = [(1:14).', (2:15).'];

            upperX = zeros(1, 26); upperY = zeros(1, 26);
            upperX(1:3) = [-0.05, -0.05, -0.10];
            upperY(1:3) = [-0.70-compression, -0.39, -0.39] * restLength;
            theta = linspace(pi, 0, 20);
            upperX(4:23) = cos(theta) * 0.1;
            upperY(4:23) = sin(theta) * 0.08 * restLength;
            upperX(24:26) = [0.10, 0.05, 0.05];
            upperY(24:26) = fliplr(upperY(1:3));
            upperVertices = transform([upperX.', upperY.'], angle, attachment);
            upperFaces = [26, 1:25];

            shadeX = zeros(1, 60); shadeY = zeros(1, 60);
            shadeX(1:5) = linspace(-0.1, 0.1, 5);
            shadeY(1:5) = -0.39 * restLength;
            shadeX(6:25) = 0.1;
            shadeY(6:25) = linspace(-0.39, 0, 20) * restLength;
            theta = linspace(0, pi, 15);
            shadeX(26:40) = cos(theta) * 0.1;
            shadeY(26:40) = sin(theta) * 0.08 * restLength;
            shadeX(41:60) = -0.1;
            shadeY(41:60) = linspace(0, -0.39, 20) * restLength;
            shadeVertices = transform([shadeX.', shadeY.'], angle, attachment);
            shadeFaces = [1 12; 3 9; 57 15; 54 18; ...
                51 21; 48 24; 45 28; 42 31];

            lowerX = zeros(1, 54); lowerY = zeros(1, 54);
            lowerX(1:2) = [-0.03, -0.03];
            lowerY(1:2) = [-0.70, -0.81] * restLength;
            theta = linspace(pi/2, 0, 20);
            lowerX(3:22) = cos(theta) * 0.10 - 0.1;
            lowerY(3:22) = (sin(theta) * 0.19 - 1) * restLength;
            theta = linspace(pi/2, pi/2+2*pi, 20);
            lowerX(23:42) = cos(theta) * 0.01;
            lowerY(23:42) = (sin(theta) * 0.01 - 1) * restLength;
            theta = linspace(pi, pi/2, 10);
            lowerX(43:52) = cos(theta) * 0.10 + 0.1;
            lowerY(43:52) = (sin(theta) * 0.19 - 1) * restLength;
            lowerX(53:54) = [0.03, 0.03];
            lowerY(53:54) = [-0.81, -0.70] * restLength;
            lowerY = lowerY - compression * restLength;
            lowerVertices = transform([lowerX.', lowerY.'], angle, attachment);
            lowerFaces = 1:54;
            spring2Faces = [(1:2:13).', (2:2:14).'];

            metadata = lmzmodels.slip_quadruped.ResearchLegGeometry.provenance();
            metadata.constants = struct('springHalfWidth', 0.09, ...
                'compression', compression, 'restLength', restLength, ...
                'currentLength', currentLength, 'absoluteAngle', angle);
            spring1 = lmz.viz.PatchGeometry('spring_part_1', ...
                springVertices, spring1Faces, metadata);
            upperBackground = lmz.viz.PatchGeometry('upper_background', ...
                upperVertices, upperFaces, metadata);
            upperShading = lmz.viz.PatchGeometry('upper_shading', ...
                shadeVertices, shadeFaces, metadata);
            upperOutline = lmz.viz.PatchGeometry('upper_outline', ...
                upperVertices, upperFaces, metadata);
            lower = lmz.viz.PatchGeometry('lower_leg', ...
                lowerVertices, lowerFaces, metadata);
            spring2 = lmz.viz.PatchGeometry('spring_part_2', ...
                springVertices, spring2Faces, metadata);
            value = struct('Spring1', spring1, ...
                'UpperBackground', upperBackground, ...
                'UpperShading', upperShading, ...
                'UpperOutline', upperOutline, 'Lower', lower, ...
                'Spring2', spring2, 'Compression', compression, ...
                'Attachment', attachment, 'CurrentLength', currentLength, ...
                'RestLength', restLength, 'AbsoluteAngle', angle, ...
                'Layers', lmz.viz.LayeredGeometry('research_leg', ...
                    {spring1, upperBackground, upperShading, ...
                     upperOutline, lower, spring2}, metadata), ...
                'Metadata', metadata);
        end

        function value = frame(simulation, index)
            assertSimulation(simulation, index);
            x = namedState(simulation, 'x', index);
            y = namedState(simulation, 'y', index);
            pitch = namedState(simulation, 'phi', index);
            backFraction = namedParameter(simulation, 'l_b');
            restLength = namedParameter(simulation, 'l_leg');
            back = [x-backFraction*cos(pitch), ...
                y-backFraction*sin(pitch)];
            front = [x+(1-backFraction)*cos(pitch), ...
                y+(1-backFraction)*sin(pitch)];
            attachments = [back; front; back; front];
            stateNames = {'alphaBL', 'alphaFL', 'alphaBR', 'alphaFR'};
            angles = zeros(1, 4);
            for leg = 1:4
                angles(leg) = namedState(simulation, stateNames{leg}, index) + pitch;
            end
            schedule = ...
                lmzmodels.slip_quadruped.ResearchLegGeometry.eventSchedule(simulation);
            eventPairs = {'tBL_TD','tBL_LO'; 'tFL_TD','tFL_LO'; ...
                'tBR_TD','tBR_LO'; 'tFR_TD','tFR_LO'};
            contact = false(1, 4); lengths = restLength * ones(1, 4);
            time = simulation.Time(index);
            for leg = 1:4
                contact(leg) = lmzmodels.slip_quadruped.ResearchLegGeometry. ...
                    isContact(time, schedule.(eventPairs{leg, 1}), ...
                    schedule.(eventPairs{leg, 2}), schedule.tAPEX);
                if contact(leg)
                    denominator = cos(angles(leg));
                    if denominator == 0
                        error('lmz:slip_quadruped:SingularLegGeometry', ...
                            'Source stance-length geometry is singular.');
                    end
                    lengths(leg) = attachments(leg, 2) / denominator;
                end
            end
            geometries = cell(1, 4); feet = zeros(4, 2);
            for leg = 1:4
                geometries{leg} = ...
                    lmzmodels.slip_quadruped.ResearchLegGeometry.compute( ...
                    attachments(leg, :), lengths(leg), restLength, angles(leg));
                feet(leg, :) = attachments(leg, :) + ...
                    [lengths(leg)*sin(angles(leg)), ...
                     -lengths(leg)*cos(angles(leg))];
            end
            value = struct();
            value.Names = {'back_left','front_left','back_right','front_right'};
            value.Attachments = attachments;
            value.Lengths = lengths;
            value.RestLength = restLength;
            value.AbsoluteAngles = angles;
            value.Contact = contact;
            value.Feet = feet;
            value.Geometry = geometries;
            value.BodyFrame = [x, y, pitch];
            value.Schedule = schedule;
            value.Time = time;
            value.Index = index;
        end

        function schedule = eventSchedule(simulation)
            if ~isa(simulation, 'lmz.api.SimulationResult')
                error('lmz:slip_quadruped:EventSchedule', ...
                    'SimulationResult is required.');
            end
            recordNames = {'BL_TD','BL_LO','FL_TD','FL_LO', ...
                'BR_TD','BR_LO','FR_TD','FR_LO','APEX'};
            fieldNames = {'tBL_TD','tBL_LO','tFL_TD','tFL_LO', ...
                'tBR_TD','tBR_LO','tFR_TD','tFR_LO','tAPEX'};
            schedule = struct();
            records = simulation.EventRecords;
            for item = 1:numel(recordNames)
                match = [];
                for recordIndex = 1:numel(records)
                    if isfield(records(recordIndex), 'Name') && ...
                            strcmp(char(records(recordIndex).Name), recordNames{item})
                        match = recordIndex;
                        break
                    end
                end
                if isempty(match) || ~isfield(records(match), 'Time') || ...
                        ~isnumeric(records(match).Time) || ...
                        ~isscalar(records(match).Time) || ...
                        ~isfinite(records(match).Time)
                    error('lmz:slip_quadruped:EventSchedule', ...
                        'Named event record %s is required.', recordNames{item});
                end
                schedule.(fieldNames{item}) = records(match).Time;
            end
            if schedule.tAPEX <= 0
                error('lmz:slip_quadruped:EventPeriod', ...
                    'Stride period must be positive.');
            end
            for item = 1:8
                schedule.(fieldNames{item}) = ...
                    lmzmodels.slip_quadruped.ResearchLegGeometry.wrapOnce( ...
                    schedule.(fieldNames{item}), schedule.tAPEX);
            end
        end

        function result = isContact(time, touchdown, liftoff, period)
            values = {time, touchdown, liftoff, period};
            valid = cellfun(@(item) isnumeric(item) && isreal(item) && ...
                isscalar(item) && isfinite(item), values);
            if ~all(valid) || period <= 0
                error('lmz:slip_quadruped:ContactTime', ...
                    'Finite event times and positive period are required.');
            end
            touchdown = ...
                lmzmodels.slip_quadruped.ResearchLegGeometry.wrapOnce( ...
                touchdown, period);
            liftoff = lmzmodels.slip_quadruped.ResearchLegGeometry.wrapOnce( ...
                liftoff, period);
            result = (touchdown < liftoff && time > touchdown && time < liftoff) || ...
                (touchdown > liftoff && (time < liftoff || time > touchdown));
        end

        function value = wrapOnce(value, period)
            if value < 0, value = value + period; end
            if value > period, value = value - period; end
        end

        function value = provenance()
            value = struct('sourceRepository', 'DLARlab/SLIP_Model_Zoo', ...
                'sourceCommit', ...
                lmzmodels.slip_quadruped.ResearchLegGeometry.SourceCommit, ...
                'sourcePath', ...
                lmzmodels.slip_quadruped.ResearchLegGeometry.SourcePath, ...
                'sourceLines', '3-65', 'jointSourcePath', ...
                lmzmodels.slip_quadruped.ResearchLegGeometry.JointSourcePath, ...
                'jointSourceLines', '14-163', ...
                'adaptation', ['Pure numeric layers with named state, parameter, ' ...
                    'and event access; source one-wrap strict contact is retained.'], ...
                'redistributionStatus', 'unresolved_source_derived');
        end
    end
end

function points = transform(points, angle, center)
rotation = [cos(angle), -sin(angle); sin(angle), cos(angle)];
points = points * rotation.' + reshape(center, 1, 2);
end

function assertSimulation(simulation, index)
if ~isa(simulation, 'lmz.api.SimulationResult') || ...
        ~isnumeric(index) || ~isreal(index) || ~isscalar(index) || ...
        ~isfinite(index) || index ~= fix(index) || ...
        index < 1 || index > numel(simulation.Time)
    error('lmz:slip_quadruped:GeometryFrame', ...
        'A SimulationResult and valid frame index are required.');
end
end

function value = namedState(simulation, name, index)
try
    values = simulation.state(name);
catch
    error('lmz:slip_quadruped:GeometryState', ...
        'Named simulation state %s is required.', name);
end
value = values(index);
end

function value = namedParameter(simulation, name)
if ~isstruct(simulation.Parameters) || ~isfield(simulation.Parameters, name) || ...
        ~isnumeric(simulation.Parameters.(name)) || ...
        ~isreal(simulation.Parameters.(name)) || ...
        ~isscalar(simulation.Parameters.(name)) || ...
        ~isfinite(simulation.Parameters.(name))
    error('lmz:slip_quadruped:GeometryParameter', ...
        'Simulation parameter %s is required.', name);
end
value = simulation.Parameters.(name);
end
