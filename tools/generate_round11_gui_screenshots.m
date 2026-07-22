function paths=generate_round11_gui_screenshots(outputDirectory)
%GENERATE_ROUND11_GUI_SCREENSHOTS Create clearly automated workbench captures.
% These images are deterministic batch evidence, not human desktop approval.
if nargin<1||isempty(outputDirectory)
    outputDirectory=fullfile(lmz.util.ProjectPaths.root(), ...
        'docs','images','round11');
end
if exist(outputDirectory,'dir')~=7,mkdir(outputDirectory);end
namespace=['LMZRound11Capture' regexprep(tempname,'[^A-Za-z0-9]','')];
preferences=lmz.gui.PreferencesStore('Namespace',namespace);
preferences.setLayoutProfile('scientific_workbench');
preferences.setWindowPosition([40 40 1460 900]);
app=lmz.gui.LeggedModelZooApp('Preferences',preferences,'Visible','off');
cleanup=onCleanup(@()clean(app,preferences));
paths={};

paths{end+1}=capture(app,outputDirectory, ...
    '01_workbench_initial_roadmap_automated.png');

app.Controller.selectByIndex(268);drawnow;
paths{end+1}=capture(app,outputDirectory, ...
    '02_workbench_locked_solution_automated.png');

layout=app.WorkbenchShell.Layout;
layout.SidebarHost.select('solve_seeds');
progress=lmz.data.SolveProgress();
snapshot=lmz.data.SolveIterationSnapshot(struct( ...
    'Stage','iteration','Iteration',4,'FunctionCount',11, ...
    'DecisionValues',app.Controller.State.WorkingSolution.DecisionValues, ...
    'ScaledResidual',2.5e-5,'StepNorm',8e-4, ...
    'FirstOrderOptimality',3.2e-5,'Accepted',true, ...
    'Message','Automated live-progress capture'));
progress.record('iteration',snapshot);
app.Controller.State.SolveProgress=progress;drawnow;
paths{end+1}=capture(app,outputDirectory, ...
    '03_workbench_live_solve_automated.png');

layout.OverlayController.clearLayer('current_solver_iterate');
app.Controller.State.SolveProgress=[];drawnow;
pair=app.Controller.makeAdjacentSeedPair(1,struct());drawnow;
paths{end+1}=capture(app,outputDirectory, ...
    '04_workbench_seed_pair_automated.png');

layout.SidebarHost.select('continuation');
prediction=struct('PointIndex',3,'StepSize',pair.AchievedRadius, ...
    'DecisionValues',pair.Second.DecisionValues, ...
    'Prediction',pair.Second.DecisionValues,'Direction',1);
app.Controller.setContinuationPreview(struct( ...
    'Phase','prediction','State',prediction));drawnow;
accepted=prediction;accepted.Solution=pair.Second;accepted.ResidualNorm=0;
accepted.CorrectedDecision=pair.Second.DecisionValues;
app.Controller.setContinuationPreview(struct( ...
    'Phase','accepted','State',accepted));drawnow;
paths{end+1}=capture(app,outputDirectory, ...
    '05_workbench_live_continuation_automated.png');

app.Controller.setContinuationPreview([]);drawnow;
app.Controller.simulateWorkingSolution();drawnow;
layout.SidebarHost.select('visualization');
layout.SidebarHost.Viewports.visualization.setScrollPosition([100 0]);
drawnow;
paths{end+1}=capture(app,outputDirectory, ...
    '06_workbench_physical_visualization_automated.png');

app.Figure.Position=[40 40 900 650];drawnow;
layout.SidebarHost.select('continuation');
layout.SidebarHost.Viewports.continuation.setScrollPosition([0 300]);
drawnow;
paths{end+1}=capture(app,outputDirectory, ...
    '07_workbench_minimum_scrolled_sidebar_automated.png');

app.Figure.Position=[40 40 1460 900];drawnow;
app.LayoutDropDown.Value='classic_tabs';
callback=app.LayoutDropDown.ValueChangedFcn;
callback(app.LayoutDropDown,[]);drawnow;
app.WorkbenchShell.Layout.TabGroup.SelectedTab=app.tab('branches').Root;
drawnow;
paths{end+1}=capture(app,outputDirectory, ...
    '08_classic_layout_fallback_automated.png');
clear cleanup
end

function path=capture(app,folder,name)
path=fullfile(folder,name);drawnow;
wasVisible=app.Figure.Visible;app.Figure.Visible='on';drawnow;
cleanup=onCleanup(@()set(app.Figure,'Visible',wasVisible));
app.WorkbenchShell.refreshGeometry();drawnow;
lmz.compat.Graphics.exportFigure(app.Figure,path);
clear cleanup
end

function clean(app,preferences)
if ~isempty(app)&&isvalid(app),delete(app);end
preferences.reset();
end
