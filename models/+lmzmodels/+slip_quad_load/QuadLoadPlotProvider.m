classdef QuadLoadPlotProvider
    %QUADLOADPLOTPROVIDER Selectable clean and source-derived load plots.
    methods (Static)
        function handles=plotBodyAndLegs(ax,simulation,varargin)
            names={'quad_dx','quad_y','quad_dy','quad_phi','quad_dphi', ...
                'alphaBL','dalphaBL','alphaFL','dalphaFL', ...
                'alphaBR','dalphaBR','alphaFR','dalphaFR'};
            handles=plotNamed(ax,simulation,names,'Quadruped body and leg states');
        end

        function handles=plotLegTrajectories(ax,simulation,profile)
            if nargin<3,profile=[];end
            if ~isResearch(profile)
                handles=lmzmodels.slip_quad_load.QuadLoadPlotProvider. ...
                    plotBodyAndLegs(ax,simulation);return
            end
            indices={'dalphaBL','dalphaFL','dalphaFR','dalphaBR'};
            count=simulation.Parameters.stride_count;
            time=linspace(0,count,numel(simulation.Time));
            colors=[8 163 119;214 99 8;239 229 72;8 118 179]/255;
            cla(ax);hold(ax,'on');handles=gobjects(1,4);allValues=[];
            for leg=1:4
                values=simulation.state(indices{leg});allValues=[allValues;values(:)]; %#ok<AGROW>
                handles(leg)=plot(ax,time,values,'-','LineWidth',1.5, ...
                    'Color',colors(leg,:));
            end
            hold(ax,'off');xlabel(ax,'Stride Time [%]', ...
                'Interpreter','none','FontSize',12);
            ylabel(ax,'Angular Velocity $[\sqrt{g/l_0}]$', ...
                'Interpreter','latex','FontSize',12);
            title(ax,'Leg Angular Velocities','FontSize',12);xlim(ax,[0 count]);
            low=min(allValues);high=max(allValues);
            if ~isfinite(low)||~isfinite(high)||low==high,low=-5;high=5;end
            padding=.05*(high-low);ylim(ax,[min(low-padding,-5),max(high+padding,5)]);
            pbaspect(ax,[2*count 1 1]);
            setQualification(ax,struct('sourceLegendPresent',false, ...
                'timePolicy','Uniform normalized stride time, matching source.'));
        end

        function handles=plotLoad(ax,simulation,varargin)
            handles=plotNamed(ax,simulation,{'load_x','load_dx','load_y','load_dy'}, ...
                'Load states');
        end

        function handles=plotGRF(ax,simulation,varargin)
            labels={'BL','FL','BR','FR'};
            components={simulation.GroundReactionForces(:,1:4), ...
                simulation.GroundReactionForces(:,5:8), ...
                simulation.GroundReactionForces(:,9:12)};
            styles={'-','--',':'};componentLabels={'mag','x','y'};
            handles=gobjects(1,12);cla(ax);hold(ax,'on');slot=0;
            for component=1:3
                for leg=1:4
                    slot=slot+1;handles(slot)=plot(ax,simulation.Time, ...
                        components{component}(:,leg),'LineStyle',styles{component}, ...
                        'LineWidth',1.2,'DisplayName', ...
                        sprintf('%s %s',labels{leg},componentLabels{component}));
                end
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');ylabel(ax,'GRF');
            title(ax,'Ground reaction forces');legend(ax,'show','Location','best');
        end

        function handles=plotTugline(ax,simulation,experimental,profile)
            if nargin<3,experimental=[];end
            if nargin<4,profile=[];end
            if isResearch(profile)
                handles=researchTugline(ax,simulation,experimental);return
            end
            cla(ax);hold(ax,'on');handles=gobjects(0);
            handles(end+1)=plot(ax,simulation.Observables.normalized_stride_time, ...
                simulation.Observables.tugline_force,'LineWidth',1.8, ...
                'DisplayName','Simulated');
            if ~isempty(experimental)
                if iscell(experimental),experimental=vertcat(experimental{:});end
                time=linspace(0,simulation.Observables.stride_count,numel(experimental));
                handles(end+1)=plot(ax,time,experimental(:),'--','LineWidth',1.4, ...
                    'DisplayName','Observed');
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Stride time');
            ylabel(ax,'Tugline force');title(ax,'Tugline force');
            legend(ax,'show','Location','best');
        end

        function handles=plotFootfall(ax,simulation,experimental,profile)
            if nargin<3,experimental=[];end
            if nargin<4,profile=[];end
            if isResearch(profile)
                handles=researchFootfall(ax,simulation,experimental);return
            end
            phases=footfallPhases(simulation);cla(ax);hold(ax,'on');
            handles=gobjects(0);colors=lines(4);
            for stride=1:size(phases,1)
                for leg=1:4
                    x=phases(stride,2*leg-1:2*leg);
                    handles(end+1)=plot(ax,x,[leg leg],'-','LineWidth',7, ...
                        'Color',colors(leg,:)); %#ok<AGROW>
                end
            end
            if ~isempty(experimental)&&~isstruct(experimental)
                for stride=1:size(experimental,1)
                    for leg=1:4
                        plot(ax,experimental(stride,2*leg-1:2*leg), ...
                            [leg+.18 leg+.18],':','LineWidth',2, ...
                            'Color',colors(leg,:));
                    end
                end
            end
            hold(ax,'off');grid(ax,'on');yticks(ax,1:4);
            yticklabels(ax,{'BL','FL','FR','BR'});xlabel(ax,'Stride time');
            title(ax,'Footfall sequence');
        end

        function handles=plotSensitivity(ax,sensitivity,profile)
            if nargin<3,profile=[];end
            if isResearch(profile)
                handles=researchSensitivity(ax,sensitivity);return
            end
            cla(ax);handles=gobjects(0);
            if isempty(fieldnames(sensitivity)),title(ax,'No sensitivity data');return,end
            if isfield(sensitivity,'percs')&&isfield(sensitivity,'C')
                handles=plot(ax,sensitivity.percs,sensitivity.C.','LineWidth',1.2);
                grid(ax,'on');xlabel(ax,'Perturbation (%)','Interpreter','none');
                ylabel(ax,'Objective');
                title(ax,'Sensitivity');
                if isfield(sensitivity,'names')
                    legend(ax,cellstr(sensitivity.names),'Location','best');
                end
            end
        end

        function handles=plotR2(ax,r2,profile)
            if nargin<3,profile=[];end
            if isResearch(profile)
                handles=researchR2(ax,r2);return
            end
            labels={'Stride duration','Footfall','Tugline','Weighted'};
            values=[r2.strideduration,r2.footfalltiming,r2.loadingforce,r2.weighted];
            cla(ax);handles=bar(ax,values);xticks(ax,1:4);xticklabels(ax,labels);
            ylim(ax,[min(0,min(values)-.1),1]);grid(ax,'on');ylabel(ax,'R^2');
            title(ax,'Fit quality');
        end
    end
end

function handles=plotNamed(ax,simulation,names,plotTitle)
cla(ax);hold(ax,'on');handles=gobjects(1,numel(names));
for index=1:numel(names)
    handles(index)=plot(ax,simulation.Time,simulation.state(names{index}), ...
        'LineWidth',1.2,'DisplayName',names{index});
end
hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');title(ax,plotTitle);
legend(ax,'show','Location','best');
end

function result=isResearch(profile)
if isa(profile,'lmz.viz.VisualizationProfile')
    value=profile.PlotProfile;
elseif ischar(profile)
    value=profile;
elseif isstring(profile)&&isscalar(profile)
    value=char(profile);
else
    value='';
end
result=strcmp(value,'research_legacy');
end

function phases=footfallPhases(simulation)
phases=simulation.Parameters.per_stride_parameters(:,1:8)./ ...
    simulation.Parameters.per_stride_parameters(:,9);
phases=phases+((0:size(phases,1)-1).');
phases=phases(:,[1 2 3 4 7 8 5 6]);
end

function handles=researchFootfall(ax,simulation,experimental)
phases=footfallPhases(simulation);count=size(phases,1);
colors=[8 118 179;239 229 72;214 99 8;8 163 119]/255;
halfWidth=.25;handles=gobjects(0);cla(ax);hold(ax,'on');box(ax,'on');
[meanSequence,stdSequence,hasExperiment]=experimentalFootfall(experimental);
if hasExperiment
    for stride=1:size(meanSequence,1)
        for leg=1:4
            values=meanSequence(stride,2*leg-1:2*leg);center=5-leg+.15;
            handles(end+1)=fill(ax,[values(1) values(2) values(2) values(1)], ...
                center+halfWidth/2*[-1 -1 1 1],'w','EdgeColor','k', ...
                'LineWidth',1.5); %#ok<AGROW>
            if ~isempty(stdSequence)
                for event=1:2
                    meanValue=values(event);deviation=stdSequence(stride,2*leg-2+event);
                    handles(end+1)=plot(ax,meanValue+[-deviation deviation], ...
                        [center center],'k-','LineWidth',1.5); %#ok<AGROW>
                    handles(end+1)=plot(ax,repmat(meanValue-deviation,1,2), ...
                        center+halfWidth/8*[-1 1],'k-','LineWidth',1); %#ok<AGROW>
                    handles(end+1)=plot(ax,repmat(meanValue+deviation,1,2), ...
                        center+halfWidth/8*[-1 1],'k-','LineWidth',1); %#ok<AGROW>
                end
            end
        end
    end
end
for stride=1:count
    for leg=1:4
        values=phases(stride,2*leg-1:2*leg);center=5-leg-.15;
        handles(end+1)=fill(ax,[values(1) values(2) values(2) values(1)], ...
            center+halfWidth/2*[-1 -1 1 1],colors(leg,:), ...
            'EdgeColor','none'); %#ok<AGROW>
    end
end
xlim(ax,[0 count]);ylim(ax,[.5 4.5]);xticks(ax,0:.25:count);
yticks(ax,1:4);yticklabels(ax,{'RH','RF','LF','LH'});
xlabel(ax,'Stride Time  [%]','Interpreter','none');title(ax,'Footfall Sequence');
pbaspect(ax,[2*count 1 1]);
legendHandles=gobjects(1,4);labels=cell(1,4);
tickLabels={'RH','RF','LF','LH'};
for leg=1:4
    legendHandles(leg)=patch('Parent',ax,'XData',nan,'YData',nan, ...
        'FaceColor',colors(leg,:),'EdgeColor','none');
    labels{leg}=['Sim - ' tickLabels{leg}];
end
legendHandles=fliplr(legendHandles);labels=fliplr(labels);
if hasExperiment
    expHandle=patch('Parent',ax,'XData',nan,'YData',nan, ...
        'FaceColor','w','EdgeColor','k','LineWidth',1.5);
    legendHandles=[expHandle legendHandles];labels=[{'Exp'} labels];
end
location='northeastoutside';if count==1,location='best';end
legend(ax,legendHandles,labels,'Location',location,'Box','off');hold(ax,'off');
setQualification(ax,struct( ...
    'sourceColorLegendMismatchPreserved',true, ...
    'actualPatchOrder','LH_blue LF_yellow RF_orange RH_green', ...
    'legendOrder','LH_green LF_orange RF_yellow RH_blue'));
end

function [meanSequence,stdSequence,present]=experimentalFootfall(value)
meanSequence=[];stdSequence=[];present=~isempty(value);
if ~present,return,end
if ~isstruct(value),meanSequence=value;return,end
names=fieldnames(value);meanName=firstContaining(names,{'exp','mean'});
if isempty(meanName)
    error('lmz:slip_quad_load:ResearchFootfall', ...
        'Experimental footfall structure has no mean sequence.');
end
meanSequence=value.(meanName);stdName=firstContaining(names,{'std','dev'});
if ~isempty(stdName),stdSequence=value.(stdName);else
    minName=firstContaining(names,{'min'});maxName=firstContaining(names,{'max'});
    if ~isempty(minName)&&~isempty(maxName)
        stdSequence=(value.(maxName)-value.(minName))/2;
    end
end
end

function handles=researchTugline(ax,simulation,experimental)
count=simulation.Parameters.stride_count;force=simulation.Observables.tugline_force(:);
time=linspace(0,count,numel(force)).';cla(ax);hold(ax,'on');handles=gobjects(0);
handles(end+1)=plot(ax,time,force,'-','LineWidth',2, ...
    'Color',[0 .4470 .7410],'DisplayName','Sim');
maximum=max(force);
if ~isempty(experimental)
    if isstruct(experimental)
        names=fieldnames(experimental);meanName=firstContaining(names,{'mean'});
        stdName=firstContaining(names,{'std','dev'});meanValue=[];stdValue=[];
        if ~isempty(meanName),meanValue=resampleLinear(experimental.(meanName),time);end
        if ~isempty(stdName),stdValue=resampleLinear(experimental.(stdName),time);end
        if ~isempty(meanValue)
            handles(end+1)=plot(ax,time,meanValue,':','LineWidth',2.5, ...
                'Color',[.6350 .0780 .1840],'DisplayName','Exp Mean');
            maximum=max(maximum,max(meanValue));
        end
        if ~isempty(meanValue)&&~isempty(stdValue)
            handles(end+1)=fill(ax,[time;flipud(time)], ...
                [meanValue+stdValue;flipud(meanValue-stdValue)], ...
                [.6350 .0780 .1840],'FaceAlpha',.3,'EdgeColor','none', ...
                'DisplayName','Exp \pm1\sigma');
            maximum=max(maximum,max(meanValue+stdValue));
        end
    else
        if iscell(experimental),experimental=vertcat(experimental{:});end
        observed=normalizedResample(experimental,time);
        handles(end+1)=plot(ax,time,observed,':','LineWidth',2.5, ...
            'DisplayName','Exp');maximum=max(maximum,max(observed));
    end
end
xlim(ax,[0 count]);if isfinite(maximum)&&maximum>0,ylim(ax,[0 1.2*maximum]);end
xlabel(ax,'Stride Time  [%]','Interpreter','none');
ylabel(ax,'Leash Force  $[mg]$', ...
    'Interpreter','latex');title(ax,'Loading Force Along the Tugline');
ticks=0:.25:count;xticks(ax,ticks);
xticklabels(ax,arrayfun(@(value)sprintf('%.2f',value),ticks,'UniformOutput',false));
if count>1,pbaspect(ax,[2*count 1 1]);end
legend(ax,'show','Location','best');hold(ax,'off');
setQualification(ax,struct('timePolicy','Uniform normalized stride time', ...
    'structuredMinMaxIgnored',true,'multiStrideAspectAppliedByCallerInSource',true));
end

function handles=researchSensitivity(axesHandles,sensitivity)
if isempty(fieldnames(sensitivity)),handles=gobjects(0);return,end
axesHandles=axesHandles(:);
if isempty(axesHandles)||numel(axesHandles)>2
    error('lmz:slip_quad_load:ResearchSensitivityAxes', ...
        'Research sensitivity requires one curve axes and optional bar axes.');
end
C=sensitivity.C;percent=sensitivity.percs(:).';names=cellstr(sensitivity.names);
zero=C(:,percent==0);if isempty(zero),zero=C(:,floor(size(C,2)/2)+1);end
deltas=100*(max(C,[],2)-min(C,[],2))./max(zero,eps);
[sortedDeltas,order]=sort(deltas,'descend');colors=[8 163 119;214 99 8;8 118 179;239 229 72]/255;
ax=axesHandles(1);cla(ax);hold(ax,'on');curves=gobjects(size(C,1),1);
for parameter=1:size(C,1)
    color=colors(mod(parameter-1,4)+1,:);
    curves(parameter)=plot(ax,percent,100*(C(parameter,:)-zero(parameter))/ ...
        max(zero(parameter),eps),'-o','Color',color, ...
        'DisplayName',names{parameter},'LineWidth',1.5);
end
xlabel(ax,'$\mathrm{Perturbation}\ [\%]$','Interpreter','latex');
ylabel(ax,'Relative Objective Change [\%]','Interpreter','latex');
title(ax,'Objective vs %-Perturbation','Interpreter','none', ...
    'FontWeight','bold','FontName','Arial');
legend(ax,'Location','best','Interpreter','latex');grid(ax,'on');
set(ax,'FontSize',12);axis(ax,'tight');xlim(ax,[min(percent) max(percent)]);hold(ax,'off');
handles=curves;
if numel(axesHandles)==2
    ax=axesHandles(2);cla(ax);hold(ax,'on');grid(ax,'on');
    barHandle=bar(ax,sortedDeltas,'FaceColor','flat','EdgeColor','none','BarWidth',.6);
    barHandle.CData=colors(mod(order-1,4)+1,:);ax.XTick=1:numel(order);
    ax.XTickLabel=names(order);ax.XTickLabelRotation=0;
    ax.TickLabelInterpreter='latex';set(ax,'FontSize',12);
    xlabel(ax,'$\mathrm{Paramters}$','Interpreter','latex');
    ylabel(ax,'$\Delta\,\mathrm{Objective}\ [\%]$','Interpreter','latex');
    title(ax,'Sorted Percentage Objective Variation', ...
        'FontWeight','bold','FontName','Arial');
    ax.GridLineStyle='--';ax.GridAlpha=.25;maximum=max(sortedDeltas);
    if maximum>0,ylim(ax,[0 maximum*1.15]);end
    textHandles=gobjects(numel(order),1);
    for parameter=1:numel(order)
        textHandles(parameter)=text(ax,parameter,sortedDeltas(parameter)+maximum*.02, ...
            sprintf('%.2f\\%%',sortedDeltas(parameter)), ...
            'HorizontalAlignment','center','Interpreter','latex','FontSize',10);
    end
    handles=[handles(:);barHandle;textHandles(:)];hold(ax,'off');
else
    setQualification(ax,struct('sortedBarOmitted',true, ...
        'reason','Only one axes was supplied; source uses a second axes.'));
end
end

function handles=researchR2(ax,r2)
labels={'$R^2$. Footfall Timing','$R^2$. Loading Force', ...
    '$R^2$. Stride Duration','$R^2$. Weighted'};
values=[r2.footfalltiming,r2.loadingforce,r2.strideduration,r2.weighted];
cla(ax);axis(ax,[0 1 0 1]);axis(ax,'off');handles=gobjects(8,1);
for index=1:4
    y=1-index*.2;handles(2*index-1)=text(ax,.05,y,labels{index}, ...
        'Interpreter','latex','VerticalAlignment','middle');
    handles(2*index)=text(ax,.72,y,sprintf('%.6f',values(index)), ...
        'HorizontalAlignment','right','VerticalAlignment','middle');
end
title(ax,'R-squared Readouts');
setQualification(ax,struct('sourceLayoutsConsolidated',true, ...
    'sourceSection2Fields','footfall loading stride', ...
    'sourceSection3Fields','weighted only'));
end

function name=firstContaining(names,patterns)
name='';lowerNames=lower(names);
for pattern=1:numel(patterns)
    match=find(contains(lowerNames,patterns{pattern}),1);
    if ~isempty(match),name=names{match};return,end
end
end

function value=resampleLinear(value,time)
value=value(:);
if numel(value)~=numel(time)
    sourceTime=linspace(0,time(end),numel(value));
    value=interp1(sourceTime,value,time,'linear','extrap');
end
value=value(:);
end

function value=normalizedResample(value,time)
value=value(:);source=linspace(0,1,numel(value));target=linspace(0,1,numel(time));
if numel(value)<numel(time),method='spline';else,method='makima';end
value=interp1(source,value,target,method).';
end

function setQualification(ax,value)
setappdata(ax,'lmzResearchGraphicsQualifications',value);
end
