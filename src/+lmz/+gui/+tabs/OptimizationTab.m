classdef OptimizationTab < lmz.gui.tabs.BaseTab
    %OPTIMIZATIONTAB Scientific-fit controls and result presentation.
    properties (SetAccess=private)
        ObjectiveAxes
        SensitivityAxes
        R2Axes
        RunButton
        CancelButton
        StrideCountSpinner
        PlanStatusLabel
    end

    methods
        function obj=OptimizationTab(parent,controller,eventBus,preferences,varargin)
            tab=uitab(parent,'Title','Optimization','Tag','lmz-tab-optimization');
            obj@lmz.gui.tabs.BaseTab(tab,controller,eventBus,preferences,varargin{:});
            obj.Id='optimization';obj.CapabilityName='optimize';obj.build();
            obj.subscribe({lmz.gui.PresentationEvents.ModelChanged, ...
                lmz.gui.PresentationEvents.ProblemChanged, ...
                lmz.gui.PresentationEvents.WorkingSolutionChanged, ...
                lmz.gui.PresentationEvents.OptimizationChanged, ...
                lmz.gui.PresentationEvents.StridePlanChanged, ...
                lmz.gui.PresentationEvents.RunStateChanged});
            obj.setCapabilities(controller.capabilities());obj.refresh();
        end

        function build(obj)
            grid=uigridlayout(obj.Root,[2 3]);grid.RowHeight={'1x',40};
            obj.ObjectiveAxes=uiaxes(grid,'Tag','lmz-optimization-objective');
            title(obj.ObjectiveAxes,'Objective history');
            obj.SensitivityAxes=uiaxes(grid,'Tag','lmz-optimization-sensitivity');
            title(obj.SensitivityAxes,'Sensitivity / terms');
            obj.R2Axes=uiaxes(grid,'Tag','lmz-optimization-r2');
            title(obj.R2Axes,'Fit quality');
            controls=uigridlayout(grid,[1 5]);place(controls,2,[1 3]);
            uilabel(controls,'Text','Plan strides');
            obj.StrideCountSpinner=uispinner(controls,'Limits',[1 100], ...
                'Value',1,'Step',1,'RoundFractionalValues','on', ...
                'Tag','lmz-optimization-stride-count', ...
                'ValueChangedFcn',@(~,~)obj.strideCountChanged());
            obj.PlanStatusLabel=uilabel(controls,'Text','No plan', ...
                'Tag','lmz-optimization-plan-status');
            obj.RunButton=uibutton(controls,'Text','Run fit (supported models)', ...
                'Tag','lmz-optimization-run', ...
                'Tooltip','Run the bounded fit for the selected optimization problem.', ...
                'ButtonPushedFcn',@(~,~)obj.optimize());
            obj.CancelButton=uibutton(controls,'Text','Cancel fit', ...
                'Tag','lmz-optimization-cancel', ...
                'Tooltip','Request a controlled stop of the current fit.', ...
                'ButtonPushedFcn',@(~,~)obj.Controller.stopCurrentRun());
            obj.ActionControls={obj.RunButton obj.StrideCountSpinner};
            obj.CancelControls={obj.CancelButton};
        end

        function refresh(obj,varargin)
            refresh@lmz.gui.tabs.BaseTab(obj);
            result=obj.Controller.State.OptimizationResult;
            obj.StrideCountSpinner.Value= ...
                obj.Controller.State.RequestedStrideCount;
            plan=obj.Controller.State.StridePlan;
            if isempty(plan)
                obj.PlanStatusLabel.Text='No completed plan';
            else
                obj.PlanStatusLabel.Text=sprintf('%d/%d strides complete', ...
                    plan.CompletedStrideCount,plan.RequestedStrideCount);
            end
            if isempty(result)
                cla(obj.ObjectiveAxes);cla(obj.SensitivityAxes);cla(obj.R2Axes);
                title(obj.ObjectiveAxes,'Objective history');
                title(obj.SensitivityAxes,'Sensitivity / terms');
                title(obj.R2Axes,'Fit quality');
                return
            end
            obj.renderResult(result);
        end

        function hooks=testHooks(obj)
            hooks=testHooks@lmz.gui.tabs.BaseTab(obj);
            hooks.Controls=obj.controlMap();
        end

    end

    methods (Static)
        function value=descriptor()
            value=struct('Id','optimization','Title','Optimization', ...
                'Purpose','Configure, run, cancel, compare, and save scientific fits.');
        end
    end

    methods (Access=protected)
        function onPresentationEvents(obj,batch)
            names={batch.Name};
            if any(ismember(names,{lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged, ...
                    lmz.gui.PresentationEvents.OptimizationChanged, ...
                    lmz.gui.PresentationEvents.StridePlanChanged}))
                obj.refresh(batch);
            end
        end

        function controls=controlMap(obj)
            controls=struct('ObjectiveAxes',obj.ObjectiveAxes, ...
                'SensitivityAxes',obj.SensitivityAxes,'R2Axes',obj.R2Axes, ...
                'RunButton',obj.RunButton,'CancelButton',obj.CancelButton, ...
                'StrideCountSpinner',obj.StrideCountSpinner, ...
                'PlanStatusLabel',obj.PlanStatusLabel);
        end
    end

    methods (Access=private)
        function strideCountChanged(obj)
            state=obj.Controller.State;
            try
                obj.Controller.setStrideSettings( ...
                    obj.StrideCountSpinner.Value,state.CompletionPolicy, ...
                    state.FailurePolicy,state.EnergyNeutralOnly);
            catch exception
                obj.refresh();obj.reportError(exception);
            end
        end

        function optimize(obj)
            if ~obj.Controller.capabilities().optimize
                obj.reportStatus('Selected problem does not support optimization.');
                return
            end
            try
                obj.Controller.runOptimization(struct());
            catch exception
                obj.reportError(exception);
            end
        end

        function renderResult(obj,result)
            history=result.History;if isempty(history),history=result.Objective;end
            semilogy(obj.ObjectiveAxes,max(history,eps),'o-');grid(obj.ObjectiveAxes,'on');
            xlabel(obj.ObjectiveAxes,'Iteration');ylabel(obj.ObjectiveAxes,'Objective');
            if strcmp(obj.Controller.State.ModelId,'slip_quad_load')
                problem=obj.Controller.Registry.createModel('slip_quad_load').createProblem( ...
                    'multi_stride_fit',struct());
                lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotSensitivity( ...
                    obj.SensitivityAxes,problem.Dataset.SensitivityStudyData);
                diagnostics=result.Provenance.diagnostics;
                lmzmodels.slip_quad_load.QuadLoadPlotProvider.plotR2( ...
                    obj.R2Axes,diagnostics.R2);
            else
                plotTerms(obj.SensitivityAxes,result.Terms);
                cla(obj.R2Axes);text(obj.R2Axes,.5,.5, ...
                    'R-squared is not defined for this fit','HorizontalAlignment','center');
                axis(obj.R2Axes,'off');
            end
        end
    end
end

function place(control,row,column)
control.Layout.Row=row;control.Layout.Column=column;
end

function plotTerms(axesHandle,terms)
names=fieldnames(terms);values=zeros(1,numel(names));
for index=1:numel(names)
    item=terms.(names{index});
    if isnumeric(item)&&isscalar(item),values(index)=item;
    elseif isstruct(item)&&isfield(item,'Value')
        values(index)=item.Value;
        if isfield(item,'Weight'),values(index)=values(index)*item.Weight;end
    end
end
cla(axesHandle);bar(axesHandle,values);grid(axesHandle,'on');
axesHandle.XTick=1:numel(names);axesHandle.XTickLabel=strrep(names,'_',' ');
axesHandle.XTickLabelRotation=25;ylabel(axesHandle,'Weighted contribution');
end
