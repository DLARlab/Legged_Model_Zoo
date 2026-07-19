classdef InspectorTable
    %INSPECTORTABLE Shared construction for schema and diagnostics tables.
    methods (Static)
        function tableHandle = create(parent,editable,editCallback)
            if nargin < 2, editable = false; end
            if nargin < 3, editCallback = []; end
            tableHandle = uitable(parent,'Units','normalized', ...
                'Position',[0 0 1 1],'Tag','lmz-inspector-table');
            if editable
                tableHandle.ColumnName = {'Name','Label','Value','Unit', ...
                    'Bounds / activity','Scale','Edited'};
                tableHandle.ColumnEditable = ...
                    [false false true false false false false];
                if ~isempty(editCallback)
                    tableHandle.CellEditCallback = editCallback;
                end
            end
        end
    end
end
