classdef PoincareReturnService
    %POINCARERETURNSERVICE Catalog-driven section return over public models.
    methods
        function result=simulate(obj,model,source,configuration,context)
            result=obj.evaluate(model,source,configuration,context);
        end

        function result=evaluate(obj,model,source,configuration,context)
            if nargin<4||isempty(configuration),configuration=struct();end
            if nargin<5||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if ~isa(model,'lmz.api.LeggedModel')||~isstruct(configuration)
                error('lmz:Poincare:ReturnServiceInput', ...
                    'Poincare return requires a model and configuration.');
            end
            [problemId,decision,parameters,simulation]= ...
                obj.simulationFor(model,source,configuration,context);
            registry=lmz.registry.ModelRegistry.discover();
            modelId=model.getManifest().id;
            sections=registry.getPoincareSectionRegistry(modelId);
            default=sections.defaultSection(problemId);
            startId=fieldOr(configuration,'StartSectionId',default.Id);
            stopId=fieldOr(configuration,'StopSectionId',default.Id);
            start=obj.configuredSection(sections.section(startId), ...
                configuration,'Start',simulation.StateSchema);
            stop=obj.configuredSection(sections.section(stopId), ...
                configuration,'Stop',simulation.StateSchema);
            symmetry=sections.symmetryFor(stopId);
            if isfield(configuration,'SymmetryId')&& ...
                    strcmp(configuration.SymmetryId,'identity')
                symmetry=lmz.poincare.IdentitySymmetry();
            end
            defaultSection=sections.section(default.Id);
            startCrossing=[];startDiagnostics=struct( ...
                'RequestedStartSectionId',start.Id, ...
                'RequestedStartStateSide',start.StateSide, ...
                'TrajectoryRephased',false,'PhysicalOrbitMaxError',0);
            if ~strcmp(start.Id,defaultSection.Id)|| ...
                    ~strcmp(start.StateSide,defaultSection.StateSide)
                startSymmetry=sections.symmetryFor(start.Id);
                [simulation,located,orbitError,preserved]= ...
                    lmz.services.SectionTransferService. ...
                    rephaseSimulationToSection( ...
                    simulation,start,startSymmetry);
                startCrossing=atTimeZero(located);
                startDiagnostics.TrajectoryRephased=true;
                startDiagnostics.SourceCrossingTime=located.Time;
                startDiagnostics.PhysicalOrbitMaxError=orbitError;
                startDiagnostics.PhaseInvariantObservablesPreserved=preserved;
            end
            stride=lmz.poincare.StrideDefinition(struct( ...
                'StartSectionId',start.Id,'StartStateSide',start.StateSide, ...
                'StopSectionId',stop.Id,'StopStateSide',stop.StateSide, ...
                'CrossingDirection',stop.CrossingDirection, ...
                'MinimumReturnTime',stop.MinimumReturnTime, ...
                'RequiredEventSequence',{stop.RequiredEventSequence}, ...
                'ReturnOccurrence',stop.ReturnOccurrence, ...
                'SymmetryId',symmetry.Id, ...
                'StartSectionHash',start.Descriptor.fingerprint(), ...
                'StopSectionHash',stop.Descriptor.fingerprint()));
            map=lmz.poincare.PoincareReturnMap(start,stop,symmetry, ...
                simulation.StateSchema,stride);
            initial=simulation.States(1,:).';
            result=map.evaluate(initial,parameters, ...
                @(~,~,~,~)struct('Simulation',simulation, ...
                'StartCrossing',startCrossing, ...
                'Diagnostics',struct('ProblemId',problemId, ...
                'DecisionValues',decision,'CatalogHash',sections.CatalogHash, ...
                'InitialRootSuppressed',true, ...
                'StartSectionInitialization',startDiagnostics)),context);
        end
    end

    methods (Access=private)
        function [problemId,decision,parameters,simulation]= ...
                simulationFor(~,model,source,configuration,context)
            if isa(source,'lmz.data.Solution')
                problemId=source.ProblemId;decision=source.DecisionValues;
                parameters=source.ParameterValues;
            else
                problemId=fieldOr(configuration,'ProblemId','');
                if isempty(problemId),problemId=model.listProblems();problemId=problemId{1};end
                problem=model.createProblem(problemId,configuration);
                decision=problem.getDecisionSchema().defaults();
                parameters=problem.getParameterSchema().defaults();
                if isnumeric(source)&&~isempty(source),decision=source(:);end
                if isfield(configuration,'DecisionValues')
                    decision=configuration.DecisionValues(:);
                end
                if isfield(configuration,'ParameterValues')
                    parameters=configuration.ParameterValues(:);
                end
            end
            problem=model.createProblem(problemId,configuration);
            if isa(problem,'lmz.api.NonlinearEquationProblem')
                evaluation=problem.evaluate(decision,parameters,context,true);
                simulation=evaluation.Simulation;
            elseif ismethod(problem,'simulateDecision')
                simulation=problem.simulateDecision(decision,context);
            else
                request=lmz.api.SimulationRequest(model.getManifest().id, ...
                    problemId,source,struct());
                simulation=model.simulate(request,context);
            end
            if ~isa(simulation,'lmz.api.SimulationResult')
                error('lmz:Poincare:ReturnSimulation', ...
                    'Selected problem did not return a SimulationResult.');
            end
        end

        function section=configuredSection(~,section,configuration,prefix,schema)
            descriptor=section.toStruct();
            fields={'StateSide','CrossingDirection','MinimumReturnTime', ...
                'RequiredEventSequence','ReturnOccurrence'};
            targets={'stateSide','crossingDirection','minimumReturnTime', ...
                'requiredEventSequence','returnOccurrence'};
            for index=1:numel(fields)
                name=[prefix fields{index}];
                if isfield(configuration,name)
                    descriptor.(targets{index})=configuration.(name);
                elseif strcmp(prefix,'Stop')&&isfield(configuration,fields{index})
                    descriptor.(targets{index})=configuration.(fields{index});
                end
            end
            descriptor=lmz.poincare.PoincareSectionDescriptor(descriptor);
            if strcmp(descriptor.Kind,'named_event')
                section=lmz.poincare.NamedEventSection(descriptor);
            elseif strcmp(descriptor.Kind,'state_plane')
                section=lmz.poincare.StateFunctionSection(descriptor,schema);
            elseif isa(section,'lmz.poincare.CompositeSection')
                section=lmz.poincare.CompositeSection( ...
                    descriptor,section.Primary,section.Conditions);
            end
        end
    end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end

function value=atTimeZero(source)
metadata=source.Metadata;
metadata.SourceCrossingTime=source.Time;
metadata.RephasedTimeOrigin=true;
value=lmz.poincare.SectionCrossing(source.SectionId,0, ...
    'EventId',source.EventId,'ModeBefore',source.ModeBefore, ...
    'ModeAfter',source.ModeAfter,'PreState',source.PreState, ...
    'PostState',source.PostState,'StateSide',source.StateSide, ...
    'Value',source.Value, ...
    'DirectionalDerivative',source.DirectionalDerivative, ...
    'CrossingDirection',source.CrossingDirection, ...
    'Grazing',source.Grazing,'Occurrence',1,'Accepted',true, ...
    'Metadata',metadata);
end
