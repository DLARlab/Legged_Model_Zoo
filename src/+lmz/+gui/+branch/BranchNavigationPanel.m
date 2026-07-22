classdef BranchNavigationPanel < lmz.gui.branch.BranchComponentGroup
    methods
        function obj=BranchNavigationPanel(parent,callbacks)
            obj@lmz.gui.branch.BranchComponentGroup('navigation');
            root=uigridlayout(parent,[2 3], ...
                'Tag','lmz-branch-navigation-panel');
            root.Padding=[0 0 0 0];
            root.ColumnWidth={52,62,92};
            indexChanged=callbacks.IndexChanged;
            percentChanged=callbacks.PercentChanged;
            label=uilabel(root,'Text','Index');place(label,1,1);
            indexSpinner=uispinner(root,'Limits',[1 Inf],'Step',1, ...
                'RoundFractionalValues','on','Tag','lmz-branch-index', ...
                'ValueChangedFcn',@(~,~)indexChanged());
            place(indexSpinner,1,2);
            percentage=uislider(root,'Limits',[0 100], ...
                'Tag','lmz-branch-percent', ...
                'Tooltip','Navigate by percentage along the active branch.', ...
                'ValueChangedFcn',@(~,~)percentChanged());
            place(percentage,1,3);
            label=uilabel(root,'Text','Branch %');place(label,2,1);
            obj.own(root,struct('Index',indexSpinner, ...
                'Percentage',percentage));
        end
    end
end

function place(control,row,column)
control.Layout.Row=row;control.Layout.Column=column;
end
