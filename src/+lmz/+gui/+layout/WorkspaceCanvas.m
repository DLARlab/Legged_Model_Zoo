classdef WorkspaceCanvas < handle
    %WORKSPACECANVAS Persistent central-view tab host.
    properties (SetAccess=private)
        Root
        TabGroup
        Views = struct()
    end
    properties (Access=private)
        SelectionHandler = []
    end

    methods
        function obj=WorkspaceCanvas(parent,varargin)
            parser=inputParser;
            addParameter(parser,'SelectionHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            parse(parser,varargin{:});
            obj.SelectionHandler=parser.Results.SelectionHandler;
            obj.Root=uipanel(parent,'Title','Workspace', ...
                'Tag','lmz-workspace-canvas');
            grid=uigridlayout(obj.Root,[1 1]);grid.Padding=[6 6 6 6];
            obj.TabGroup=uitabgroup(grid,'Tag','lmz-central-view-tabs', ...
                'SelectionChangedFcn',@(~,~)obj.selectionChanged());
        end

        function parent=addView(obj,id,titleText)
            id=char(id);
            tab=uitab(obj.TabGroup,'Title',titleText, ...
                'Tag',['lmz-central-view-' strrep(id,'_','-')]);
            parent=uigridlayout(tab,[1 1]);parent.Padding=[0 0 0 0];
            parent.RowSpacing=0;parent.ColumnSpacing=0;
            obj.Views.(id)=tab;
        end

        function select(obj,id)
            id=char(id);
            if isfield(obj.Views,id)
                obj.TabGroup.SelectedTab=obj.Views.(id);
                % Keep programmatic selection behavior identical to a user
                % click on MATLAB releases that suppress this callback.
                obj.selectionChanged();
            end
        end

        function id=selectedId(obj)
            id='';names=fieldnames(obj.Views);
            for index=1:numel(names)
                if isequal(obj.TabGroup.SelectedTab,obj.Views.(names{index}))
                    id=names{index};return
                end
            end
        end

        function delete(obj)
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];obj.TabGroup=[];obj.Views=struct();
        end
    end

    methods (Access=private)
        function selectionChanged(obj)
            if isa(obj.SelectionHandler,'function_handle')
                obj.SelectionHandler(obj.selectedId());
            end
        end
    end
end
