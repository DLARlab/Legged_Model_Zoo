classdef BranchCanvas < lmz.gui.branch.BranchComponentGroup
    methods
        function obj=BranchCanvas(parent)
            obj@lmz.gui.branch.BranchComponentGroup('branch_canvas');
            axesHandle=uiaxes(parent,'Tag','lmz-branch-axes');
            axesHandle.XGrid='on';axesHandle.YGrid='on';
            title(axesHandle,'Scientific branches');
            obj.own(axesHandle,struct('Axes',axesHandle));
        end
    end
end
