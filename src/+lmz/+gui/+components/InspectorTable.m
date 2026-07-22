classdef InspectorTable
    %INSPECTORTABLE Shared construction for schema and diagnostics tables.
    methods (Static)
        function tableHandle = create(parent,editable,editCallback)
            if nargin < 2, editable = false; end
            if nargin < 3, editCallback = []; end
            grid=uigridlayout(parent,[1 1]);
            grid.Padding=[0 0 0 0];grid.RowSpacing=0;grid.ColumnSpacing=0;
            tableHandle = uitable(grid,'Tag','lmz-inspector-table');
            if editable
                tableHandle.ColumnName = {'Name','Label','Value','Unit', ...
                    'Bounds / activity / role / energy','Scale','Edited'};
                tableHandle.ColumnEditable = ...
                    [false false true false false false false];
                if ~isempty(editCallback)
                    tableHandle.CellEditCallback = editCallback;
                end
            end
        end
    end
end
