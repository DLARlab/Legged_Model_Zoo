classdef WorkbenchShell < handle
    %WORKBENCHSHELL Select and safely replace application placement profiles.
    properties (SetAccess=private)
        Root
        Profile
        Layout
        ComponentMap = struct()
        StatusPanel = []
        TabGroup = []
        OverlayController = []
    end
    properties (Access=private)
        HostGrid
        Controller
        EventBus
        Preferences
        ErrorHandler = []
        StatusHandler = []
        IsDisposed = false
    end

    methods
        function obj=WorkbenchShell(parent,controller,eventBus,preferences,varargin)
            parser=inputParser;
            addParameter(parser,'ProfileId','classic_tabs', ...
                @(value)ischar(value)||(isstring(value)&&isscalar(value)));
            addParameter(parser,'ErrorHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            addParameter(parser,'StatusHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            parse(parser,varargin{:});
            obj.Controller=controller;obj.EventBus=eventBus;
            obj.Preferences=preferences;
            obj.ErrorHandler=parser.Results.ErrorHandler;
            obj.StatusHandler=parser.Results.StatusHandler;
            obj.Root=uipanel(parent,'BorderType','none','Tag','lmz-workbench-shell');
            obj.HostGrid=uigridlayout(obj.Root,[1 1]);
            obj.HostGrid.Padding=[0 0 0 0];
            obj.HostGrid.RowSpacing=0;obj.HostGrid.ColumnSpacing=0;
            obj.select(char(parser.Results.ProfileId));
        end

        function select(obj,id,force)
            if nargin<3,force=false;end
            id=char(id);profile=lmz.gui.layout.LayoutProfileRegistry.get(id);
            if ~logical(force)&&~isempty(obj.Layout)&&isvalid(obj.Layout)&& ...
                    strcmp(obj.Profile.Id,id)
                return
            end
            if ~isempty(obj.Layout)&&isvalid(obj.Layout),delete(obj.Layout);end
            obj.Layout=[];obj.ComponentMap=struct();obj.StatusPanel=[];
            obj.TabGroup=[];obj.OverlayController=[];
            % Resolve a newly created host and flush a deleted profile before
            % building its replacement.  Without this boundary, MATLAB can
            % ask nested UIAxes/tab SceneNodes to lay out against the default
            % unresolved 100-by-100 grid and report nonfinite UnitPositions.
            drawnow nocallbacks
            args={'ErrorHandler',obj.ErrorHandler, ...
                'StatusHandler',obj.StatusHandler};
            switch id
                case 'scientific_workbench'
                    layout=lmz.gui.layout.ScientificWorkbenchLayout( ...
                        obj.HostGrid,obj.Controller,obj.EventBus, ...
                        obj.Preferences,args{:});
                case 'classic_tabs'
                    layout=lmz.gui.layout.ClassicTabbedLayout( ...
                        obj.HostGrid,obj.Controller,obj.EventBus, ...
                        obj.Preferences,args{:});
                otherwise
                    error('lmz:GUI:LayoutProfile','Unsupported layout %s.',id);
            end
            obj.Layout=layout;obj.Profile=profile;
            obj.ComponentMap=layout.ComponentMap;
            obj.StatusPanel=layout.StatusPanel;
            obj.TabGroup=layout.TabGroup;
            if isprop(layout,'OverlayController')
                obj.OverlayController=layout.OverlayController;
            else
                obj.OverlayController=[];
            end
            if ismethod(obj.Preferences,'setLayoutProfile')
                try
                    obj.Preferences.setLayoutProfile(id);
                catch
                end
            end
        end

        function setCapabilities(obj,value)
            if ~isempty(obj.Layout)&&isvalid(obj.Layout)
                obj.Layout.setCapabilities(value);
            end
        end

        function refreshGeometry(obj)
            if ~isempty(obj.Layout)&&isvalid(obj.Layout)
                obj.Layout.refreshGeometry();
            end
        end

        function hooks=testHooks(obj)
            hooks=obj.Layout.testHooks();
        end

        function delete(obj)
            if obj.IsDisposed,return,end
            obj.IsDisposed=true;
            if ~isempty(obj.Layout)&&isvalid(obj.Layout),delete(obj.Layout);end
            obj.Layout=[];obj.ComponentMap=struct();obj.StatusPanel=[];
            obj.TabGroup=[];obj.OverlayController=[];
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];obj.HostGrid=[];
        end
    end
end
