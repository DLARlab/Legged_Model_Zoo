classdef ScientificWorkbenchLayout < handle
    %SCIENTIFICWORKBENCHLAYOUT Source-inspired persistent branch workbench.
    properties (SetAccess=private)
        Root
        Viewport
        MainGrid
        DataRegion
        WorkspaceCanvas
        SidebarHost
        StatusDock
        StatusPanel
        ComponentMap = struct()
        OverlayController
        TabGroup
        Profile
        ColumnRatio = [3.35 1.85]
        FootfallAxes
        RunOverlayAxes
        AnalysisWorkspace
        Contribution
    end
    properties (Access=private)
        Preferences
        ComponentHosts = struct()
        StagingPanel
        IsDisposed = false
        IsRefreshingGeometry = false
    end

    methods
        function obj=ScientificWorkbenchLayout(parent,controller,eventBus,preferences,varargin)
            parser=inputParser;
            addParameter(parser,'ErrorHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            addParameter(parser,'StatusHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            parse(parser,varargin{:});
            obj.Preferences=preferences;
            obj.Profile=lmz.gui.layout.LayoutProfileRegistry.get( ...
                'scientific_workbench');
            obj.Contribution=controller.workbenchContribution();
            obj.ColumnRatio=obj.preferenceColumnRatio();
            obj.Viewport=lmz.gui.layout.ScrollableViewport(parent, ...
                'MinimumSize',[1120 590],'Tag','lmz-workbench-scroll');
            obj.Root=obj.Viewport.Root;
            obj.MainGrid=uigridlayout(obj.Viewport.Content.Root,[3 2]);
            obj.MainGrid.RowHeight={'fit','1x',93};
            obj.MainGrid.ColumnWidth={ratioText(obj.ColumnRatio(1)), ...
                ratioText(obj.ColumnRatio(2))};
            obj.MainGrid.Padding=[12 12 12 12];
            obj.MainGrid.RowSpacing=10;obj.MainGrid.ColumnSpacing=12;

            obj.DataRegion=uipanel(obj.MainGrid,'Title','Data Info', ...
                'Tag','lmz-workbench-data-info');
            place(obj.DataRegion,1,1);
            dataHost=uigridlayout(obj.DataRegion,[1 1]);
            dataHost.Padding=[4 4 4 4];

            obj.WorkspaceCanvas=lmz.gui.layout.WorkspaceCanvas(obj.MainGrid, ...
                'SelectionHandler',@(id)obj.centralViewChanged(id));
            place(obj.WorkspaceCanvas.Root,2,1);
            centralViews=obj.Contribution.CentralViews;
            if ~any(strcmp(centralViews,'branch_state'))
                centralViews=[{'branch_state'} centralViews];
            end
            branchParent=[];obj.FootfallAxes=[];obj.RunOverlayAxes=[];
            for viewIndex=1:numel(centralViews)
                viewId=centralViews{viewIndex};
                viewParent=obj.WorkspaceCanvas.addView( ...
                    viewId,centralViewTitle(viewId));
                switch viewId
                    case 'branch_state'
                        branchParent=viewParent;
                    case 'hildebrand_footfall'
                        obj.FootfallAxes=uiaxes(viewParent, ...
                            'Tag','lmz-workbench-footfall-axes');
                    case 'run_overlay'
                        obj.RunOverlayAxes=uiaxes(viewParent, ...
                            'Tag','lmz-workbench-run-overlay-axes');
                    otherwise
                        buildContributedView(viewParent,viewId);
                end
            end
            obj.AnalysisWorkspace= ...
                lmz.gui.workspace.CentralAnalysisWorkspace(controller, ...
                obj.FootfallAxes,obj.RunOverlayAxes);

            obj.SidebarHost=lmz.gui.layout.SidebarHost(obj.MainGrid, ...
                'SelectionHandler',@(id)obj.sidebarChanged(id));
            obj.TabGroup=obj.SidebarHost.TabGroup;
            place(obj.SidebarHost.Root,[1 3],2);
            obj.StagingPanel=uipanel(obj.Viewport.Content.Root, ...
                'BorderType','none','Visible','off', ...
                'Position',[1 1 1 1],'Tag','lmz-workbench-staging');
            sidebarIds=unique([obj.Contribution.SidebarPanels ...
                obj.Contribution.AnalysisPlugins],'stable');
            sidebarConstructionFloor=[320 320];
            infoParent=optionalSidebarParent(obj.SidebarHost, ...
                obj.StagingPanel,sidebarIds,'info_selection', ...
                'Info / Selection',sidebarConstructionFloor);
            visualizationParent=optionalSidebarParent(obj.SidebarHost, ...
                obj.StagingPanel,sidebarIds,'visualization', ...
                'Visualization',sidebarConstructionFloor);
            solveParent=optionalSidebarParent(obj.SidebarHost, ...
                obj.StagingPanel,sidebarIds,'solve_seeds', ...
                'Solve / Seeds',sidebarConstructionFloor);
            continuationParent=optionalSidebarParent(obj.SidebarHost, ...
                obj.StagingPanel,sidebarIds,'continuation', ...
                'Continuation',sidebarConstructionFloor);
            optimizationParent=optionalSidebarParent(obj.SidebarHost, ...
                obj.StagingPanel,sidebarIds,'optimization', ...
                'Optimization',sidebarConstructionFloor);
            analysisParent=optionalSidebarParent(obj.SidebarHost, ...
                obj.StagingPanel,sidebarIds,'oscillator_analysis', ...
                'Oscillator / Analysis',sidebarConstructionFloor);
            shootingParent=optionalSidebarParent(obj.SidebarHost, ...
                obj.StagingPanel,sidebarIds, ...
                'advanced_shooting_horizon', ...
                'Advanced Shooting / Horizon',sidebarConstructionFloor);
            known={'info_selection','visualization','solve_seeds', ...
                'continuation','optimization','oscillator_analysis', ...
                'advanced_shooting_horizon'};
            contributed=setdiff(sidebarIds,known,'stable');
            for panelIndex=1:numel(contributed)
                panelId=contributed{panelIndex};
                panelParent=obj.SidebarHost.addTab(panelId, ...
                    contributionTitle(panelId),sidebarConstructionFloor);
                buildContributedPanel(panelParent,panelId);
            end

            infoGrid=hostGrid(infoParent,[2 1]);
            infoGrid.RowHeight={280,'1x'};
            branchInfoHost=uigridlayout(infoGrid,[1 1]);
            branchInfoHost.Padding=[4 4 4 4];place(branchInfoHost,1,1);
            solutionHost=uigridlayout(infoGrid,[1 1]);
            solutionHost.Padding=[0 0 0 0];place(solutionHost,2,1);
            visualizationHost=hostGrid(visualizationParent,[1 1]);
            analysisHost=hostGrid(analysisParent,[1 1]);
            solveHost=hostGrid(solveParent,[1 1]);
            shootingHost=hostGrid(shootingParent,[1 1]);
            continuationHost=hostGrid(continuationParent,[1 1]);
            optimizationHost=hostGrid(optimizationParent,[1 1]);
            simulationInitial=preferredHost(sidebarIds, ...
                'visualization',visualizationHost,analysisHost);
            solveInitial=preferredHost(sidebarIds, ...
                'solve_seeds',solveHost,shootingHost);
            obj.ComponentHosts=struct( ...
                'visualization',visualizationHost, ...
                'oscillator_analysis',analysisHost, ...
                'solve_seeds',solveHost, ...
                'advanced_shooting_horizon',shootingHost);

            obj.OverlayController=lmz.gui.branch.BranchOverlayController();
            args={'ErrorHandler',parser.Results.ErrorHandler, ...
                'StatusHandler',parser.Results.StatusHandler};
            placement=struct('DataParent',dataHost, ...
                'InfoParent',branchInfoHost);
            % Keep the stable BranchTab class as the compatibility wrapper;
            % HostMode makes the same implementation a workspace component.
            obj.ComponentMap.branches=lmz.gui.tabs.BranchTab( ...
                branchParent,controller,eventBus,preferences,args{:}, ...
                'HostMode','workspace', ...
                'OverlayController',obj.OverlayController, ...
                'Placement',placement);
            obj.ComponentMap.solution=lmz.gui.workspace.SolutionWorkspace( ...
                solutionHost,controller,eventBus,preferences,args{:});
            obj.ComponentMap.simulation=lmz.gui.workspace.SimulationWorkspace( ...
                simulationInitial,controller,eventBus,preferences,args{:});
            obj.ComponentMap.solve=lmz.gui.workspace.SolveWorkspace( ...
                solveInitial,controller,eventBus,preferences,args{:}, ...
                'OverlayController',obj.OverlayController);
            obj.ComponentMap.continuation= ...
                lmz.gui.workspace.ContinuationWorkspace(continuationHost, ...
                controller,eventBus,preferences,args{:}, ...
                'OverlayController',obj.OverlayController);
            obj.ComponentMap.optimization= ...
                lmz.gui.workspace.OptimizationWorkspace(optimizationHost, ...
                controller,eventBus,preferences,args{:});

            obj.StatusDock=lmz.gui.layout.StatusDock(obj.MainGrid);
            place(obj.StatusDock.Root,3,1);obj.StatusPanel=obj.StatusDock.Panel;
            obj.restoreSelections();
            obj.SidebarHost.setSharedMinimumGroups({ ...
                {'visualization','oscillator_analysis'}, ...
                {'solve_seeds','advanced_shooting_horizon'}});
            obj.SidebarHost.fitContentsToControls(sidebarConstructionFloor);
            obj.refreshGeometry();
            obj.refreshAnalysisViews(true);
            % The scroll viewport observes the effective client size after
            % any operating-system window cap.  Route that active callback
            % through the complete relayout, not only content resizing.
            obj.Viewport.Root.SizeChangedFcn=@(~,~)obj.refreshGeometry();
        end

        function setCapabilities(obj,value)
            values=struct2cell(obj.ComponentMap);
            for index=1:numel(values),values{index}.setCapabilities(value);end
            setNamedTabCapability(obj.SidebarHost.Tabs,'visualization', ...
                capability(value,'simulate'));
            setNamedTabCapability(obj.SidebarHost.Tabs,'solve_seeds', ...
                capability(value,'solve'));
            setNamedTabCapability(obj.SidebarHost.Tabs,'continuation', ...
                capability(value,'continue'));
            setNamedTabCapability(obj.SidebarHost.Tabs,'optimization', ...
                capability(value,'optimize'));
            setNamedTabCapability(obj.SidebarHost.Tabs, ...
                'oscillator_analysis', ...
                capability(value,'simulate'));
            setNamedTabCapability(obj.SidebarHost.Tabs, ...
                'advanced_shooting_horizon', ...
                capability(value,'solve'));
        end

        function refreshGeometry(obj)
            if obj.IsDisposed||obj.IsRefreshingGeometry|| ...
                    isempty(obj.Viewport)||~isvalid(obj.Viewport)
                return
            end
            obj.IsRefreshingGeometry=true;
            try
                obj.Viewport.refresh();
                active=refreshReadOnlyGridExtent(obj.MainGrid, ...
                    obj.Viewport.Content.Root);
                if ~active
                    if isvalid(obj),obj.IsRefreshingGeometry=false;end
                    return
                end
                values=struct2cell(obj.SidebarHost.Viewports);
                for index=1:numel(values),values{index}.refresh();end
            catch exception
                if isvalid(obj),obj.IsRefreshingGeometry=false;end
                rethrow(exception)
            end
            obj.IsRefreshingGeometry=false;
        end

        function refreshAnalysisViews(obj,force)
            if nargin<2,force=false;end
            if isempty(obj.WorkspaceCanvas)||~isvalid(obj.WorkspaceCanvas)|| ...
                    isempty(obj.AnalysisWorkspace)|| ...
                    ~isvalid(obj.AnalysisWorkspace)
                return
            end
            obj.AnalysisWorkspace.refresh( ...
                obj.WorkspaceCanvas.selectedId(),force);
        end

        function hooks=testHooks(obj)
            hooks=struct('Id',obj.Profile.Id,'Root',obj.Root, ...
                'Viewport',obj.Viewport,'MainGrid',obj.MainGrid, ...
                'ColumnRatio',obj.ColumnRatio,'DataRegion',obj.DataRegion, ...
                'WorkspaceCanvas',obj.WorkspaceCanvas, ...
                'SidebarHost',obj.SidebarHost,'StatusDock',obj.StatusDock.Root, ...
                'Components',obj.ComponentMap, ...
                'AnalysisWorkspace',obj.AnalysisWorkspace, ...
                'OverlayController',obj.OverlayController);
        end

        function delete(obj)
            if obj.IsDisposed,return,end
            obj.IsDisposed=true;
            if ~isempty(obj.Viewport)&&isvalid(obj.Viewport)&& ...
                    ~isempty(obj.Viewport.Root)&&isvalid(obj.Viewport.Root)
                obj.Viewport.Root.SizeChangedFcn=[];
            end
            names=fieldnames(obj.ComponentMap);
            for index=1:numel(names)
                component=obj.ComponentMap.(names{index});
                if ~isempty(component)&&isvalid(component),component.dispose();end
            end
            obj.ComponentMap=struct();
            if ~isempty(obj.AnalysisWorkspace)&&isvalid(obj.AnalysisWorkspace)
                obj.AnalysisWorkspace.dispose();
            end
            obj.AnalysisWorkspace=[];
            if ~isempty(obj.OverlayController)&&isvalid(obj.OverlayController)
                delete(obj.OverlayController);
            end
            obj.OverlayController=[];
            if ~isempty(obj.StatusDock)&&isvalid(obj.StatusDock),delete(obj.StatusDock);end
            obj.StatusDock=[];obj.StatusPanel=[];
            if ~isempty(obj.WorkspaceCanvas)&&isvalid(obj.WorkspaceCanvas)
                delete(obj.WorkspaceCanvas);
            end
            obj.WorkspaceCanvas=[];
            if ~isempty(obj.SidebarHost)&&isvalid(obj.SidebarHost)
                delete(obj.SidebarHost);
            end
            obj.SidebarHost=[];
            obj.ComponentHosts=struct();obj.StagingPanel=[];
            if ~isempty(obj.Viewport)&&isvalid(obj.Viewport),delete(obj.Viewport);end
            obj.Viewport=[];obj.Root=[];obj.MainGrid=[];obj.TabGroup=[];
            obj.FootfallAxes=[];obj.RunOverlayAxes=[];
        end
    end

    methods (Access=private)
        function value=preferenceColumnRatio(obj)
            value=obj.Profile.SidebarRatio;
            if ~ismethod(obj.Preferences,'sidebarWidthRatio'),return,end
            try
                right=obj.Preferences.sidebarWidthRatio( ...
                    value(2)/sum(value));
                if isnumeric(right)&&isscalar(right)&&right>0&&right<1
                    defaultRight=value(2)/sum(value);
                    if abs(right-defaultRight)>10*eps(defaultRight)
                        value=[1-right right];
                    end
                end
            catch
            end
        end

        function restoreSelections(obj)
            sidebar='info_selection';central='branch_state';
            if ismethod(obj.Preferences,'sidebarTab')
                try
                    sidebar=obj.Preferences.sidebarTab(sidebar);
                catch
                end
            end
            if ismethod(obj.Preferences,'centralViewTab')
                try
                    central=obj.Preferences.centralViewTab(central);
                catch
                end
            end
            obj.SidebarHost.select(sidebar);obj.WorkspaceCanvas.select(central);
        end

        function sidebarChanged(obj,id)
            switch id
                case {'visualization','oscillator_analysis'}
                    if isfield(obj.ComponentHosts,id)&& ...
                            isfield(obj.ComponentMap,'simulation')
                        rehost(obj.ComponentMap.simulation.Root, ...
                            obj.ComponentHosts.(id));
                    end
                case {'solve_seeds','advanced_shooting_horizon'}
                    if isfield(obj.ComponentHosts,id)&& ...
                            isfield(obj.ComponentMap,'solve')
                        rehost(obj.ComponentMap.solve.Root, ...
                            obj.ComponentHosts.(id));
                    end
            end
            if ~isempty(id)&&ismethod(obj.Preferences,'setSidebarTab')
                try
                    obj.Preferences.setSidebarTab(id);
                catch
                end
            end
        end

        function centralViewChanged(obj,id)
            if ~isempty(id)&&ismethod(obj.Preferences,'setCentralViewTab')
                try
                    obj.Preferences.setCentralViewTab(id);
                catch
                end
            end
            obj.refreshAnalysisViews();
        end
    end
end

function grid=hostGrid(parent,sizeValue)
grid=uigridlayout(parent,sizeValue);grid.Padding=[0 0 0 0];
grid.RowSpacing=0;grid.ColumnSpacing=0;
end
function value=centralViewTitle(id)
switch id
    case 'branch_state',value='Branch / State Plot';
    case 'hildebrand_footfall',value='Hildebrand / Footfall';
    case 'run_overlay',value='Run Overlay';
    otherwise,value=contributionTitle(id);
end
end
function buildContributedView(parent,id)
axesHandle=uiaxes(parent,'Tag',[ ...
    'lmz-contributed-central-' strrep(id,'_','-')]);
title(axesHandle,contributionTitle(id));grid(axesHandle,'on');
end
function buildContributedPanel(parent,id)
gridLayout=hostGrid(parent,[2 1]);gridLayout.RowHeight={30,'1x'};
label=uilabel(gridLayout,'Text',contributionTitle(id), ...
    'FontWeight','bold');place(label,1,1);
axesHandle=uiaxes(gridLayout,'Tag',[ ...
    'lmz-contributed-analysis-' strrep(id,'_','-')]);
title(axesHandle,'Registered analysis view');place(axesHandle,2,1);
end
function parent=optionalSidebarParent(sidebar,staging,ids,id,titleText,sizeValue)
if any(strcmp(id,ids))
    parent=sidebar.addTab(id,titleText,sizeValue);
else
    parent=uipanel(staging,'BorderType','none','Visible','off', ...
        'Tag',['lmz-staged-' strrep(id,'_','-')]);
end
end
function value=preferredHost(ids,primaryId,primary,alternative)
if any(strcmp(primaryId,ids)),value=primary;else,value=alternative;end
end
function value=contributionTitle(id)
value=strrep(char(id),'_',' ');
if ~isempty(value),value(1)=upper(value(1));end
end
function value=ratioText(source)
value=sprintf('%.8gx',source);
end
function place(control,row,column)
control.Layout.Row=row;control.Layout.Column=column;
end
function value=capability(source,name)
value=isfield(source,name)&&logical(source.(name));
end
function setTabCapability(tab,value)
if isprop(tab,'Enable')
    if value,tab.Enable='on';else,tab.Enable='off';end
end
end
function setNamedTabCapability(tabs,id,value)
if isfield(tabs,id),setTabCapability(tabs.(id),value);end
end
function rehost(root,parent)
if isempty(root)||~isvalid(root)||isempty(parent)||~isvalid(parent)|| ...
        isequal(root.Parent,parent)
    return
end
root.Parent=parent;root.Layout.Row=1;root.Layout.Column=1;
end
function active=refreshReadOnlyGridExtent(grid,parent)
% UIFigure grids expose a read-only Position and can retain their creation
% extent after a scroll-content panel expands.  Nudge the explicitly sized
% content parent to force a child-layout pass without rebuilding or
% reparenting the grid and all controls that it owns.  The nudge is required
% even when Position already reports the target: MATLAB can update that
% property while retaining child columns from the previous extent.
active=false;
if isempty(grid)||~isvalid(grid)||isempty(parent)||~isvalid(parent),return,end
original=parent.Position;nudged=original;
nudgeSize=max(1,original(3:4)-1);
nudged(3:4)=nudgeSize;
parent.Position=nudged;drawnow
if isempty(grid)||~isvalid(grid)||isempty(parent)||~isvalid(parent)
    if ~isempty(parent)&&isvalid(parent),parent.Position=original;end
    return
end
parent.Position=original;drawnow
active=~isempty(grid)&&isvalid(grid)&&~isempty(parent)&&isvalid(parent);
end
