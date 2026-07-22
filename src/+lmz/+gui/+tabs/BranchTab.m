classdef BranchTab < lmz.gui.tabs.BaseTab
    %BRANCHTAB Scientific branch datasets, selection, and visualization.
    properties (SetAccess=private)
        Axes
        CatalogDropDown
        DatasetList
        VisibilityCheckBox
        MetadataArea
        XDropDown
        YDropDown
        ZDropDown
        DimensionDropDown
        AzimuthSpinner
        ElevationSpinner
        AspectDropDown
        XLimitsField
        YLimitsField
        ZLimitsField
        IndexSpinner
        PercentSlider
        FixedParameterDropDown
        FixedValueDropDown
        VaryingParameterDropDown
        VaryingValueDropDown
        DataToolbar
        ParameterFilterPanel
        BranchCanvas
        AxisControlPanel
        DatasetPanel
        BranchNavigationPanel
        OverlayController
    end
    properties (Access=private)
        IsRefreshing = false
        Palette
        InteractionController = []
        OwnsOverlayController = false
        Placement = struct()
    end

    methods
        function obj=BranchTab(parent,controller,eventBus,preferences,varargin)
            [root,hostOptions,baseArguments]= ...
                lmz.gui.layout.ComponentHost.create(parent, ...
                'Scientific Branches','lmz-tab-branches',varargin{:});
            obj@lmz.gui.tabs.BaseTab(root,controller,eventBus,preferences, ...
                baseArguments{:});
            obj.HostMode=hostOptions.HostMode;
            obj.OverlayController=hostOptions.OverlayController;
            obj.Placement=hostOptions.Placement;
            obj.Id='branches';obj.Palette=lmz.gui.Palette.named(preferences.palette());obj.build();
            obj.subscribe({lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.DatasetsChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.BranchViewChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged});
            if isempty(obj.OverlayController)
                obj.OverlayController= ...
                    lmz.gui.branch.BranchOverlayController(obj.Axes);
                obj.OwnsOverlayController=true;
            else
                obj.OverlayController.attachAxes(obj.Axes);
            end
            figureHandle=ancestor(obj.Root,'figure');
            if ~isempty(figureHandle)
                obj.InteractionController= ...
                    lmz.gui.branch.BranchInteractionController( ...
                    figureHandle,@(~,~)obj.hover(), ...
                    @(~,event)obj.navigate(event));
            end
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            rootGrid=uigridlayout(obj.Root,[3 2]);
            rootGrid.RowHeight={84,'1x',116};rootGrid.ColumnWidth={'1x',315};
            toolbarCallbacks=struct( ...
                'LoadSelected',@()obj.loadSelected(), ...
                'LoadAll',@()obj.loadAll(), ...
                'OpenFolder',@()obj.openFolder(), ...
                'OpenFile',@()obj.openFile(), ...
                'Reload',@()obj.reload(), ...
                'Remove',@()obj.remove(), ...
                'Save',@()obj.save(), ...
                'ExportLegacy',@()obj.exportLegacy(), ...
                'PlotSelected',@()obj.plotSelected(), ...
                'PlotAll',@()obj.plotAll(), ...
                'ClearPlot',@()obj.clearPlot(), ...
                'Preset',@()obj.preset(), ...
                'ExportPlot',@()obj.exportPlot());
            obj.DataToolbar=lmz.gui.branch.DataToolbar( ...
                rootGrid,toolbarCallbacks);
            buttons=obj.DataToolbar.Root;place(buttons,1,[1 2]);
            toolbarControls=obj.DataToolbar.Controls;
            obj.CatalogDropDown=toolbarControls.CatalogDropDown;
            controls=toolbarControls.Buttons;
            lowerButtons=toolbarControls.PlotButtons;

            filterCallbacks=struct( ...
                'FilterChanged',@()obj.parameterFilterChanged(), ...
                'VaryingValueChanged',@()obj.varyingValueChanged());
            obj.ParameterFilterPanel= ...
                lmz.gui.branch.ParameterFilterPanel( ...
                buttons,filterCallbacks);
            place(obj.ParameterFilterPanel.Root,2,[6 9]);
            filterControls=obj.ParameterFilterPanel.Controls;
            obj.FixedParameterDropDown=filterControls.FixedParameter;
            obj.FixedValueDropDown=filterControls.FixedValue;
            obj.VaryingParameterDropDown=filterControls.VaryingParameter;
            obj.VaryingValueDropDown=filterControls.VaryingValue;

            obj.BranchCanvas=lmz.gui.branch.BranchCanvas(rootGrid);
            place(obj.BranchCanvas.Root,2,1);
            obj.Axes=obj.BranchCanvas.Controls.Axes;

            datasetCallbacks=struct( ...
                'DatasetChanged',@()obj.datasetChanged(), ...
                'VisibilityChanged',@()obj.visibilityChanged());
            obj.DatasetPanel=lmz.gui.branch.DatasetPanel( ...
                rootGrid,datasetCallbacks);
            side=obj.DatasetPanel.Root;place(side,2,2);
            datasetControls=obj.DatasetPanel.Controls;
            obj.DatasetList=datasetControls.List;
            obj.VisibilityCheckBox=datasetControls.Visible;
            obj.MetadataArea=datasetControls.Metadata;

            axisCallbacks=struct( ...
                'AxesChanged',@()obj.axesChanged(), ...
                'ViewChanged',@()obj.viewChanged(), ...
                'ApplyLimits',@()obj.applyLimits());
            obj.AxisControlPanel=lmz.gui.branch.AxisControlPanel( ...
                rootGrid,axisCallbacks);
            axisControls=obj.AxisControlPanel.Root;
            place(axisControls,3,[1 2]);
            axisWidgets=obj.AxisControlPanel.Controls;
            obj.XDropDown=axisWidgets.X;
            obj.YDropDown=axisWidgets.Y;
            obj.ZDropDown=axisWidgets.Z;
            obj.DimensionDropDown=axisWidgets.Dimension;
            obj.AzimuthSpinner=axisWidgets.Azimuth;
            obj.ElevationSpinner=axisWidgets.Elevation;
            obj.AspectDropDown=axisWidgets.Aspect;
            obj.XLimitsField=axisWidgets.XLimits;
            obj.YLimitsField=axisWidgets.YLimits;
            obj.ZLimitsField=axisWidgets.ZLimits;

            navigationCallbacks=struct( ...
                'IndexChanged',@()obj.indexChanged(), ...
                'PercentChanged',@()obj.percentChanged());
            obj.BranchNavigationPanel= ...
                lmz.gui.branch.BranchNavigationPanel( ...
                axisControls,navigationCallbacks);
            place(obj.BranchNavigationPanel.Root,[1 2],[8 10]);
            navigation=obj.BranchNavigationPanel.Controls;
            obj.IndexSpinner=navigation.Index;
            obj.PercentSlider=navigation.Percentage;

            obj.ActionControls=[controls lowerButtons ...
                {obj.CatalogDropDown obj.DatasetList obj.VisibilityCheckBox ...
                obj.XDropDown obj.YDropDown obj.ZDropDown obj.DimensionDropDown ...
                obj.AzimuthSpinner obj.ElevationSpinner obj.AspectDropDown ...
                obj.XLimitsField obj.YLimitsField obj.ZLimitsField ...
                obj.IndexSpinner obj.PercentSlider}];
            obj.ActionControls=[obj.ActionControls {obj.FixedParameterDropDown ...
                obj.FixedValueDropDown obj.VaryingParameterDropDown ...
                obj.VaryingValueDropDown}];
            obj.applyWorkspacePlacement(rootGrid,buttons,side);
        end

        function refresh(obj,varargin)
            if obj.IsRefreshing,return,end
            obj.IsRefreshing=true;cleanup=onCleanup(@()obj.finishRefresh());
            refresh@lmz.gui.tabs.BaseTab(obj);obj.refreshCatalog(); ...
                obj.refreshDatasets();obj.refreshParameterFilters();obj.render();
            clear cleanup
        end

        function setPalette(obj,value)
            if ischar(value)||isstring(value),value=lmz.gui.Palette.named(value);end
            obj.Palette=value;
            if ~isempty(obj.OverlayController)&&isvalid(obj.OverlayController)
                obj.OverlayController.setPalette(value);
            end
            obj.render();
        end

        function hooks=testHooks(obj)
            hooks=testHooks@lmz.gui.tabs.BaseTab(obj);hooks.Controls=obj.controlMap();
        end

        function handleKeyPress(obj,event),obj.navigate(event);end
    end

    methods (Static)
        function value=descriptor()
            value=struct('Id','branches','Title','Scientific Branches', ...
                'Purpose','Load, compare, select, and export scientific branches.');
        end
    end

    methods (Access=protected)
        function onPresentationEvents(obj,batch)
            names={batch.Name};
            if any(ismember(names,{lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.WorkflowChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged}))&& ...
                    ~isempty(obj.OverlayController)
                obj.OverlayController.clearRunLayers();
                obj.OverlayController.clearLayer('hover_point');
            end
            obj.refresh(batch);
        end

        function controls=controlMap(obj)
            controls=struct('Axes',obj.Axes,'CatalogDropDown',obj.CatalogDropDown, ...
                'DatasetList',obj.DatasetList,'VisibilityCheckBox',obj.VisibilityCheckBox, ...
                'MetadataArea',obj.MetadataArea,'XDropDown',obj.XDropDown, ...
                'YDropDown',obj.YDropDown,'ZDropDown',obj.ZDropDown, ...
                'DimensionDropDown',obj.DimensionDropDown,'IndexSpinner',obj.IndexSpinner, ...
                'PercentSlider',obj.PercentSlider, ...
                'FixedParameterDropDown',obj.FixedParameterDropDown, ...
                'FixedValueDropDown',obj.FixedValueDropDown, ...
                'VaryingParameterDropDown',obj.VaryingParameterDropDown, ...
                'VaryingValueDropDown',obj.VaryingValueDropDown);
        end

        function beforeDelete(obj)
            if ~isempty(obj.InteractionController)&& ...
                    isvalid(obj.InteractionController)
                delete(obj.InteractionController);
            end
            obj.InteractionController=[];
            if obj.OwnsOverlayController&&~isempty(obj.OverlayController)&& ...
                    isvalid(obj.OverlayController)
                delete(obj.OverlayController);
            end
            obj.OverlayController=[];
            components={obj.ParameterFilterPanel,obj.DataToolbar, ...
                obj.BranchNavigationPanel,obj.AxisControlPanel, ...
                obj.DatasetPanel,obj.BranchCanvas};
            for index=1:numel(components)
                component=components{index};
                if ~isempty(component)&&isvalid(component),delete(component);end
            end
            obj.ParameterFilterPanel=[];obj.DataToolbar=[];
            obj.BranchNavigationPanel=[];obj.AxisControlPanel=[];
            obj.DatasetPanel=[];obj.BranchCanvas=[];
        end
    end

    methods (Access=private)
        function applyWorkspacePlacement(obj,rootGrid,buttons,side)
            if ~strcmp(obj.HostMode,'workspace')||isempty(fieldnames(obj.Placement))
                return
            end
            buttons.ColumnWidth={120,65,58,68,74,60,70,70,'1x'};
            if ~isempty(obj.ParameterFilterPanel)&& ...
                    isvalid(obj.ParameterFilterPanel)&& ...
                    ~isempty(obj.ParameterFilterPanel.Root)&& ...
                    isvalid(obj.ParameterFilterPanel.Root)
                obj.ParameterFilterPanel.Root.ColumnWidth= ...
                    {60,70,70,'1x'};
            end
            if isfield(obj.Placement,'DataParent')&& ...
                    ~isempty(obj.Placement.DataParent)&& ...
                    isvalid(obj.Placement.DataParent)
                buttons.Parent=obj.Placement.DataParent;
                buttons.Layout.Row=1;buttons.Layout.Column=1;
                rootGrid.RowHeight={0,'1x',116};
            end
            if isfield(obj.Placement,'InfoParent')&& ...
                    ~isempty(obj.Placement.InfoParent)&& ...
                    isvalid(obj.Placement.InfoParent)
                side.Parent=obj.Placement.InfoParent;
                side.Layout.Row=1;side.Layout.Column=1;
                rootGrid.ColumnWidth={'1x',0};
            end
        end

        function finishRefresh(obj),obj.IsRefreshing=false;end
        function refreshCatalog(obj)
            if ismethod(obj.Controller,'dataSourceDescriptors')
                descriptors=obj.Controller.dataSourceDescriptors();
                files=cell(1,numel(descriptors));labels=files;defaultPath='';
                for index=1:numel(descriptors)
                    files{index}=descriptorField(descriptors(index),'id','');
                    labels{index}=descriptorField(descriptors(index),'label',files{index});
                    if descriptorField(descriptors(index),'isDefault',false)
                        defaultPath=files{index};
                    end
                end
            else
                datasets=obj.Controller.State.Datasets;
                files=cell(1,numel(datasets));labels=files;
                for index=1:numel(datasets)
                    files{index}=datasets{index}.SourcePath;
                    labels{index}=datasets{index}.Name;
                end
                defaultPath='';
            end
            if isempty(files)
                obj.CatalogDropDown.Items={'No registered scientific dataset'};
                obj.CatalogDropDown.ItemsData={''};obj.CatalogDropDown.Value='';return
            end
            obj.CatalogDropDown.Items=labels;obj.CatalogDropDown.ItemsData=files;
            if any(strcmp(defaultPath,files))
                obj.CatalogDropDown.Value=defaultPath;
            elseif ~any(strcmp(obj.CatalogDropDown.Value,files))
                obj.CatalogDropDown.Value=files{1};
            end
        end
        function refreshDatasets(obj)
            datasets=obj.Controller.State.Datasets;items=cell(1,numel(datasets));ids=cell(1,numel(datasets));
            for index=1:numel(datasets)
                visible='○';if datasets{index}.Visible,visible='●';end
                items{index}=sprintf('%s %s — %d points — %s — %s',visible, ...
                    datasets{index}.Name,datasets{index}.Branch.pointCount(), ...
                    shortText(metadataField(datasets{index}.Metadata,'GaitSummary',''),20), ...
                    metadataField(datasets{index}.Metadata,'Status',''));
                ids{index}=datasets{index}.Id;
            end
            obj.DatasetList.Items=items;obj.DatasetList.ItemsData=ids;
            if isempty(datasets)
                obj.MetadataArea.Value={'No dataset loaded.'};
                obj.DatasetList.Enable='off';obj.VisibilityCheckBox.Enable='off';return
            end
            obj.DatasetList.Enable=onOff(~obj.IsBusy);obj.VisibilityCheckBox.Enable=onOff(~obj.IsBusy);
            obj.DatasetList.Value=obj.Controller.State.ActiveDatasetId;dataset=obj.Controller.activeDataset();
            obj.VisibilityCheckBox.Value=dataset.Visible;obj.MetadataArea.Value=metadataLines(dataset);
            names=dataset.Branch.coordinateNames();
            obj.XDropDown.Items=names;obj.YDropDown.Items=names;obj.ZDropDown.Items=names;
            selected=obj.Controller.State.AxisVariables;
            if numel(selected)<3
                originalCount=numel(selected);selected(3)={''};
                for fillIndex=originalCount+1:3
                    selected{fillIndex}=names{min(fillIndex,numel(names))};
                end
            end
            for index=1:3
                if ~any(strcmp(selected{index},names)),selected{index}=names{min(index,numel(names))};end
            end
            if ~isequal(selected,obj.Controller.State.AxisVariables)
                obj.Controller.setAxisVariables(selected{1},selected{2},selected{3});
            end
            obj.XDropDown.Value=selected{1};obj.YDropDown.Value=selected{2};obj.ZDropDown.Value=selected{3};
            n=dataset.Branch.pointCount();obj.IndexSpinner.Limits=[1 n];selectedIndex=1;
            if ~isempty(obj.Controller.State.LockedSelection)
                selectedIndex=min(n,obj.Controller.State.LockedSelection.PointIndex);
            end
            obj.IndexSpinner.Value=selectedIndex;
            obj.PercentSlider.Value=100*(selectedIndex-1)/max(1,n-1);
        end
        function loadSelected(obj)
            if isempty(obj.CatalogDropDown.Value),return,end
            try
                if ismethod(obj.Controller,'loadDataSource')
                    obj.Controller.loadDataSource(obj.CatalogDropDown.Value);
                else
                    obj.Controller.openBranch(obj.CatalogDropDown.Value);
                end
            catch exception
                obj.reportError(exception);
            end
        end
        function loadAll(obj)
            try
                if ismethod(obj.Controller,'loadAllDataSources')
                    obj.Controller.loadAllDataSources();
                elseif ~isempty(obj.Controller.State.RoadMapCatalog)
                    obj.Controller.loadAllRoadMapBranches();
                end
            catch exception
                obj.reportError(exception);
            end
        end
        function openFolder(obj)
            start=obj.Preferences.recentDataFolder(pwd);
            folder=uigetdir(start,'Open folder containing MAT/artifact branches');
            if isequal(folder,0),return,end
            try
                obj.Controller.openBranchFolder(folder);
                obj.Preferences.rememberDataFolder(folder);
            catch exception
                obj.reportError(exception);
            end
        end
        function openFile(obj)
            start=obj.Preferences.recentDataFolder(pwd);
            [file,path]=uigetfile(fullfile(start,'*.mat'),'Open branch');if isequal(file,0),return,end
            try
                obj.Controller.openBranch(fullfile(path,file));
                obj.Preferences.rememberDataFolder(path);
            catch exception
                obj.reportError(exception);
            end
        end
        function reload(obj)
            try
                obj.Controller.reloadActiveDataset();
            catch exception
                obj.reportError(exception);
            end
        end
        function remove(obj)
            if isempty(obj.Controller.State.Datasets),return,end
            try
                obj.Controller.removeDataset(obj.Controller.State.ActiveDatasetId);
            catch exception
                obj.reportError(exception);
            end
        end
        function datasetChanged(obj)
            try
                obj.Controller.setActiveDataset(obj.DatasetList.Value);
            catch exception
                obj.reportError(exception);
            end
        end
        function visibilityChanged(obj)
            try
                obj.Controller.setDatasetVisibility( ...
                    obj.Controller.State.ActiveDatasetId, ...
                    obj.VisibilityCheckBox.Value);
            catch exception
                obj.reportError(exception);
            end
        end
        function plotSelected(obj),obj.Controller.showOnlyActiveDataset();end
        function plotAll(obj),obj.Controller.setAllDatasetsVisible(true);end
        function clearPlot(obj),obj.Controller.setAllDatasetsVisible(false);end
        function axesChanged(obj)
            try
                obj.Controller.setAxisVariables(obj.XDropDown.Value, ...
                    obj.YDropDown.Value,obj.ZDropDown.Value);
                obj.render();
            catch exception
                obj.reportError(exception);
            end
        end
        function preset(obj)
            if ismethod(obj.Controller,'axisPreset')
                preset=obj.Controller.axisPreset();names=preset.Coordinates;
                limits=preset.Limits;
            elseif ~isempty(obj.Controller.State.Datasets)
                names=obj.Controller.activeDataset().Branch.coordinateNames();
                if numel(names)<3,return,end
                names=names(1:3);limits={'auto','auto','auto'};
            else
                return
            end
            obj.XDropDown.Value=names{1};obj.YDropDown.Value=names{2};obj.ZDropDown.Value=names{3};
            obj.DimensionDropDown.Value='2-D';obj.AzimuthSpinner.Value=0;obj.ElevationSpinner.Value=90;
            obj.XLimitsField.Value=limits{1};obj.YLimitsField.Value=limits{2};obj.ZLimitsField.Value=limits{3};
            obj.axesChanged();obj.applyLimits();
        end
        function viewChanged(obj)
            if strcmp(obj.DimensionDropDown.Value,'3-D')
                view(obj.Axes,obj.AzimuthSpinner.Value,obj.ElevationSpinner.Value);
            else
                view(obj.Axes,2);
            end
            if strcmp(obj.AspectDropDown.Value,'equal'),axis(obj.Axes,'equal');else,axis(obj.Axes,'normal');end
        end
        function applyLimits(obj)
            try
                applyLimit(obj.Axes,'x',obj.XLimitsField.Value);
                applyLimit(obj.Axes,'y',obj.YLimitsField.Value);
                applyLimit(obj.Axes,'z',obj.ZLimitsField.Value);
            catch exception
                obj.reportError(exception);
            end
        end
        function render(obj)
            if isempty(obj.Axes)||~isgraphics(obj.Axes),return,end
            clearBranchContent(obj.Axes);
            if isempty(obj.Controller.State.Datasets)
                if ~isempty(obj.OverlayController)
                    obj.OverlayController.clearLayer('source_branches');
                    obj.OverlayController.clearLayer('locked_point');
                    obj.OverlayController.clearLayer('hover_point');
                end
                return
            end
            hold(obj.Axes,'on');names=obj.Controller.State.AxisVariables;
            is3=strcmp(obj.DimensionDropDown.Value,'3-D');datasets=obj.Controller.State.Datasets;
            active=obj.Controller.activeDataset();shownDatasets=0;shownPoints=0;
            for index=1:numel(datasets)
                dataset=datasets{index};if ~dataset.Visible,continue,end
                if strcmp(dataset.Id,active.Id),continue,end
                if ~obj.datasetPassesFixedFilter(dataset),continue,end
                mask=obj.pointFilterMask(dataset.Branch);
                if ~any(mask),continue,end
                x=dataset.Branch.coordinate(names{1});x=x(mask);
                y=dataset.Branch.coordinate(names{2});y=y(mask);
                color=styleField(dataset.DisplayStyle,'Color',lineColor(index));
                lineStyle=styleField(dataset.DisplayStyle,'LineStyle','-');
                marker=styleField(dataset.DisplayStyle,'Marker','none');
                if strcmp(obj.Palette.Name,'high-contrast')&&strcmp(marker,'none')
                    marker=markerFor(index);
                end
                if is3
                    z=dataset.Branch.coordinate(names{3});z=z(mask);
                    lineHandle=plot3(obj.Axes,x,y,z, ...
                        'Color',color,'LineStyle',lineStyle,'Marker',marker,'LineWidth',1.8);
                else
                    lineHandle=plot(obj.Axes,x,y,'Color',color,'LineStyle',lineStyle, ...
                        'Marker',marker,'LineWidth',1.8);
                end
                lineHandle.UserData=dataset.Id;
                lineHandle.ButtonDownFcn=@(~,event)obj.clicked(dataset.Id,event);
                shownDatasets=shownDatasets+1;shownPoints=shownPoints+sum(mask);
            end
            hold(obj.Axes,'off');grid(obj.Axes,'on');
            xlabel(obj.Axes,names{1},'Interpreter','none');ylabel(obj.Axes,names{2},'Interpreter','none');
            if is3,zlabel(obj.Axes,names{3},'Interpreter','none');end
            obj.viewChanged();obj.applyLimits();
            obj.OverlayController.attachAxes(obj.Axes);
            obj.OverlayController.setAxisContext(names,is3);
            if active.Visible&&obj.datasetPassesFixedFilter(active)
                mask=obj.pointFilterMask(active.Branch);
                if any(mask)
                    coordinates=nan(numel(names),sum(mask));
                    for nameIndex=1:numel(names)
                        values=active.Branch.coordinate(names{nameIndex});
                        coordinates(nameIndex,:)=values(mask);
                    end
                    obj.OverlayController.setCoordinates('source_branches', ...
                        coordinates);
                    sourceHandle=obj.OverlayController.layerHandle( ...
                        'source_branches');
                    if ~isempty(sourceHandle)&&isgraphics(sourceHandle)
                        sourceHandle.UserData=active.Id;
                        sourceHandle.ButtonDownFcn= ...
                            @(~,event)obj.clicked(active.Id,event);
                    end
                    shownDatasets=shownDatasets+1;
                    shownPoints=shownPoints+sum(mask);
                else
                    obj.OverlayController.clearLayer('source_branches');
                end
            else
                obj.OverlayController.clearLayer('source_branches');
            end
            obj.OverlayController.axesWasCleared();
            title(obj.Axes,sprintf( ...
                'Scientific branches — %d datasets, %d visible points', ...
                shownDatasets,shownPoints));
            selection=obj.Controller.State.LockedSelection;
            if isempty(selection)||~obj.selectionPassesFilters(selection)
                obj.OverlayController.clearLayer('locked_point');
            else
                try
                    obj.OverlayController.setSolution('locked_point', ...
                        obj.Controller.lockedSolution());
                catch
                end
            end
        end
        function hover(obj)
            if isempty(obj.Axes)||~isgraphics(obj.Axes)||isempty(obj.Controller.State.Datasets),return,end
            if ~obj.isSelectedTab(),return,end
            try
                figureHandle=ancestor(obj.Root,'figure');hit=hittest(figureHandle);
                hitAxes=ancestor(hit,'axes');if isempty(hitAxes)||~isequal(hitAxes,obj.Axes),return,end
                point=obj.Axes.CurrentPoint;dimensions=2;
                if strcmp(obj.DimensionDropDown.Value,'3-D'),dimensions=3;end
                coordinates=obj.Controller.State.AxisVariables(1:dimensions);
                [selection,details]=obj.Controller.hoverNearestVisiblePoint( ...
                    coordinates,point(1,1:dimensions));
                delete(findobj(obj.Axes,'Tag','HoverDataTip'));
                holdState=ishold(obj.Axes);hold(obj.Axes,'on');values=cell2mat(details.Values);
                obj.OverlayController.setCoordinates('hover_point',values(:));
                if dimensions==3
                    tip=text(obj.Axes,values(1),values(2),values(3),hoverText(details,selection), ...
                        'BackgroundColor',obj.Palette.HoverColor,'Margin',3,'Tag','HoverDataTip','Interpreter','none');
                else
                    tip=text(obj.Axes,values(1),values(2),hoverText(details,selection), ...
                        'BackgroundColor',obj.Palette.HoverColor,'Margin',3,'Tag','HoverDataTip','Interpreter','none');
                end
                tip.VerticalAlignment='bottom';if ~holdState,hold(obj.Axes,'off');end
            catch
            end
        end
        function clicked(obj,datasetId,event)
            try
                if isprop(event,'IntersectionPoint')
                    target=event.IntersectionPoint;
                else
                    point=obj.Axes.CurrentPoint;target=point(1,:);
                end
                dimensions=2;if strcmp(obj.DimensionDropDown.Value,'3-D'),dimensions=3;end
                coordinates=obj.Controller.State.AxisVariables(1:dimensions);
                selection=obj.Controller.hoverNearestPoint(datasetId,coordinates,target(1:dimensions));
                obj.Controller.lockBranchPoint(datasetId,selection.PointIndex);
            catch exception
                obj.reportError(exception);
            end
        end
        function navigate(obj,event)
            if ~obj.isSelectedTab()||isempty(obj.Controller.State.LockedSelection),return,end
            switch event.Key
                case {'leftarrow','downarrow'},delta=-1;
                case {'rightarrow','uparrow'},delta=1;
                otherwise,return
            end
            n=obj.Controller.activeDataset().Branch.pointCount();
            index=max(1,min(n,obj.Controller.State.LockedSelection.PointIndex+delta));
            obj.Controller.selectByIndex(index);
        end
        function result=isSelectedTab(obj)
            group=obj.Root.Parent;result=~isprop(group,'SelectedTab')||isequal(group.SelectedTab,obj.Root);
        end
        function indexChanged(obj)
            try
                obj.Controller.selectByIndex(obj.IndexSpinner.Value);
            catch exception
                obj.reportError(exception);
            end
        end
        function percentChanged(obj)
            try
                obj.Controller.selectByPercentage(obj.PercentSlider.Value);
            catch exception
                obj.reportError(exception);
            end
        end
        function save(obj)
            if isempty(obj.Controller.State.Datasets),return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.lmz.mat'),'Save native branch');if isequal(file,0),return,end
            try
                obj.Controller.saveBranch(fullfile(path,file), ...
                    obj.Controller.activeDataset().Branch);
                obj.Preferences.rememberOutputFolder(path);
            catch exception
                obj.reportError(exception);
            end
        end
        function exportLegacy(obj)
            if isempty(obj.Controller.State.Datasets),return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.mat'),'Export legacy branch');if isequal(file,0),return,end
            try
                obj.Controller.exportLegacyBranch(fullfile(path,file), ...
                    obj.Controller.activeDataset().Branch);
                obj.Preferences.rememberOutputFolder(path);
            catch exception
                obj.reportError(exception);
            end
        end
        function exportPlot(obj)
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile({'*.png';'*.pdf'},'Export branch plot',start);if isequal(file,0),return,end
            try
                obj.Controller.exportPlot(obj.Axes,fullfile(path,file));
                obj.Preferences.rememberOutputFolder(path);
            catch exception
                obj.reportError(exception);
            end
        end

        function refreshParameterFilters(obj)
            if isempty(obj.Controller.State.Datasets)
                obj.FixedParameterDropDown.Items={'<none>'};
                obj.VaryingParameterDropDown.Items={'<none>'};
                obj.FixedValueDropDown.Items={'<all>'};
                obj.VaryingValueDropDown.Items={'<all>'};
                return
            end
            branch=obj.Controller.activeDataset().Branch;
            names=reshape(branch.ParameterSchema.names(),1,[]);
            varying=obj.providerVaryingNames(branch);
            configured=obj.ContributionParameterFilters();
            configuredFixed=filterMetadataNames(configured, ...
                {'fixedParameters','fixed','fixedParameterNames'});
            configuredVarying=filterMetadataNames(configured, ...
                {'varyingParameters','varying','varyingParameterNames'});
            if ~isempty(configuredVarying)
                varying=intersect(names,configuredVarying,'stable');
            end
            fixed=setdiff(names,varying,'stable');
            if ~isempty(configuredFixed)
                fixed=intersect(names,configuredFixed,'stable');
            end
            restoreDropDown(obj.FixedParameterDropDown, ...
                [{'<none>'} fixed]);
            restoreDropDown(obj.VaryingParameterDropDown, ...
                [{'<none>'} varying]);
            obj.parameterFilterChanged();
        end

        function parameterFilterChanged(obj)
            restoreDropDown(obj.FixedValueDropDown,parameterValues( ...
                obj.Controller,obj.FixedParameterDropDown.Value,true));
            restoreDropDown(obj.VaryingValueDropDown,parameterValues( ...
                obj.Controller,obj.VaryingParameterDropDown.Value,false));
            if ~obj.IsRefreshing,obj.render();end
        end

        function varyingValueChanged(obj)
            name=obj.VaryingParameterDropDown.Value;
            value=obj.VaryingValueDropDown.Value;
            obj.render();
            if strcmp(name,'<none>')||strcmp(value,'<all>'),return,end
            try
                branch=obj.Controller.activeDataset().Branch;
                values=branch.parameter(name);target=str2double(value);
                [~,index]=min(abs(values-target));obj.Controller.selectByIndex(index);
            catch exception
                obj.reportError(exception);
            end
        end

        function names=providerVaryingNames(obj,branch)
            provider=obj.filterProvider();
            try
                if ~isempty(provider)&&ismethod(provider, ...
                        'identifyVaryingParameter')
                    names=provider.identifyVaryingParameter(branch);
                else
                    names=lmz.services.BranchService(). ...
                        identifyVaryingParameter(branch);
                end
            catch
                names={};
            end
            names=reshape(names,1,[]);
        end

        function value=ContributionParameterFilters(obj)
            value=struct();
            try
                contribution=obj.Controller.workbenchContribution();
                if isa(contribution,'lmz.workflow.WorkbenchContribution')
                    value=contribution.ParameterFilters;
                end
            catch
            end
        end

        function provider=filterProvider(obj)
            provider=[];
            try
                sourceId=obj.Controller.State.DataSourceId;
                if isempty(sourceId)
                    descriptor=obj.Controller.Workflows.defaultDataSource( ...
                        obj.Controller.State.ModelId);
                else
                    descriptor=obj.Controller.Workflows.getDataSource( ...
                        obj.Controller.State.ModelId,sourceId);
                end
                provider=descriptor.createProvider();
            catch
            end
        end

        function result=datasetPassesFixedFilter(obj,dataset)
            result=true;name=obj.FixedParameterDropDown.Value;
            value=obj.FixedValueDropDown.Value;
            if strcmp(name,'<none>')||strcmp(value,'<all>'),return,end
            target=str2double(value);
            if ~isfinite(target),return,end
            try
                provider=obj.filterProvider();
                if ~isempty(provider)&&ismethod(provider, ...
                        'filterByFixedParameters')
                    matches=provider.filterByFixedParameters( ...
                        {dataset.Branch},name,target,1e-9);
                else
                    matches=lmz.services.BranchService(). ...
                        filterByFixedParameters( ...
                        {dataset.Branch},name,target,1e-9);
                end
                result=logical(matches(1));
            catch
                result=false;
            end
        end

        function mask=pointFilterMask(obj,branch)
            mask=true(1,branch.pointCount());
            name=obj.VaryingParameterDropDown.Value;
            value=obj.VaryingValueDropDown.Value;
            if strcmp(name,'<none>')||strcmp(value,'<all>'),return,end
            try
                values=branch.parameter(name);target=str2double(value);
                tolerance=1e-9*max(1,abs(target));
                mask=abs(values-target)<=tolerance;
                if ~any(mask)&&isfinite(target)
                    [~,index]=min(abs(values-target));mask(index)=true;
                end
            catch
                mask=false(1,branch.pointCount());
            end
        end

        function result=selectionPassesFilters(obj,selection)
            result=false;datasets=obj.Controller.State.Datasets;
            for index=1:numel(datasets)
                dataset=datasets{index};
                if ~strcmp(dataset.Id,selection.DatasetId),continue,end
                if ~dataset.Visible||~obj.datasetPassesFixedFilter(dataset)
                    return
                end
                mask=obj.pointFilterMask(dataset.Branch);
                pointIndex=selection.PointIndex;
                result=pointIndex>=1&&pointIndex<=numel(mask)&&mask(pointIndex);
                return
            end
        end
    end
end

function place(control,row,column),control.Layout.Row=row;control.Layout.Column=column;end
function value=onOff(condition),if condition,value='on';else,value='off';end,end
function value=metadataField(metadata,name,fallback),if isstruct(metadata)&&isfield(metadata,name),value=metadata.(name);else,value=fallback;end;if isnumeric(value),value=mat2str(value,4);end,end
function value=shortText(source,count),if isstring(source),source=char(source);end;if ~ischar(source),source=displayValue(source);end;if numel(source)>count,value=[source(1:count-1) '…'];else,value=source;end,end
function lines=metadataLines(dataset)
metadata=dataset.Metadata;lines={sprintf('Name: %s',dataset.Name),sprintf('Status: %s',metadataField(metadata,'Status','unknown')),sprintf('Points: %d',dataset.Branch.pointCount()),sprintf('Source: %s',dataset.SourcePath),sprintf('Read only: %s',onOff(dataset.ReadOnly)),sprintf('Gait/type: %s',metadataField(metadata,'GaitSummary','')),sprintf('Parameters: %s',metadataField(metadata,'ParameterSummary','')),sprintf('SHA-256: %s',metadataField(metadata,'SourceHash',''))};
end
function applyLimit(axesHandle,dimension,textValue)
if strcmp(strtrim(textValue),'auto')
    switch dimension,case 'x',xlim(axesHandle,'auto');case 'y',ylim(axesHandle,'auto');case 'z',zlim(axesHandle,'auto');end
    return
end
values=sscanf(strrep(strrep(textValue,'[',''),']',''),'%f');if numel(values)~=2||values(1)>=values(2),error('lmz:GUI:AxisLimits','Axis limits must be auto or [minimum maximum].');end
switch dimension,case 'x',xlim(axesHandle,values(:).');case 'y',ylim(axesHandle,values(:).');case 'z',zlim(axesHandle,values(:).');end
end
function value=styleField(style,name,fallback),if isstruct(style)&&isfield(style,name)&&~isempty(style.(name)),value=style.(name);else,value=fallback;end,end
function value=lineColor(index),colors=lines(7);value=colors(1+mod(index-1,size(colors,1)),:);end
function value=markerFor(index),values={'o','s','d','^','v','>','<','p','h'};value=values{1+mod(index-1,numel(values))};end
function value=displayValue(source),if isnumeric(source),value=mat2str(source,4);elseif ischar(source),value=source;elseif isstring(source),value=char(source);else,value=class(source);end,end
function clearBranchContent(axesHandle)
children=axesHandle.Children;
for index=1:numel(children)
    child=children(index);tag='';
    if isprop(child,'Tag'),tag=child.Tag;end
    if isstring(tag)&&isscalar(tag),tag=char(tag);end
    if ischar(tag)&&strncmp(tag,'lmz-overlay-',12),continue,end
    if isvalid(child),delete(child);end
end
end
function value=descriptorField(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name),value=source.(name);end
if isstring(value)&&isscalar(value),value=char(value);end
end
function items=parameterValues(controller,name,allDatasets)
items={'<all>'};
if strcmp(name,'<none>')||isempty(controller.State.Datasets),return,end
try
    if allDatasets
        datasets=controller.State.Datasets;values=[];
        for datasetIndex=1:numel(datasets)
            values=[values datasets{datasetIndex}.Branch.parameter(name)]; %#ok<AGROW>
        end
    else
        values=controller.activeDataset().Branch.parameter(name);
    end
    values=unique(values(isfinite(values)),'stable');
    for index=1:numel(values)
        items{end+1}=sprintf('%.9g',values(index)); %#ok<AGROW>
    end
catch
end
end
function restoreDropDown(control,items)
previous=control.Value;control.Items=items;
if any(strcmp(previous,items)),control.Value=previous;else,control.Value=items{1};end
end
function values=filterMetadataNames(metadata,fields)
values={};
if ~isstruct(metadata)||~isscalar(metadata),return,end
for index=1:numel(fields)
    if ~isfield(metadata,fields{index}),continue,end
    candidate=metadata.(fields{index});
    if ischar(candidate),candidate={candidate};end
    if isstring(candidate),candidate=cellstr(candidate);end
    if iscell(candidate)&&all(cellfun(@ischar,candidate))
        values=reshape(candidate,1,[]);return
    end
end
end
function textValue=hoverText(details,selection)
solution=details.Solution;coordinates=cell(1,numel(details.Coordinates));for index=1:numel(coordinates),coordinates{index}=sprintf('%s=%.5g',details.Coordinates{index},details.Values{index});end
parameters=solution.ParameterSchema.names();parts=cell(1,min(4,numel(parameters)));for index=1:numel(parts),parts{index}=sprintf('%s=%.4g',parameters{index},solution.ParameterValues(index));end
gait=classificationField(solution.Classification,'Abbreviation','?');residual=diagnosticField(solution.Diagnostics,'ResidualNorm',NaN);
textValue=sprintf('%s #%d\n%s\ngait=%s residual=%.3g\n%s',details.Dataset.Name,selection.PointIndex,strjoin(coordinates,', '),gait,residual,strjoin(parts,', '));
end
function value=classificationField(source,name,fallback),if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end,end
function value=diagnosticField(source,name,fallback),if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end,end
