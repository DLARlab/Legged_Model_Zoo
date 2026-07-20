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
    end
    properties (Access=private)
        IsRefreshing = false
        Palette
    end

    methods
        function obj=BranchTab(parent,controller,eventBus,preferences,varargin)
            tab=uitab(parent,'Title','Scientific Branches','Tag','lmz-tab-branches');
            obj@lmz.gui.tabs.BaseTab(tab,controller,eventBus,preferences,varargin{:});
            obj.Id='branches';obj.Palette=lmz.gui.Palette.named(preferences.palette());obj.build();
            obj.subscribe({lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.DatasetsChanged, ...
                lmz.gui.PresentationEvents.SelectionChanged, ...
                lmz.gui.PresentationEvents.BranchViewChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged});
            figureHandle=ancestor(obj.Root,'figure');
            if ~isempty(figureHandle)
                figureHandle.WindowButtonMotionFcn=@(~,~)obj.hover();
                figureHandle.KeyPressFcn=@(~,event)obj.navigate(event);
            end
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            rootGrid=uigridlayout(obj.Root,[3 2]);
            rootGrid.RowHeight={84,'1x',116};rootGrid.ColumnWidth={'1x',315};
            buttons=uigridlayout(rootGrid,[2 9]);place(buttons,1,[1 2]);
            buttons.ColumnWidth={165,95,85,92,105,90,105,105,'1x'};
            obj.CatalogDropDown=uidropdown(buttons,'Tag','lmz-branch-catalog', ...
                'Tooltip','Choose a built-in scientific branch or dataset.');place(obj.CatalogDropDown,1,1);
            controls={ ...
                makeButton(buttons,'Load selected','load-selected',@()obj.loadSelected()), ...
                makeButton(buttons,'Load all','load-all',@()obj.loadAll()), ...
                makeButton(buttons,'Open folder…','open-folder',@()obj.openFolder()), ...
                makeButton(buttons,'Open MAT/artifact…','open-file',@()obj.openFile()), ...
                makeButton(buttons,'Reload','reload',@()obj.reload()), ...
                makeButton(buttons,'Remove selected','remove',@()obj.remove()), ...
                makeButton(buttons,'Save native…','save',@()obj.save()), ...
                makeButton(buttons,'Export legacy…','export-legacy',@()obj.exportLegacy())};
            for index=1:numel(controls),place(controls{index},1,index+1);end
            lowerButtons={ ...
                makeButton(buttons,'Plot selected','plot-selected',@()obj.plotSelected()), ...
                makeButton(buttons,'Plot all','plot-all',@()obj.plotAll()), ...
                makeButton(buttons,'Clear plot','clear-plot',@()obj.clearPlot()), ...
                makeButton(buttons,'RoadMap preset','preset',@()obj.preset()), ...
                makeButton(buttons,'Export plot…','export-plot',@()obj.exportPlot())};
            for index=1:numel(lowerButtons),place(lowerButtons{index},2,index);end
            obj.ActionControls=[controls lowerButtons {obj.CatalogDropDown}];
            obj.Axes=uiaxes(rootGrid,'Tag','lmz-branch-axes');place(obj.Axes,2,1);
            obj.Axes.XGrid='on';obj.Axes.YGrid='on';title(obj.Axes,'Scientific branches');
            side=uigridlayout(rootGrid,[4 1]);place(side,2,2);side.RowHeight={24,'1x',28,112};
            uilabel(side,'Text','Datasets (active selection)','FontWeight','bold');
            obj.DatasetList=uilistbox(side,'Tag','lmz-branch-datasets', ...
                'Tooltip','Select the active scientific dataset.', ...
                'ValueChangedFcn',@(~,~)obj.datasetChanged());
            obj.VisibilityCheckBox=uicheckbox(side,'Text','Visible','Value',true, ...
                'Tag','lmz-branch-visible','ValueChangedFcn',@(~,~)obj.visibilityChanged());
            obj.MetadataArea=uitextarea(side,'Editable','off','Value',{'No dataset'}, ...
                'Tag','lmz-branch-metadata','Tooltip','Copyable source and dataset metadata.');
            axisControls=uigridlayout(rootGrid,[3 10]);place(axisControls,3,[1 2]);
            axisControls.ColumnWidth={24,'1x',24,'1x',24,'1x',64,52,62,92};
            label=uilabel(axisControls,'Text','X');place(label,1,1);
            obj.XDropDown=axisDropDown(axisControls,'x',@()obj.axesChanged());place(obj.XDropDown,1,2);
            label=uilabel(axisControls,'Text','Y');place(label,1,3);
            obj.YDropDown=axisDropDown(axisControls,'y',@()obj.axesChanged());place(obj.YDropDown,1,4);
            label=uilabel(axisControls,'Text','Z');place(label,1,5);
            obj.ZDropDown=axisDropDown(axisControls,'z',@()obj.axesChanged());place(obj.ZDropDown,1,6);
            obj.DimensionDropDown=uidropdown(axisControls,'Items',{'2-D','3-D'}, ...
                'Tag','lmz-branch-dimension','Tooltip','Switch between 2-D and 3-D branch views.', ...
                'ValueChangedFcn',@(~,~)obj.axesChanged());place(obj.DimensionDropDown,1,7);
            label=uilabel(axisControls,'Text','Index');place(label,1,8);
            obj.IndexSpinner=uispinner(axisControls,'Limits',[1 Inf],'Step',1, ...
                'RoundFractionalValues','on','Tag','lmz-branch-index', ...
                'ValueChangedFcn',@(~,~)obj.indexChanged());place(obj.IndexSpinner,1,9);
            obj.PercentSlider=uislider(axisControls,'Limits',[0 100], ...
                'Tag','lmz-branch-percent','Tooltip','Navigate by percentage along the active branch.', ...
                'ValueChangedFcn',@(~,~)obj.percentChanged());place(obj.PercentSlider,1,10);
            label=uilabel(axisControls,'Text','Az');place(label,2,1);
            obj.AzimuthSpinner=uispinner(axisControls,'Limits',[-180 180],'Value',0, ...
                'Tag','lmz-branch-azimuth','ValueChangedFcn',@(~,~)obj.viewChanged());place(obj.AzimuthSpinner,2,2);
            label=uilabel(axisControls,'Text','El');place(label,2,3);
            obj.ElevationSpinner=uispinner(axisControls,'Limits',[-90 90],'Value',90, ...
                'Tag','lmz-branch-elevation','ValueChangedFcn',@(~,~)obj.viewChanged());place(obj.ElevationSpinner,2,4);
            label=uilabel(axisControls,'Text','Aspect');place(label,2,5);
            obj.AspectDropDown=uidropdown(axisControls,'Items',{'auto','equal'}, ...
                'Value','auto','Tag','lmz-branch-aspect', ...
                'ValueChangedFcn',@(~,~)obj.viewChanged());place(obj.AspectDropDown,2,6);
            label=uilabel(axisControls,'Text','Branch %');place(label,2,8);
            label=uilabel(axisControls,'Text','X lim');place(label,3,1);
            obj.XLimitsField=limitField(axisControls,'x',@()obj.applyLimits());place(obj.XLimitsField,3,2);
            label=uilabel(axisControls,'Text','Y lim');place(label,3,3);
            obj.YLimitsField=limitField(axisControls,'y',@()obj.applyLimits());place(obj.YLimitsField,3,4);
            label=uilabel(axisControls,'Text','Z lim');place(label,3,5);
            obj.ZLimitsField=limitField(axisControls,'z',@()obj.applyLimits());place(obj.ZLimitsField,3,6);
            label=uilabel(axisControls,'Text','Use [min max] or auto');place(label,3,[8 10]);
            obj.ActionControls=[obj.ActionControls {obj.DatasetList obj.VisibilityCheckBox ...
                obj.XDropDown obj.YDropDown obj.ZDropDown obj.DimensionDropDown ...
                obj.AzimuthSpinner obj.ElevationSpinner obj.AspectDropDown ...
                obj.XLimitsField obj.YLimitsField obj.ZLimitsField ...
                obj.IndexSpinner obj.PercentSlider}];
        end

        function refresh(obj,varargin)
            if obj.IsRefreshing,return,end
            obj.IsRefreshing=true;cleanup=onCleanup(@()obj.finishRefresh());
            refresh@lmz.gui.tabs.BaseTab(obj);obj.refreshCatalog();obj.refreshDatasets();obj.render();
            clear cleanup
        end

        function setPalette(obj,value)
            if ischar(value)||isstring(value),value=lmz.gui.Palette.named(value);end
            obj.Palette=value;obj.render();
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
        function controls=controlMap(obj)
            controls=struct('Axes',obj.Axes,'CatalogDropDown',obj.CatalogDropDown, ...
                'DatasetList',obj.DatasetList,'VisibilityCheckBox',obj.VisibilityCheckBox, ...
                'MetadataArea',obj.MetadataArea,'XDropDown',obj.XDropDown, ...
                'YDropDown',obj.YDropDown,'ZDropDown',obj.ZDropDown, ...
                'DimensionDropDown',obj.DimensionDropDown,'IndexSpinner',obj.IndexSpinner, ...
                'PercentSlider',obj.PercentSlider);
        end

        function beforeDelete(obj)
            figureHandle=[];
            if ~isempty(obj.Root)&&isvalid(obj.Root),figureHandle=ancestor(obj.Root,'figure');end
            if ~isempty(figureHandle)&&isvalid(figureHandle)
                figureHandle.WindowButtonMotionFcn=[];figureHandle.KeyPressFcn=[];
            end
        end
    end

    methods (Access=private)
        function finishRefresh(obj),obj.IsRefreshing=false;end
        function refreshCatalog(obj)
            switch obj.Controller.State.ModelId
                case 'slip_quadruped'
                    catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
                    files=catalog.listBranches();defaultPath=catalog.defaultBranchPath();
                    title(obj.Axes,'SLIP quadruped RoadMap');
                case 'slip_biped'
                    catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
                    files=catalog.listBranches();defaultPath=catalog.defaultBranchPath();
                    title(obj.Axes,'SLIP biped GaitMap');
                case 'slip_quad_load'
                    catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
                    records=catalog.records();files=cell(1,numel(records));
                    for index=1:numel(records),files{index}=catalog.pathFor(records(index).id);end
                    defaultPath=catalog.defaultMultiPath();title(obj.Axes,'SLIP quadruped-with-load datasets');
                otherwise
                    obj.CatalogDropDown.Items={'No built-in scientific dataset'};
                    obj.CatalogDropDown.ItemsData={''};obj.CatalogDropDown.Value='';return
            end
            labels=cell(size(files));
            for index=1:numel(files),[~,name,extension]=fileparts(files{index});labels{index}=[name extension];end
            obj.CatalogDropDown.Items=labels;obj.CatalogDropDown.ItemsData=files;
            if any(strcmp(defaultPath,files)),obj.CatalogDropDown.Value=defaultPath;end
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
                switch obj.Controller.State.ModelId
                    case 'slip_quadruped',obj.Controller.loadRoadMap(obj.CatalogDropDown.Value);
                    case 'slip_biped',obj.Controller.loadGaitMap(obj.CatalogDropDown.Value);
                    case 'slip_quad_load',obj.Controller.loadScientificLoadDataset(obj.CatalogDropDown.Value);
                end
            catch exception,obj.reportError(exception);end
        end
        function loadAll(obj)
            try
                switch obj.Controller.State.ModelId
                    case 'slip_quadruped',obj.Controller.loadAllRoadMapBranches();
                    case 'slip_biped',obj.Controller.loadAllGaitMapBranches();
                    case 'slip_quad_load',obj.Controller.loadAllScientificLoadDatasets();
                end
            catch exception,obj.reportError(exception);end
        end
        function openFolder(obj)
            start=obj.Preferences.recentDataFolder(pwd);
            folder=uigetdir(start,'Open folder containing MAT/artifact branches');
            if isequal(folder,0),return,end
            try,obj.Controller.openBranchFolder(folder);obj.Preferences.rememberDataFolder(folder); ...
            catch exception,obj.reportError(exception);end
        end
        function openFile(obj)
            start=obj.Preferences.recentDataFolder(pwd);
            [file,path]=uigetfile(fullfile(start,'*.mat'),'Open branch');if isequal(file,0),return,end
            try,obj.Controller.openBranch(fullfile(path,file));obj.Preferences.rememberDataFolder(path); ...
            catch exception,obj.reportError(exception);end
        end
        function reload(obj),try,obj.Controller.reloadActiveDataset();catch exception,obj.reportError(exception);end,end
        function remove(obj)
            if isempty(obj.Controller.State.Datasets),return,end
            try,obj.Controller.removeDataset(obj.Controller.State.ActiveDatasetId);catch exception,obj.reportError(exception);end
        end
        function datasetChanged(obj)
            try,obj.Controller.setActiveDataset(obj.DatasetList.Value);catch exception,obj.reportError(exception);end
        end
        function visibilityChanged(obj)
            try,obj.Controller.setDatasetVisibility(obj.Controller.State.ActiveDatasetId, ...
                    obj.VisibilityCheckBox.Value);catch exception,obj.reportError(exception);end
        end
        function plotSelected(obj),obj.Controller.showOnlyActiveDataset();end
        function plotAll(obj),obj.Controller.setAllDatasetsVisible(true);end
        function clearPlot(obj),obj.Controller.setAllDatasetsVisible(false);end
        function axesChanged(obj)
            try,obj.Controller.setAxisVariables(obj.XDropDown.Value,obj.YDropDown.Value, ...
                    obj.ZDropDown.Value);obj.render();catch exception,obj.reportError(exception);end
        end
        function preset(obj)
            switch obj.Controller.State.ModelId
                case 'slip_quadruped',names={'dx','dphi','y'};limits={'[0 10]','[-0.05 0.15]','[0.6 1.2]'};
                case 'slip_biped',names={'dx','alphaL','y'};limits={'auto','auto','auto'};
                case 'slip_quad_load',names={'quad_dx','tAPEX','tugline_stiffness'};limits={'auto','auto','auto'};
                otherwise,return
            end
            obj.XDropDown.Value=names{1};obj.YDropDown.Value=names{2};obj.ZDropDown.Value=names{3};
            obj.DimensionDropDown.Value='2-D';obj.AzimuthSpinner.Value=0;obj.ElevationSpinner.Value=90;
            obj.XLimitsField.Value=limits{1};obj.YLimitsField.Value=limits{2};obj.ZLimitsField.Value=limits{3};
            obj.axesChanged();obj.applyLimits();
        end
        function viewChanged(obj)
            if strcmp(obj.DimensionDropDown.Value,'3-D')
                view(obj.Axes,obj.AzimuthSpinner.Value,obj.ElevationSpinner.Value);
            else,view(obj.Axes,2);end
            if strcmp(obj.AspectDropDown.Value,'equal'),axis(obj.Axes,'equal');else,axis(obj.Axes,'normal');end
        end
        function applyLimits(obj)
            try,applyLimit(obj.Axes,'x',obj.XLimitsField.Value);applyLimit(obj.Axes,'y',obj.YLimitsField.Value);applyLimit(obj.Axes,'z',obj.ZLimitsField.Value);catch exception,obj.reportError(exception);end
        end
        function render(obj)
            if isempty(obj.Axes)||~isgraphics(obj.Axes),return,end
            cla(obj.Axes);if isempty(obj.Controller.State.Datasets),return,end
            hold(obj.Axes,'on');names=obj.Controller.State.AxisVariables;
            is3=strcmp(obj.DimensionDropDown.Value,'3-D');datasets=obj.Controller.State.Datasets;
            for index=1:numel(datasets)
                dataset=datasets{index};if ~dataset.Visible,continue,end
                x=dataset.Branch.coordinate(names{1});y=dataset.Branch.coordinate(names{2});
                color=styleField(dataset.DisplayStyle,'Color',lineColor(index));
                lineStyle=styleField(dataset.DisplayStyle,'LineStyle','-');
                marker=styleField(dataset.DisplayStyle,'Marker','none');
                if strcmp(obj.Palette.Name,'high-contrast')&&strcmp(marker,'none')
                    marker=markerFor(index);
                end
                if is3
                    z=dataset.Branch.coordinate(names{3});lineHandle=plot3(obj.Axes,x,y,z, ...
                        'Color',color,'LineStyle',lineStyle,'Marker',marker,'LineWidth',1.8);
                else
                    lineHandle=plot(obj.Axes,x,y,'Color',color,'LineStyle',lineStyle, ...
                        'Marker',marker,'LineWidth',1.8);
                end
                lineHandle.UserData=dataset.Id;
                lineHandle.ButtonDownFcn=@(~,event)obj.clicked(dataset.Id,event);
            end
            obj.plotLocked();hold(obj.Axes,'off');grid(obj.Axes,'on');
            xlabel(obj.Axes,names{1},'Interpreter','none');ylabel(obj.Axes,names{2},'Interpreter','none');
            if is3,zlabel(obj.Axes,names{3},'Interpreter','none');end
            obj.viewChanged();obj.applyLimits();
        end
        function plotLocked(obj)
            selection=obj.Controller.State.LockedSelection;if isempty(selection),return,end
            try,dataset=obj.Controller.activeDataset();catch,return,end
            if ~strcmp(selection.DatasetId,dataset.Id)||~dataset.Visible,return,end
            names=obj.Controller.State.AxisVariables;index=selection.PointIndex;
            x=dataset.Branch.coordinate(names{1});y=dataset.Branch.coordinate(names{2});
            args={'Color','k','Marker',obj.Palette.LockedMarker,'MarkerFaceColor', ...
                obj.Palette.LockedColor,'MarkerSize',12,'LineStyle','none','Tag','LockedPoint'};
            if strcmp(obj.DimensionDropDown.Value,'3-D')
                z=dataset.Branch.coordinate(names{3});plot3(obj.Axes,x(index),y(index),z(index),args{:});
            else,plot(obj.Axes,x(index),y(index),args{:});end
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
                delete(findobj(obj.Axes,'Tag','HoverPoint'));delete(findobj(obj.Axes,'Tag','HoverDataTip'));
                holdState=ishold(obj.Axes);hold(obj.Axes,'on');values=cell2mat(details.Values);
                args={'Color','k','Marker',obj.Palette.HoverMarker,'MarkerFaceColor', ...
                    obj.Palette.HoverColor,'MarkerSize',7,'LineStyle','none','Tag','HoverPoint'};
                if dimensions==3
                    plot3(obj.Axes,values(1),values(2),values(3),args{:});
                    tip=text(obj.Axes,values(1),values(2),values(3),hoverText(details,selection), ...
                        'BackgroundColor',obj.Palette.HoverColor,'Margin',3,'Tag','HoverDataTip','Interpreter','none');
                else
                    plot(obj.Axes,values(1),values(2),args{:});
                    tip=text(obj.Axes,values(1),values(2),hoverText(details,selection), ...
                        'BackgroundColor',obj.Palette.HoverColor,'Margin',3,'Tag','HoverDataTip','Interpreter','none');
                end
                tip.VerticalAlignment='bottom';if ~holdState,hold(obj.Axes,'off');end
            catch
            end
        end
        function clicked(obj,datasetId,event)
            try
                if isprop(event,'IntersectionPoint'),target=event.IntersectionPoint; ...
                else,point=obj.Axes.CurrentPoint;target=point(1,:);end
                dimensions=2;if strcmp(obj.DimensionDropDown.Value,'3-D'),dimensions=3;end
                coordinates=obj.Controller.State.AxisVariables(1:dimensions);
                selection=obj.Controller.hoverNearestPoint(datasetId,coordinates,target(1:dimensions));
                obj.Controller.lockBranchPoint(datasetId,selection.PointIndex);
            catch exception,obj.reportError(exception);end
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
        function indexChanged(obj),try,obj.Controller.selectByIndex(obj.IndexSpinner.Value);catch exception,obj.reportError(exception);end,end
        function percentChanged(obj),try,obj.Controller.selectByPercentage(obj.PercentSlider.Value);catch exception,obj.reportError(exception);end,end
        function save(obj)
            if isempty(obj.Controller.State.Datasets),return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.lmz.mat'),'Save native branch');if isequal(file,0),return,end
            try,obj.Controller.saveBranch(fullfile(path,file),obj.Controller.activeDataset().Branch);obj.Preferences.rememberOutputFolder(path);catch exception,obj.reportError(exception);end
        end
        function exportLegacy(obj)
            if isempty(obj.Controller.State.Datasets),return,end
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile(fullfile(start,'*.mat'),'Export legacy branch');if isequal(file,0),return,end
            try,obj.Controller.exportLegacyBranch(fullfile(path,file),obj.Controller.activeDataset().Branch);obj.Preferences.rememberOutputFolder(path);catch exception,obj.reportError(exception);end
        end
        function exportPlot(obj)
            start=obj.Preferences.recentOutputFolder(pwd);
            [file,path]=uiputfile({'*.png';'*.pdf'},'Export branch plot',start);if isequal(file,0),return,end
            try,obj.Controller.exportPlot(obj.Axes,fullfile(path,file));obj.Preferences.rememberOutputFolder(path);catch exception,obj.reportError(exception);end
        end
    end
end

function button=makeButton(parent,label,tag,callback)
button=uibutton(parent,'Text',label,'Tag',['lmz-branch-' tag], ...
    'Tooltip',label,'ButtonPushedFcn',@(~,~)callback());
end
function control=axisDropDown(parent,axisName,callback)
control=uidropdown(parent,'Tag',['lmz-branch-' axisName], ...
    'Tooltip',['Coordinate shown on the ' upper(axisName) ' axis.'], ...
    'ValueChangedFcn',@(~,~)callback());
end
function control=limitField(parent,axisName,callback)
control=uieditfield(parent,'text','Value','auto','Tag',['lmz-branch-' axisName '-limits'], ...
    'Tooltip','Enter auto or [minimum maximum].','ValueChangedFcn',@(~,~)callback());
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
function textValue=hoverText(details,selection)
solution=details.Solution;coordinates=cell(1,numel(details.Coordinates));for index=1:numel(coordinates),coordinates{index}=sprintf('%s=%.5g',details.Coordinates{index},details.Values{index});end
parameters=solution.ParameterSchema.names();parts=cell(1,min(4,numel(parameters)));for index=1:numel(parts),parts{index}=sprintf('%s=%.4g',parameters{index},solution.ParameterValues(index));end
gait=classificationField(solution.Classification,'Abbreviation','?');residual=diagnosticField(solution.Diagnostics,'ResidualNorm',NaN);
textValue=sprintf('%s #%d\n%s\ngait=%s residual=%.3g\n%s',details.Dataset.Name,selection.PointIndex,strjoin(coordinates,', '),gait,residual,strjoin(parts,', '));
end
function value=classificationField(source,name,fallback),if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end,end
function value=diagnosticField(source,name,fallback),if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end,end
