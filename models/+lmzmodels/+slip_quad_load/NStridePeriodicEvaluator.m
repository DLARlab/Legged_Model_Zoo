classdef NStridePeriodicEvaluator
    %NSTRIDEPERIODICEVALUATOR Explicit contacts and final apex closure.
    properties (SetAccess = private)
        Codec
        Simulator
        Section
        Symmetry
    end

    methods
        function obj = NStridePeriodicEvaluator(model, codec, configuration)
            if ~isa(model, 'lmzmodels.slip_quad_load.Model') || ...
                    ~isa(codec, ...
                    'lmzmodels.slip_quad_load.NStridePeriodicCodec')
                error('lmz:QuadLoad:PeriodicEvaluatorInput', ...
                    'Quad-load periodic evaluator inputs are invalid.');
            end
            sections = localSections(model);
            startId = localField(configuration, 'StartSectionId', 'apex');
            stopId = localField(configuration, 'StopSectionId', startId);
            if ~strcmp(startId, 'apex') || ~strcmp(stopId, 'apex')
                error('lmz:QuadLoad:PeriodicSection', ...
                    ['The quad-load N-stride periodic formulation is ' ...
                    'currently validated only for apex-to-apex closure.']);
            end
            obj.Codec = codec;
            obj.Simulator = lmzmodels.slip_quad_load.MultiStrideSimulator();
            obj.Section = sections.section('apex');
            obj.Symmetry = sections.symmetryFor('apex');
            requested = localField(configuration, ...
                'SymmetryId', obj.Symmetry.Id);
            if strcmp(requested, 'identity')
                obj.Symmetry = lmz.poincare.IdentitySymmetry();
            elseif ~strcmp(requested, obj.Symmetry.Id)
                error('lmz:QuadLoad:PeriodicSymmetry', ...
                    'SymmetryId is incompatible with the apex catalog.');
            end
        end

        function value = evaluate(obj, u, p, context, ...
                includeSimulation, contract)
            if contract.NumberOfStrides ~= obj.Codec.NumberOfStrides
                error('lmz:QuadLoad:PeriodicStrideContract', ...
                    'The evaluator and generic N-stride contract disagree.');
            end
            xAccum = obj.Codec.expand(u, p);
            raw = obj.Simulator.runRaw(xAccum, context, false);
            count = obj.Codec.NumberOfStrides;
            expected = 27 * count;
            if numel(raw.Residual) ~= expected
                error('lmz:QuadLoad:PeriodicResidualLayout', ...
                    'The source residual no longer has 27 rows per stride.');
            end
            contacts = cell(count, 1);
            legacyPeriodicity = cell(count, 1);
            for stride = 1:count
                offset = 27 * (stride - 1);
                contacts{stride} = raw.Residual(offset + (1:9));
                legacyPeriodicity{stride} = ...
                    raw.Residual(offset + (10:27));
            end
            schema = lmzmodels.slip_quad_load.PhysicalStateSchema.create();
            initial = raw.States(1, :).';
            terminal = raw.States(end, :).';
            aligned = obj.Symmetry.align(terminal, initial, schema);
            closure = obj.Section.coordinates(aligned, schema) - ...
                obj.Section.coordinates(initial, schema);
            simulation = [];
            if includeSimulation
                simulation = obj.Simulator.run(xAccum, context, ...
                    struct('EnforceEventTiming', false));
            end
            finite = all(isfinite(raw.States(:))) && ...
                all(isfinite(raw.Residual));
            feasibility = struct('Valid', finite && ...
                all(raw.States(:, 3) > 0), ...
                'ContactResidualNorms', ...
                cellfun(@norm, contacts), ...
                'FinalClosureNorm', norm(closure));
            diagnostics = struct( ...
                'Formulation', ...
                'quad-load-explicit-n-stride-final-apex-closure-v1', ...
                'FullXAccum', xAccum, ...
                'Codec', obj.Codec.toStruct(), ...
                'LegacyResidual', raw.Residual, ...
                'LegacyPerStridePeriodicityResiduals', ...
                {legacyPeriodicity}, ...
                'IntermediateLegacyPeriodicityImposed', false, ...
                'EventTimingVariablesExplicit', true, ...
                'SymmetryId', obj.Symmetry.Id, ...
                'HiddenTimingSolve', false);
            value = struct('ContactResiduals', {contacts}, ...
                'FinalClosureResidual', closure, ...
                'Simulation', simulation, 'Feasibility', feasibility, ...
                'PhysicalValidity', feasibility.Valid, ...
                'Diagnostics', diagnostics);
        end
    end
end

function sections = localSections(model)
manifest = model.registeredManifest();
if ~isempty(manifest) && isfield(manifest, 'poincareSectionsPath')
    path = manifest.poincareSectionsPath;
else
    path = fullfile(lmz.util.ProjectPaths.catalog(), ...
        'slip_quad_load', 'poincare_sections.json');
end
sections = lmz.poincare.PoincareSectionRegistry.fromJson(path, ...
    'ModelId', 'slip_quad_load', ...
    'StateSchema', model.getPhysicalStateSchema());
end

function value = localField(source, name, fallback)
if isfield(source, name)
    value = source.(name);
else
    value = fallback;
end
end
