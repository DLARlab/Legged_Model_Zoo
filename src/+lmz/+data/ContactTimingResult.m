classdef ContactTimingResult
    %CONTACTTIMINGRESULT Reproducible result of an explicit timing-only solve.
    properties (SetAccess=private)
        ModelId
        ProblemId
        FixedInitialState
        FixedPhysicalParameters
        InputSchedule
        SolvedSchedule
        FreeMask
        FixedMask
        ContactResiduals
        SectionResidual
        TerminalState
        SectionCrossing
        Simulation
        SolverDiagnostics
        RandomSeed
        Provenance
    end

    methods
        function obj=ContactTimingResult(value)
            names=properties(obj);
            for index=1:numel(names)
                if ~isfield(value,names{index})
                    error('lmz:Timing:ResultField', ...
                        'ContactTimingResult is missing %s.',names{index});
                end
                obj.(names{index})=value.(names{index});
            end
            if ~isa(obj.InputSchedule,'lmz.schedule.EventSchedule')|| ...
                    ~isa(obj.SolvedSchedule,'lmz.schedule.EventSchedule')
                error('lmz:Timing:ResultSchedule', ...
                    'Timing result schedules are invalid.');
            end
            if ~isnumeric(obj.FixedInitialState)||~isreal(obj.FixedInitialState)|| ...
                    ~isvector(obj.FixedInitialState)|| ...
                    ~isnumeric(obj.FixedPhysicalParameters)|| ...
                    ~isreal(obj.FixedPhysicalParameters)|| ...
                    ~isvector(obj.FixedPhysicalParameters)|| ...
                    any(~isfinite(obj.FixedInitialState(:)))|| ...
                    any(~isfinite(obj.FixedPhysicalParameters(:)))
                error('lmz:Timing:ResultFixedData', ...
                    'Timing result fixed data are invalid.');
            end
            if ~islogical(obj.FreeMask)||~islogical(obj.FixedMask)|| ...
                    ~isequal(size(obj.FreeMask),size(obj.FixedMask))|| ...
                    any(obj.FreeMask(:)==obj.FixedMask(:))
                error('lmz:Timing:ResultMask', ...
                    'Timing fixed/free masks must be complementary logical data.');
            end
        end

        function value=toStruct(obj)
            value=struct(); names=properties(obj);
            for index=1:numel(names), value.(names{index})=obj.(names{index}); end
            value.InputSchedule=obj.InputSchedule.toStruct();
            value.SolvedSchedule=obj.SolvedSchedule.toStruct();
            value.SectionCrossing=obj.serializable(obj.SectionCrossing);
            if isa(obj.Simulation,'lmz.api.SimulationResult')
                value.Simulation=obj.Simulation.toStruct();
            end
        end

        function artifact=toArtifact(obj)
            artifact=lmz.io.ArtifactStore.workflowBase( ...
                obj.ModelId,obj.ProblemId);
            artifact.artifactType='contact-timing-run';
            artifact.diagnostics=obj.SolverDiagnostics;
            artifact.lineage=struct('Workflow','contact_timing_only');
            artifact.contactTimingResult=obj.toStruct();
            sectionIds={obj.InputSchedule.StartSectionId, ...
                obj.InputSchedule.StopSectionId};
            artifact.poincareMetadata=lmz.io.ArtifactStore.sectionMetadata( ...
                obj.ModelId,sectionIds);
            configuration=struct('InitialState',obj.FixedInitialState, ...
                'PhysicalParameters',obj.FixedPhysicalParameters, ...
                'EventSchedule',obj.InputSchedule.toStruct(), ...
                'StartSectionId',obj.InputSchedule.StartSectionId, ...
                'StopSectionId',obj.InputSchedule.StopSectionId);
            artifact.problemMetadata.configuration=configuration;
            sourceHashes=struct();
            relative=artifact.poincareMetadata.CatalogRelativePath;
            if ~isempty(relative)
                sourceHashes.PoincareCatalog=struct( ...
                    'relativePath',relative,'sha256', ...
                    artifact.poincareMetadata.CatalogHash);
            end
            options=struct();
            if isfield(obj.SolverDiagnostics,'Options')
                options=obj.SolverDiagnostics.Options;
            end
            exitFlag=fieldOr(obj.SolverDiagnostics,'ExitFlag',0);
            reason='solver-stopped';if exitFlag>0,reason='converged';end
            output=fieldOr(obj.SolverDiagnostics,'Output',struct());
            evaluations=fieldOr(output,'funcCount',NaN);
            details=struct('Options',options, ...
                'SourceSeed',obj.InputSchedule.toStruct(), ...
                'RandomSeed',obj.RandomSeed,'Provenance',obj.Provenance, ...
                'FunctionEvaluations',evaluations, ...
                'TerminationReason',reason,'Warnings',{{}}, ...
                'SourceDataHashes',sourceHashes);
            artifact=lmz.io.ArtifactStore.withRunMetadata(artifact,details);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            value.InputSchedule=lmz.schedule.EventSchedule.fromStruct(value.InputSchedule);
            value.SolvedSchedule=lmz.schedule.EventSchedule.fromStruct(value.SolvedSchedule);
            if isstruct(value.SectionCrossing)&& ...
                    isfield(value.SectionCrossing,'sectionId')
                value.SectionCrossing= ...
                    lmz.poincare.SectionCrossing.fromStruct( ...
                    value.SectionCrossing);
            end
            if isstruct(value.Simulation)&&isfield(value.Simulation,'time')
                value.Simulation=lmz.api.SimulationResult.fromStruct( ...
                    value.Simulation);
            end
            obj=lmz.data.ContactTimingResult(value);
        end

        function obj=fromArtifact(artifact)
            lmz.io.ArtifactStore.validate(artifact);
            if ~strcmp(artifact.artifactType,'contact-timing-run')
                error('lmz:Timing:ArtifactType', ...
                    'Artifact is not a contact timing run.');
            end
            obj=lmz.data.ContactTimingResult.fromStruct( ...
                artifact.contactTimingResult);
        end
    end

    methods (Static, Access=private)
        function value=serializable(item)
            if isobject(item)&&ismethod(item,'toStruct'), value=item.toStruct(); ...
            else, value=item; end
        end
    end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name); ...
else,value=fallback;end
end
