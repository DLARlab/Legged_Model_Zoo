classdef SidebarHost < handle
    %SIDEBARHOST Full-height capability-oriented scrollable tab host.
    properties (SetAccess=private)
        Root
        TabGroup
        Tabs = struct()
        Viewports = struct()
    end
    properties (Access=private)
        SelectionHandler = []
        LastNotifiedSelectionId = ''
        IsNotifyingSelection = false
        SharedMinimumGroups = {}
    end

    methods
        function obj=SidebarHost(parent,varargin)
            parser=inputParser;
            addParameter(parser,'SelectionHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            parse(parser,varargin{:});
            obj.SelectionHandler=parser.Results.SelectionHandler;
            obj.Root=uipanel(parent,'BorderType','none','Tag','lmz-sidebar-host');
            grid=uigridlayout(obj.Root,[1 1]);grid.Padding=[0 0 0 0];
            obj.TabGroup=uitabgroup(grid,'Tag','lmz-workbench-sidebar-tabs', ...
                'SelectionChangedFcn',@(~,~)obj.selectionChanged());
        end

        function parent=addTab(obj,id,titleText,minimumSize)
            if nargin<4,minimumSize=[320 320];end
            id=char(id);tab=uitab(obj.TabGroup,'Title',titleText, ...
                'Tag',['lmz-sidebar-' strrep(id,'_','-')]);
            tabGrid=uigridlayout(tab,[1 1]);
            tabGrid.Padding=[0 0 0 0];
            tabGrid.RowSpacing=0;tabGrid.ColumnSpacing=0;
            viewport=lmz.gui.layout.ScrollableViewport(tabGrid, ...
                'MinimumSize',minimumSize, ...
                'Tag',['lmz-sidebar-scroll-' strrep(id,'_','-')]);
            obj.Tabs.(id)=tab;obj.Viewports.(id)=viewport;
            parent=viewport.Content.Root;
        end

        function select(obj,id)
            id=char(id);
            if isfield(obj.Tabs,id)
                obj.TabGroup.SelectedTab=obj.Tabs.(id);
                % Programmatic tab selection does not consistently emit a
                % SelectionChanged callback on every supported MATLAB.
                obj.selectionChanged();
            end
        end

        function id=selectedId(obj)
            id='';names=fieldnames(obj.Tabs);
            for index=1:numel(names)
                if isequal(obj.TabGroup.SelectedTab,obj.Tabs.(names{index}))
                    id=names{index};return
                end
            end
        end

        function resetScroll(obj)
            values=struct2cell(obj.Viewports);
            for index=1:numel(values),values{index}.resetScroll();end
        end

        function setSharedMinimumGroups(obj,value)
            if isempty(value),obj.SharedMinimumGroups={};return,end
            if ~iscell(value)
                error('lmz:GUI:SidebarSharedMinimumGroups', ...
                    'Shared minimum groups must be a cell array.');
            end
            groups=cell(size(value));
            for index=1:numel(value)
                group=value{index};
                if isstring(group),group=cellstr(group);end
                if ~iscell(group)||~all(cellfun(@(item)ischar(item)|| ...
                        (isstring(item)&&isscalar(item)),group))
                    error('lmz:GUI:SidebarSharedMinimumGroups', ...
                        'Every shared minimum group must contain IDs.');
                end
                groups{index}=cellfun(@char,group,'UniformOutput',false);
            end
            obj.SharedMinimumGroups=groups;
        end

        function sizes=fitContentsToControls(obj,floorSize)
            if nargin<2,floorSize=[360 400];end
            names=fieldnames(obj.Viewports);sizes=struct();
            for index=1:numel(names)
                sizes.(names{index})=obj.Viewports.(names{index}). ...
                    fitContentToControls(floorSize);
            end
            sizes=obj.synchronizeSharedMinimumGroups(sizes);
        end

        function delete(obj)
            values=struct2cell(obj.Viewports);
            for index=1:numel(values)
                if isvalid(values{index}),delete(values{index});end
            end
            obj.Viewports=struct();obj.Tabs=struct();
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];obj.TabGroup=[];
        end
    end

    methods (Access=private)
        function selectionChanged(obj)
            id=obj.selectedId();
            if obj.IsNotifyingSelection||strcmp(id,obj.LastNotifiedSelectionId)
                return
            end
            obj.LastNotifiedSelectionId=id;
            if ~isa(obj.SelectionHandler,'function_handle'),return,end
            obj.IsNotifyingSelection=true;
            cleanup=onCleanup(@()obj.finishSelectionNotification());
            obj.SelectionHandler(id);
            clear cleanup
        end

        function sizes=synchronizeSharedMinimumGroups(obj,sizes)
            for groupIndex=1:numel(obj.SharedMinimumGroups)
                group=obj.SharedMinimumGroups{groupIndex};
                available=group(cellfun( ...
                    @(id)isfield(obj.Viewports,id),group));
                if numel(available)<2,continue,end
                minimum=[0 0];
                for index=1:numel(available)
                    viewport=obj.Viewports.(available{index});
                    minimum=max(minimum,viewport.Content.MinimumSize);
                end
                for index=1:numel(available)
                    id=available{index};viewport=obj.Viewports.(id);
                    viewport.Content.setMinimumSize(minimum);viewport.refresh();
                    sizes.(id)=minimum;
                end
            end
        end

        function finishSelectionNotification(obj)
            if isvalid(obj),obj.IsNotifyingSelection=false;end
        end
    end
end
