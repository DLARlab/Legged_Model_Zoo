classdef PeriodicOrbitProblem < lmz.api.NonlinearEquationProblem
    %PERIODICORBITPROBLEM Configurable catalog-section scientific problem.
    properties (SetAccess = private)
        ApexProblem
        ReturnEvaluator
    end

    methods
        function obj = PeriodicOrbitProblem(model, configuration)
            if nargin < 2
                configuration = struct();
            end
            apex = lmzmodels.slip_quadruped.PeriodicApexProblem( ...
                model, struct());
            obj@lmz.api.NonlinearEquationProblem(model, ...
                'periodic_orbit', 'nonlinear_equation', ...
                apex.getDecisionSchema(), apex.getParameterSchema(), ...
                apex.getParameterSchema().defaults(), configuration);
            obj.Version = '1.0.0';
            obj.ApexProblem = apex;
            obj.ReturnEvaluator = ...
                lmz.poincare.ScientificPeriodicOrbitEvaluator();
        end

        function evaluation = evaluate(obj, u, p, context, includeSimulation)
            if nargin < 5
                includeSimulation = false;
            end
            returned = obj.ReturnEvaluator.evaluate(obj.Model, ...
                obj.ApexProblem, u, p, obj.Configuration, 13, context, ...
                includeSimulation);
            base = returned.BaseEvaluation;
            if returned.ApexEquivalent
                diagnostics = base.Diagnostics;
                diagnostics.PeriodicOrbit = returned.Diagnostics;
                evaluation = lmz.data.ProblemEvaluation( ...
                    base.ResidualBlocks, 'Simulation', base.Simulation, ...
                    'Feasibility', base.Feasibility, ...
                    'PhysicalValidity', base.PhysicalValidity, ...
                    'Warnings', base.Warnings, 'Diagnostics', diagnostics);
                return
            end
            blocks = [ ...
                lmz.data.ResidualBlock('contact_geometry', ...
                base.Residual(1:8), ones(8, 1)); ...
                lmz.data.ResidualBlock('source_apex_phase_gauge', ...
                base.Residual(9), 1); ...
                lmz.data.ResidualBlock('section_periodicity', ...
                returned.PeriodicResidual, ...
                ones(numel(returned.PeriodicResidual), 1))];
            next = returned.NextEvaluation;
            valid = base.Feasibility.Valid && next.Feasibility.Valid && ...
                all(isfinite(returned.PeriodicResidual));
            feasibility = struct('Valid', valid, ...
                'BaseApex', base.Feasibility, ...
                'NextApex', next.Feasibility, ...
                'SectionResidualNorm', norm(returned.PeriodicResidual));
            diagnostics = returned.Diagnostics;
            diagnostics.LegacyEquivalent = false;
            diagnostics.SourceApexResidual = base.Residual;
            evaluation = lmz.data.ProblemEvaluation(blocks, ...
                'Simulation', returned.Simulation, ...
                'Feasibility', feasibility, ...
                'PhysicalValidity', valid && base.PhysicalValidity && ...
                next.PhysicalValidity, 'Diagnostics', diagnostics);
        end

        function names = listObservables(obj)
            names = obj.ApexProblem.listObservables();
        end

        function solution = makeSolution(obj, u, p, evaluation)
            if nargin < 3 || isempty(p)
                p = obj.DefaultParameters;
            end
            if nargin < 4
                evaluation = [];
            end
            source = makeSolution@lmz.api.BaseProblem( ...
                obj, u, p, evaluation);
            data = source.toStruct();
            data.DecisionSchema = source.DecisionSchema;
            data.ParameterSchema = source.ParameterSchema;
            data.ResidualBlocks = source.ResidualBlocks;
            data.Classification = ...
                lmzmodels.slip_quadruped.GaitClassifier.classify(u);
            if ~isempty(evaluation) && ~isempty(evaluation.Simulation)
                data.Observables = evaluation.Simulation.Observables;
            end
            data.Lineage = localLineage(obj.Configuration, evaluation);
            data.Provenance = struct('source', ...
                'scientific-roadmap-configurable-section', ...
                'sourceCommit', ...
                '2c106101383ecee1b2a9d695efe09fbd72d5718a');
            solution = lmz.data.Solution(data);
        end
    end
end

function value = localLineage(configuration, evaluation)
value = struct('Operation', 'periodic_orbit_configuration', ...
    'Configuration', configuration);
if ~isempty(evaluation) && isfield(evaluation.Diagnostics, ...
        'StartSectionHash')
    value.StartSectionHash = evaluation.Diagnostics.StartSectionHash;
    value.StopSectionHash = evaluation.Diagnostics.StopSectionHash;
    value.SectionCatalogHash = evaluation.Diagnostics.SectionCatalogHash;
elseif ~isempty(evaluation) && isfield(evaluation.Diagnostics, ...
        'PeriodicOrbit')
    details = evaluation.Diagnostics.PeriodicOrbit;
    value.StartSectionHash = details.StartSectionHash;
    value.StopSectionHash = details.StopSectionHash;
    value.SectionCatalogHash = details.SectionCatalogHash;
end
end
