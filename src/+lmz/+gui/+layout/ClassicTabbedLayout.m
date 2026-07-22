classdef ClassicTabbedLayout < handle
    %CLASSICTABBEDLAYOUT Stable six-tab application layout.
    properties (SetAccess=private)
        Root
        TabGroup
        ComponentMap = struct()
        StatusDock
        StatusPanel
        OverlayController = []
        Profile
    end
    properties (Access=private)
        IsDisposed = false
    end

    methods
        function obj=ClassicTabbedLayout(parent,controller,eventBus,preferences,varargin)
            parser=inputParser;
            addParameter(parser,'ErrorHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            addParameter(parser,'StatusHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            parse(parser,varargin{:});
            obj.Profile=lmz.gui.layout.LayoutProfileRegistry.get('classic_tabs');
            obj.Root=uipanel(parent,'BorderType','none', ...
                'Tag','lmz-classic-tabbed-layout');
            grid=uigridlayout(obj.Root,[2 1]);
            grid.RowHeight={'1x',93};grid.Padding=[0 0 0 0];
            grid.RowSpacing=10;
            obj.TabGroup=uitabgroup(grid,'Tag','lmz-main-tabs');
            args={'ErrorHandler',parser.Results.ErrorHandler, ...
                'StatusHandler',parser.Results.StatusHandler};
            obj.ComponentMap.simulation=lmz.gui.tabs.SimulationTab( ...
                obj.TabGroup,controller,eventBus,preferences,args{:});
            obj.ComponentMap.branches=lmz.gui.tabs.BranchTab( ...
                obj.TabGroup,controller,eventBus,preferences,args{:});
            obj.ComponentMap.solution=lmz.gui.tabs.SolutionTab( ...
                obj.TabGroup,controller,eventBus,preferences,args{:});
            obj.ComponentMap.solve=lmz.gui.tabs.SolveTab( ...
                obj.TabGroup,controller,eventBus,preferences,args{:});
            obj.ComponentMap.continuation=lmz.gui.tabs.ContinuationTab( ...
                obj.TabGroup,controller,eventBus,preferences,args{:});
            obj.ComponentMap.optimization=lmz.gui.tabs.OptimizationTab( ...
                obj.TabGroup,controller,eventBus,preferences,args{:});
            obj.StatusDock=lmz.gui.layout.StatusDock(grid);
            obj.StatusPanel=obj.StatusDock.Panel;
        end

        function setCapabilities(obj,value)
            values=struct2cell(obj.ComponentMap);
            for index=1:numel(values),values{index}.setCapabilities(value);end
        end

        function refreshGeometry(~)
        end

        function hooks=testHooks(obj)
            hooks=struct('Id',obj.Profile.Id,'Root',obj.Root, ...
                'MainGrid',obj.Root.Children(1),'TabGroup',obj.TabGroup, ...
                'Components',obj.ComponentMap,'StatusDock',obj.StatusDock.Root, ...
                'OverlayController',obj.OverlayController);
        end

        function delete(obj)
            if obj.IsDisposed,return,end
            obj.IsDisposed=true;
            names=fieldnames(obj.ComponentMap);
            for index=1:numel(names)
                component=obj.ComponentMap.(names{index});
                if ~isempty(component)&&isvalid(component),component.dispose();end
            end
            obj.ComponentMap=struct();
            if ~isempty(obj.StatusDock)&&isvalid(obj.StatusDock)
                delete(obj.StatusDock);
            end
            obj.StatusDock=[];obj.StatusPanel=[];
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];obj.TabGroup=[];
        end
    end
end
