classdef CentralAnalysisWorkspace < handle
    %CENTRALANALYSISWORKSPACE Host-neutral scientific diagnostic renderer.
    properties (SetAccess=private)
        FootfallAxes
        RunOverlayAxes
        RefreshCount = 0
        SelectedViewId = ''
    end
    properties (Access=private)
        Controller
        IsDisposed = false
    end

    methods
        function obj=CentralAnalysisWorkspace(controller,footfallAxes,runOverlayAxes)
            obj.Controller=controller;
            obj.FootfallAxes=footfallAxes;
            obj.RunOverlayAxes=runOverlayAxes;
        end

        function refresh(obj,selectedViewId,force)
            % Refresh only the visible diagnostic during live runs. A forced
            % refresh initializes every diagnostic view supplied by the host.
            if obj.IsDisposed,return,end
            if nargin<2||isempty(selectedViewId)
                selectedViewId=obj.SelectedViewId;
            end
            if nargin<3,force=false;end
            obj.SelectedViewId=char(selectedViewId);
            obj.RefreshCount=obj.RefreshCount+1;
            if force||strcmp(obj.SelectedViewId,'hildebrand_footfall')
                obj.renderFootfallAnalysis();
            end
            if force||strcmp(obj.SelectedViewId,'run_overlay')
                obj.renderRunAnalysis();
            end
        end

        function hooks=testHooks(obj)
            hooks=struct('FootfallAxes',obj.FootfallAxes, ...
                'RunOverlayAxes',obj.RunOverlayAxes, ...
                'RefreshCount',obj.RefreshCount, ...
                'SelectedViewId',obj.SelectedViewId, ...
                'IsDisposed',obj.IsDisposed);
        end

        function dispose(obj)
            if obj.IsDisposed,return,end
            obj.IsDisposed=true;
            obj.Controller=[];
            obj.FootfallAxes=[];
            obj.RunOverlayAxes=[];
        end

        function delete(obj)
            obj.dispose();
        end
    end

    methods (Access=private)
        function renderFootfallAnalysis(obj)
            axesHandle=obj.FootfallAxes;
            if isempty(axesHandle)||~isgraphics(axesHandle),return,end
            cla(axesHandle);simulation=obj.Controller.State.Simulation;
            if isa(simulation,'lmz.api.SimulationResult')&& ...
                    isstruct(simulation.Modes)
                names=fieldnames(simulation.Modes);
                valid=false(size(names));
                for index=1:numel(names)
                    values=simulation.Modes.(names{index});
                    valid(index)=(isnumeric(values)||islogical(values))&& ...
                        isvector(values)&&numel(values)==numel(simulation.Time);
                end
                names=names(valid);
                if ~isempty(names)
                    time=simulation.Time(:);duration=time(end)-time(1);
                    if duration<=0,duration=1;end
                    phase=(time-time(1))/duration;
                    hold(axesHandle,'on');
                    for index=1:numel(names)
                        contact=double(simulation.Modes.(names{index})(:));
                        stairs(axesHandle,phase,index+0.34*contact, ...
                            'LineWidth',1.8,'DisplayName', ...
                            strrep(names{index},'_',' '));
                    end
                    hold(axesHandle,'off');grid(axesHandle,'on');
                    xlim(axesHandle,[0 1]);
                    ylim(axesHandle,[0.7 numel(names)+0.7]);
                    axesHandle.YTick=1:numel(names);
                    axesHandle.YTickLabel=strrep(names,'_',' ');
                    xlabel(axesHandle,'Normalized run time');
                    title(axesHandle,'Contact modes / footfall sequence');
                    return
                end
            end
            datasets=obj.Controller.State.Datasets;
            if ~isempty(datasets)
                branch=obj.Controller.activeDataset().Branch;
                labels=branchClassificationLabels(branch);
                [uniqueLabels,codes]=stableLabelCodes(labels);
                stairs(axesHandle,1:branch.pointCount(),codes, ...
                    'LineWidth',1.7,'Marker','.');grid(axesHandle,'on');
                xlim(axesHandle,[1 max(2,branch.pointCount())]);
                axesHandle.YTick=1:numel(uniqueLabels);
                axesHandle.YTickLabel=uniqueLabels;
                xlabel(axesHandle,'Branch point index');
                ylabel(axesHandle,'Registered classification');
                title(axesHandle,'Branch gait / classification map');
                return
            end
            renderEmptyAnalysis(axesHandle, ...
                'Load a branch or run a simulation to view footfalls.');
        end

        function renderRunAnalysis(obj)
            axesHandle=obj.RunOverlayAxes;
            if isempty(axesHandle)||~isgraphics(axesHandle),return,end
            cla(axesHandle);hold(axesHandle,'on');rendered=false;
            progress=obj.Controller.State.SolveProgress;
            if isa(progress,'lmz.data.SolveProgress')&& ...
                    ~isempty(progress.Snapshots)
                snapshots=progress.Snapshots;
                residual=arrayfun(@(item)item.ScaledResidual,snapshots);
                selected=isfinite(residual);
                if any(selected)
                    semilogy(axesHandle,find(selected), ...
                        max(residual(selected),eps),'o-', ...
                        'LineWidth',1.7,'DisplayName','solve residual');
                    rendered=true;
                end
            end
            result=obj.Controller.State.ContinuationResult;
            if isa(result,'lmz.data.ContinuationResult')&& ...
                    ~isempty(result.Snapshots)
                snapshots=result.Snapshots;
                residual=arrayfun(@(item)analysisDiagnostic( ...
                    item.Diagnostics,'ResidualNorm',NaN),snapshots);
                selected=isfinite(residual);
                if any(selected)
                    semilogy(axesHandle,find(selected), ...
                        max(residual(selected),eps),'s--', ...
                        'LineWidth',1.6, ...
                        'DisplayName','continuation residual');
                    rendered=true;
                end
            end
            preview=obj.Controller.State.ContinuationPreview;
            if isstruct(preview)&&isfield(preview,'State')&& ...
                    isstruct(preview.State)
                residual=analysisDiagnostic(preview.State, ...
                    'ResidualNorm',NaN);
                point=analysisDiagnostic(preview.State,'PointIndex',1);
                if isfinite(residual)&&isfinite(point)
                    semilogy(axesHandle,point,max(residual,eps),'p', ...
                        'MarkerSize',11,'LineWidth',1.8, ...
                        'DisplayName','live continuation');
                    rendered=true;
                end
            end
            hold(axesHandle,'off');
            if ~rendered
                renderEmptyAnalysis(axesHandle, ...
                    'Start a solve or continuation run to view diagnostics.');
                return
            end
            grid(axesHandle,'on');xlabel(axesHandle,'Run update / point');
            ylabel(axesHandle,'Scaled residual norm');
            title(axesHandle,'Live solve and continuation diagnostics');
            legend(axesHandle,'show','Location','best');
        end
    end
end

function labels=branchClassificationLabels(branch)
labels=cell(1,branch.pointCount());
for index=1:numel(labels)
    classification=branch.Classifications{index};label='unclassified';
    if isstruct(classification)&&isfield(classification,'Abbreviation')&& ...
            ~isempty(classification.Abbreviation)
        label=char(classification.Abbreviation);
    elseif isstruct(classification)&&isfield(classification,'Name')&& ...
            ~isempty(classification.Name)
        label=char(classification.Name);
    elseif isfield(branch.Observables{index},'gait_abbreviation')
        label=char(branch.Observables{index}.gait_abbreviation);
    end
    labels{index}=label;
end
end

function [names,codes]=stableLabelCodes(labels)
names={};codes=zeros(1,numel(labels));
for index=1:numel(labels)
    code=find(strcmp(labels{index},names),1);
    if isempty(code)
        names{end+1}=labels{index}; %#ok<AGROW>
        code=numel(names);
    end
    codes(index)=code;
end
if isempty(names),names={'unclassified'};codes=ones(size(labels));end
end

function renderEmptyAnalysis(axesHandle,message)
cla(axesHandle);text(axesHandle,0.5,0.5,message,'Units','normalized', ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'Interpreter','none');
xlim(axesHandle,[0 1]);ylim(axesHandle,[0 1]);grid(axesHandle,'off');
end

function value=analysisDiagnostic(source,name,fallback)
value=fallback;
if isstruct(source)&&isfield(source,name)&&isnumeric(source.(name))&& ...
        isscalar(source.(name))
    value=source.(name);
end
end
