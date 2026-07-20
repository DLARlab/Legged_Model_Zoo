classdef ErrorDetailsDialog
    %ERRORDETAILSDIALOG Clear error summary with copyable technical details.
    methods (Static)
        function details = technicalDetails(exception)
            details = getReport(exception,'extended','hyperlinks','off');
        end

        function show(parent,exception)
            details = lmz.gui.components.ErrorDetailsDialog.technicalDetails(exception);
            if isempty(parent)||~isvalid(parent)||~usejava('desktop')
                return
            end
            dialog = uifigure('Name','Legged Model Zoo error', ...
                'Position',[parent.Position(1)+80 parent.Position(2)+80 700 430]);
            grid = uigridlayout(dialog,[3 1]);
            grid.RowHeight={54,34,0};
            uilabel(grid,'Text',exception.message,'WordWrap','on', ...
                'FontWeight','bold');
            buttons = uigridlayout(grid,[1 3]);
            detailsArea=uitextarea(grid,'Editable','off','Value',splitlines(details), ...
                'Tag','lmz-error-details','Visible','off');
            uibutton(buttons,'Text','Show details','ButtonPushedFcn', ...
                @(source,~)toggleDetails(source,grid,detailsArea));
            uibutton(buttons,'Text','Copy details','ButtonPushedFcn', ...
                @(~,~)clipboard('copy',details));
            uibutton(buttons,'Text','Close','ButtonPushedFcn',@(~,~)delete(dialog));
        end
    end
end

function toggleDetails(button,layout,area)
if strcmp(area.Visible,'off')
    area.Visible='on';layout.RowHeight={54,34,'1x'};button.Text='Hide details';
else
    area.Visible='off';layout.RowHeight={54,34,0};button.Text='Show details';
end
end
