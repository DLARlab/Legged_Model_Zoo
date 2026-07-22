function report=run_round11_workbench_benchmarks(options)
%RUN_ROUND11_WORKBENCH_BENCHMARKS Measure registered-workflow GUI updates.
%   The benchmark uses one warm hidden workbench for update timings and a
%   fresh workbench for construction/layout-replacement timings.

if nargin<1,options=struct();end
repetitions=option(options,'Repetitions',3);
if ~(isnumeric(repetitions)&&isscalar(repetitions)&& ...
        isfinite(repetitions)&&repetitions>=1&&repetitions==fix(repetitions))
    error('lmz:Benchmarks:Repetitions', ...
        'Repetitions must be a positive integer.');
end

startup;
registry=lmz.registry.ModelRegistry.discover();
registryCleanup=onCleanup(@()delete(registry));
workflows=lmz.workflow.WorkflowRegistry.fromModelRegistry(registry);
context=lmz.api.RunContext.synchronous(11138);
namespace=temporaryNamespace();
preferences=lmz.gui.PreferencesStore('Namespace',namespace);
preferences.setLayoutProfile('scientific_workbench');
preferences.setWindowPosition([40 40 1120 740]);
controller=lmz.gui.AppController(registry,context);
controller.selectModel('slip_quadruped');
controller.selectWorkflow('roadmap_root_continuation');
application=lmz.gui.LeggedModelZooApp('Controller',controller, ...
    'Preferences',preferences,'Visible','off');
applicationCleanup=onCleanup(@()cleanApplication(application,preferences));
drawnow;

definitions={ ...
    definition('workbench_construction',@constructWorkbench,30, ...
        'hidden scientific_workbench at 1120 x 740'); ...
    definition('model_workflow_switch',@switchWorkflow,20, ...
        'biped model to registered quadruped RoadMap workflow'); ...
    definition('roadmap_all_branches_registered_load',@loadAllRoadMap,60, ...
        'registered RoadMap branch_catalog provider'); ...
    definition('branch_axis_change_with_overlays_20',@changeBranchAxes,20, ...
        'persistent source, locked, and edited overlay layers'); ...
    definition('branch_hover_updates_100',@hoverUpdates,15, ...
        'nearest-point updates on the registered RoadMap'); ...
    definition('sidebar_tab_switching_50',@switchSidebarTabs,20, ...
        'scrollable capability sidebar with persistent central axes'); ...
    definition('solve_progress_updates_100',@solveProgressUpdates,20, ...
        'typed snapshots delivered through presentation events'); ...
    definition('accepted_continuation_overlay_updates_20', ...
        @acceptedContinuationUpdates,20, ...
        'incremental accepted-solution overlay updates'); ...
    definition('minimum_size_resize_scroll_refresh_20', ...
        @resizeAndRefresh,20, ...
        '900 x 650 and preferred-size viewport refresh'); ...
    definition('classic_workbench_layout_switch_10',@switchLayouts,120, ...
        'host-neutral component teardown and reconstruction')};

records=repmat(emptyRecord(),numel(definitions),1);
for definitionIndex=1:numel(definitions)
    item=definitions{definitionIndex};samples=zeros(repetitions,1);
    for repeat=1:repetitions
        started=tic;value=item.Function();samples(repeat)=toc(started); %#ok<NASGU>
        clear value
    end
    records(definitionIndex)=emptyRecord();
    records(definitionIndex).Name=item.Name;
    records(definitionIndex).MedianSeconds=median(samples);
    records(definitionIndex).SpreadSeconds= ...
        median(abs(samples-median(samples)));
    records(definitionIndex).Samples=samples.';
    records(definitionIndex).BudgetSeconds=item.BudgetSeconds;
    records(definitionIndex).Fixture=item.Fixture;
    records(definitionIndex).WithinBudget= ...
        records(definitionIndex).MedianSeconds<= ...
        records(definitionIndex).BudgetSeconds;
    fprintf(['LMZ_ROUND11_BENCHMARK name=%s median=%.6f ' ...
        'spread=%.6f budget=%.3f\n'],item.Name, ...
        records(definitionIndex).MedianSeconds, ...
        records(definitionIndex).SpreadSeconds, ...
        records(definitionIndex).BudgetSeconds);
end
report=struct('schemaVersion','1.0.0', ...
    'frameworkVersion',lmz.util.Version.current(), ...
    'matlabRelease',version('-release'),'matlabVersion',version, ...
    'architecture',computer('arch'),'repetitions',repetitions, ...
    'measuredAt',lmz.compat.Timestamp.current(),'records',records, ...
    'notes',['Warm hidden-GUI timings. Budgets are conservative regression ' ...
    'ceilings, not latency targets.']);
if isfield(options,'OutputPath')&&~isempty(options.OutputPath)
    writeReport(options.OutputPath,report);
end
if any(~[records.WithinBudget])
    error('lmz:Benchmarks:Round11Budget', ...
        'A Round 11 workbench benchmark exceeded its budget.');
end
fprintf('LMZ_ROUND11_BENCHMARKS_OK records=%d\n',numel(records));
clear applicationCleanup registryCleanup

    function value=constructWorkbench()
        localNamespace=temporaryNamespace();
        localPreferences=lmz.gui.PreferencesStore( ...
            'Namespace',localNamespace);
        localPreferences.setLayoutProfile('scientific_workbench');
        localController=lmz.gui.AppController(registry, ...
            lmz.api.RunContext.synchronous(11139));
        localController.selectModel('slip_quadruped');
        localController.selectWorkflow('roadmap_root_continuation');
        localApp=lmz.gui.LeggedModelZooApp( ...
            'Controller',localController,'Preferences',localPreferences, ...
            'Visible','off');
        cleanup=onCleanup(@()cleanApplication( ...
            localApp,localPreferences));
        drawnow;
        value=localApp.WorkbenchShell.testHooks().Id;
        clear cleanup
    end

    function value=switchWorkflow()
        controller.selectModel('slip_biped');
        controller.selectModel('slip_quadruped');
        session=controller.selectWorkflow('roadmap_root_continuation');
        drawnow limitrate;
        value=struct('WorkflowId',session.Descriptor.Id, ...
            'PointIndex',session.SeedIndex);
    end

    function value=loadAllRoadMap()
        datasets=lmz.services.BranchService().loadAllDataSource( ...
            workflows,'slip_quadruped','roadmap');
        value=sum(cellfun(@(item)item.Branch.pointCount(),datasets));
    end

    function value=changeBranchAxes()
        ensureReferenceWorkflow();layout=scientificLayout();
        overlay=layout.OverlayController;dataset=controller.activeDataset();
        overlay.setBranch('source_branches',dataset.Branch);
        overlay.setSolution('locked_point',controller.lockedSolution());
        names={{'dx','dphi','y'},{'dx','y','dphi'}, ...
            {'dphi','y','dx'},{'y','dx','dphi'}};
        for update=1:20
            overlay.setAxisContext(names{1+mod(update-1,numel(names))}, ...
                mod(update,2)==0);
        end
        value=overlay.layerNames();
    end

    function value=hoverUpdates()
        ensureReferenceWorkflow();dataset=controller.activeDataset();
        x=dataset.Branch.coordinate('dx');y=dataset.Branch.coordinate('dphi');
        index=controller.State.LockedSelection.PointIndex;
        for update=1:100
            offset=mod(update-1,5)-2;
            target=[x(index)+offset*eps(x(index)) y(index)];
            controller.hoverNearestVisiblePoint({'dx','dphi'},target);
        end
        value=controller.State.HoverSelection.PointIndex;
    end

    function value=switchSidebarTabs()
        ensureReferenceWorkflow();sidebar=scientificLayout().SidebarHost;
        if isempty(controller.State.Simulation)
            controller.simulateWorkingSolution();drawnow;
        end
        simulation=application.tab('simulation');
        before=simulationGraphics(simulation);
        ids=fieldnames(sidebar.Tabs);
        for update=1:50
            sidebar.select(ids{1+mod(update-1,numel(ids))});
            drawnow limitrate;
        end
        after=simulationGraphics(simulation);
        if ~isequal(before,after)
            error('lmz:Benchmarks:RendererRebuilt', ...
                ['Sidebar switching reconstructed or reordered the ' ...
                'scientific renderer graphics.']);
        end
        value=struct('SelectedId',sidebar.selectedId(), ...
            'StableRendererGraphics',true, ...
            'RendererGraphicsCount',numel(after));
    end

    function value=solveProgressUpdates()
        ensureReferenceWorkflow();progress=lmz.data.SolveProgress();
        decision=controller.State.WorkingSolution.DecisionValues;
        for update=1:100
            snapshot=lmz.data.SolveIterationSnapshot(struct( ...
                'Stage','iteration','Iteration',update, ...
                'FunctionCount',2*update,'DecisionValues',decision, ...
                'ScaledResidual',10^(-min(update,12)/2), ...
                'StepNorm',1/update,'FirstOrderOptimality',1/update, ...
                'Accepted',true,'Message','Benchmark solve update.'));
            progress.record('iteration',snapshot);
            controller.State.SolveProgress=progress;
            drawnow limitrate;
        end
        value=progress.count();
    end

    function value=acceptedContinuationUpdates()
        ensureReferenceWorkflow();layout=scientificLayout();
        branch=controller.activeDataset().Branch;
        values=lmz.data.Solution.empty(0,1);
        for update=1:20
            values(end+1,1)=branch.point(update); %#ok<AGROW>
            layout.OverlayController.setSolutions( ...
                'accepted_continuation',values);
            drawnow limitrate;
        end
        value=numel(values);
    end

    function value=resizeAndRefresh()
        ensureReferenceWorkflow();sizes=[900 650;1120 740];
        for update=1:20
            sizeValue=sizes(1+mod(update-1,2),:);
            application.Figure.Position(3:4)=sizeValue;
            application.WorkbenchShell.refreshGeometry();
            drawnow limitrate;
        end
        value=application.Figure.Position(3:4);
    end

    function value=switchLayouts()
        figureHandle=uifigure('Visible','off', ...
            'Position',[40 40 1120 740]);
        cleanup=onCleanup(@()deleteIfValid(figureHandle));
        parent=uigridlayout(figureHandle,[1 1]);
        localPreferences=lmz.gui.PreferencesStore( ...
            'Namespace',temporaryNamespace());
        shell=lmz.gui.layout.WorkbenchShell(parent,controller, ...
            controller.Events,localPreferences, ...
            'ProfileId','scientific_workbench');
        shellCleanup=onCleanup(@()deleteIfValid(shell));
        for update=1:10
            if mod(update,2)==1,id='classic_tabs'; ...
            else,id='scientific_workbench';end
            shell.select(id);drawnow limitrate;
        end
        value=shell.Profile.Id;
        localPreferences.reset();clear shellCleanup cleanup
    end

    function ensureReferenceWorkflow()
        if ~strcmp(controller.State.ModelId,'slip_quadruped')|| ...
                ~strcmp(controller.State.WorkflowId, ...
                'roadmap_root_continuation')
            controller.selectModel('slip_quadruped');
            controller.selectWorkflow('roadmap_root_continuation');
        end
    end

    function value=scientificLayout()
        value=application.WorkbenchShell.Layout;
        if ~isa(value,'lmz.gui.layout.ScientificWorkbenchLayout')
            error('lmz:Benchmarks:Round11Layout', ...
                'The benchmark fixture is not the scientific workbench.');
        end
    end
end

function value=definition(name,functionHandle,budget,fixture)
value=struct('Name',name,'Function',functionHandle, ...
    'BudgetSeconds',budget,'Fixture',fixture);
end

function value=emptyRecord()
value=struct('Name','','MedianSeconds',0,'SpreadSeconds',0, ...
    'Samples',[],'BudgetSeconds',0,'Fixture','','WithinBudget',false);
end

function value=option(options,name,fallback)
if isfield(options,name),value=options.(name);else,value=fallback;end
end

function value=temporaryNamespace()
[~,token]=fileparts(tempname);
value=['LMZRound11Benchmark' regexprep(token,'[^A-Za-z0-9]','')];
end

function cleanApplication(application,preferences)
deleteIfValid(application);preferences.reset();
end

function deleteIfValid(value)
if ~isempty(value)&&isvalid(value),delete(value);end
end

function writeReport(path,report)
path=lmz.compat.Text.character(path,'benchmark output path');
[folder,~,~]=fileparts(path);if isempty(folder),folder=pwd;end
temporary=lmz.compat.Files.temporary(folder,'.json');
cleanup=onCleanup(@()deleteIfPresent(temporary));
file=fopen(temporary,'w');
if file<0,error('lmz:Benchmarks:Output','Could not open output.');end
fileCleanup=onCleanup(@()fclose(file));
fprintf(file,'%s\n',lmz.compat.Json.encode(report,true));clear fileCleanup
lmz.compat.Files.atomicMove(temporary,path);clear cleanup
end

function deleteIfPresent(path)
if exist(path,'file')==2,delete(path);end
end

function values=simulationGraphics(component)
axesHandles=[component.Axes component.TorsoAxes component.BackLegAxes ...
    component.FrontLegAxes component.GRFAxes component.OscillatorAxes];
values=gobjects(0,1);
for index=1:numel(axesHandles)
    values=[values;findall(axesHandles(index))]; %#ok<AGROW>
end
end
