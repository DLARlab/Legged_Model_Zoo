classdef AxisControlPanel < lmz.gui.branch.BranchComponentGroup
    methods
        function obj=AxisControlPanel(parent,callbacks)
            obj@lmz.gui.branch.BranchComponentGroup('axis_controls');
            root=uigridlayout(parent,[3 10], ...
                'Tag','lmz-branch-axis-control-panel');
            root.ColumnWidth={24,'1x',24,'1x',24,'1x',64,52,62,92};
            axesChanged=callbacks.AxesChanged;
            viewChanged=callbacks.ViewChanged;
            applyLimits=callbacks.ApplyLimits;
            label=uilabel(root,'Text','X');place(label,1,1);
            x=axisDropDown(root,'x',axesChanged);place(x,1,2);
            label=uilabel(root,'Text','Y');place(label,1,3);
            y=axisDropDown(root,'y',axesChanged);place(y,1,4);
            label=uilabel(root,'Text','Z');place(label,1,5);
            z=axisDropDown(root,'z',axesChanged);place(z,1,6);
            dimension=uidropdown(root,'Items',{'2-D','3-D'}, ...
                'Tag','lmz-branch-dimension', ...
                'Tooltip','Switch between 2-D and 3-D branch views.', ...
                'ValueChangedFcn',@(~,~)axesChanged());
            place(dimension,1,7);
            label=uilabel(root,'Text','Az');place(label,2,1);
            azimuth=uispinner(root,'Limits',[-180 180],'Value',0, ...
                'Tag','lmz-branch-azimuth', ...
                'ValueChangedFcn',@(~,~)viewChanged());
            place(azimuth,2,2);
            label=uilabel(root,'Text','El');place(label,2,3);
            elevation=uispinner(root,'Limits',[-90 90],'Value',90, ...
                'Tag','lmz-branch-elevation', ...
                'ValueChangedFcn',@(~,~)viewChanged());
            place(elevation,2,4);
            label=uilabel(root,'Text','Aspect');place(label,2,5);
            aspect=uidropdown(root,'Items',{'auto','equal'}, ...
                'Value','auto','Tag','lmz-branch-aspect', ...
                'ValueChangedFcn',@(~,~)viewChanged());
            place(aspect,2,6);
            label=uilabel(root,'Text','X lim');place(label,3,1);
            xLimits=limitField(root,'x',applyLimits);
            place(xLimits,3,2);
            label=uilabel(root,'Text','Y lim');place(label,3,3);
            yLimits=limitField(root,'y',applyLimits);
            place(yLimits,3,4);
            label=uilabel(root,'Text','Z lim');place(label,3,5);
            zLimits=limitField(root,'z',applyLimits);
            place(zLimits,3,6);
            label=uilabel(root,'Text','Use [min max] or auto');
            place(label,3,[8 10]);
            obj.own(root,struct('X',x,'Y',y,'Z',z, ...
                'Dimension',dimension,'Azimuth',azimuth, ...
                'Elevation',elevation,'Aspect',aspect, ...
                'XLimits',xLimits,'YLimits',yLimits,'ZLimits',zLimits));
        end
    end
end

function control=axisDropDown(parent,axisName,callback)
control=uidropdown(parent,'Tag',['lmz-branch-' axisName], ...
    'Tooltip',['Coordinate shown on the ' upper(axisName) ' axis.'], ...
    'ValueChangedFcn',@(~,~)callback());
end
function control=limitField(parent,axisName,callback)
control=uieditfield(parent,'text','Value','auto', ...
    'Tag',['lmz-branch-' axisName '-limits'], ...
    'Tooltip','Enter auto or [minimum maximum].', ...
    'ValueChangedFcn',@(~,~)callback());
end
function place(control,row,column)
control.Layout.Row=row;control.Layout.Column=column;
end
