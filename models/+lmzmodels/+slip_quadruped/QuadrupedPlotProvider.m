classdef QuadrupedPlotProvider
    %QUADRUPEDPLOTPROVIDER Named trajectory, GRF, and phase plots.
    methods (Static)
        function handles=plotTorso(ax,simulation,profile)
            if nargin<3,profile=[];end
            names={'dx','y','dy','phi','dphi'};labels={'dx','y','dy','phi','dphi'};
            handles=gobjects(1,numel(names));cla(ax);hold(ax,'on');
            if isResearch(profile)
                labels={'$\dot{x}$','$y$','$\dot{y}$','$\phi$','$\dot{\phi}$'};
            end
            for index=1:numel(names)
                handles(index)=plot(ax,simulation.Time, ...
                    simulation.state(names{index}),'LineWidth',1.4, ...
                    'DisplayName',labels{index});
            end
            hold(ax,'off');grid(ax,'on');
            if isResearch(profile)
                xlabel(ax,'Stride Time  $[\sqrt{l_0/g}]$', ...
                    'Interpreter','latex','FontSize',12);
                title(ax,'Trajectories of the Torso','FontSize',12);
                legend(ax,'show','Location','best','Interpreter','latex');
                xlim(ax,[0 simulation.Time(end)]);
                ylim(ax,paddedSourceLimits(simulation.States(:,2:6),.10));
            else
                xlabel(ax,'Time');title(ax,'Torso states');
                legend(ax,'show','Location','best');
            end
        end
        function handles=plotBackLegs(ax,simulation,profile)
            if nargin<3,profile=[];end
            if isResearch(profile)
                handles=researchLegPlot(ax,simulation, ...
                    {'alphaBL','dalphaBL','alphaBR','dalphaBR'}, ...
                    {'$\alpha_{BL}$','$\dot{\alpha}_{BL}$', ...
                    '$\alpha_{BR}$','$\dot{\alpha}_{BR}$'}, ...
                    'Trajectories of the Back Legs');
                return
            end
            handles=lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotNamed(ax,simulation, ...
                {'alphaBL','dalphaBL','alphaBR','dalphaBR'},'Back-leg states');
        end
        function handles=plotFrontLegs(ax,simulation,profile)
            if nargin<3,profile=[];end
            if isResearch(profile)
                handles=researchLegPlot(ax,simulation, ...
                    {'alphaFL','dalphaFL','alphaFR','dalphaFR'}, ...
                    {'$\alpha_{FL}$','$\dot{\alpha}_{FL}$', ...
                    '$\alpha_{FR}$','$\dot{\alpha}_{FR}$'}, ...
                    'Trajectories of the Front Legs');
                return
            end
            handles=lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotNamed(ax,simulation, ...
                {'alphaFL','dalphaFL','alphaFR','dalphaFR'},'Front-leg states');
        end
        function handles=plotGRF(ax,simulation,profile)
            if nargin<3,profile=[];end
            if isResearch(profile)
                handles=researchGRF(ax,simulation);return
            end
            legs={'BL','FL','BR','FR'};cla(ax);hold(ax,'on');forces=simulation.GroundReactionForces;
            if isempty(forces)||size(forces,2)<12
                forces=[simulation.Observables.vertical_grf zeros(numel(simulation.Time),8)];
            end
            colors=lines(4);styles={'-','--',':'};components={'|F|','F_x','F_y'};handles=gobjects(1,12);handleIndex=0;
            for component=1:3
                for leg=1:4
                    handleIndex=handleIndex+1;column=(component-1)*4+leg;
                    handles(handleIndex)=plot(ax,simulation.Time,forces(:,column),'Color',colors(leg,:), ...
                        'LineStyle',styles{component},'LineWidth',1.25,'DisplayName',sprintf('%s %s',legs{leg},components{component}));
                end
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');ylabel(ax,'GRF');title(ax,'Ground reaction force magnitude and components');legend(ax,'show','Location','best','NumColumns',3);
        end
        function handles=plotOscillator(ax,simulation,profile)
            if nargin<3,profile=[];end
            if isResearch(profile)
                handles=researchOscillator(ax,simulation);return
            end
            names={'BL','FL','BR','FR'};fields={'back_left','front_left','back_right','front_right'};
            phases=simulation.Time/simulation.Time(end);cla(ax);hold(ax,'on');handles=gobjects(1,4);
            for index=1:4
                contact=double(simulation.Modes.(fields{index}));
                handles(index)=stairs(ax,phases,index+0.32*contact,'LineWidth',2,'DisplayName',names{index});
            end
            for index=1:numel(simulation.EventRecords)
                xline(ax,simulation.EventRecords(index).Time/simulation.Time(end),':','HandleVisibility','off');
            end
            hold(ax,'off');grid(ax,'on');xlim(ax,[0 1]);ylim(ax,[0.7 4.7]);yticks(ax,1:4);yticklabels(ax,names);xlabel(ax,'Normalized stride');title(ax,'Footfall oscillator / phase plot');
        end
        function figures=createFigures(simulation,visible,profile)
            if nargin<2,visible='on';end
            if nargin<3,profile=[];end
            titles={'Quadruped torso and legs','Quadruped GRF','Quadruped oscillator'};
            figures=gobjects(1,3);for index=1:3,figures(index)=figure('Visible',visible,'Name',titles{index});end
            layout=tiledlayout(figures(1),3,1);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotTorso(nexttile(layout),simulation,profile);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotBackLegs(nexttile(layout),simulation,profile);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotFrontLegs(nexttile(layout),simulation,profile);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotGRF(axes(figures(2)),simulation,profile);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider. ...
                plotOscillator(axes(figures(3)),simulation,profile);
        end
    end
    methods (Static, Access=private)
        function handles=plotNamed(ax,simulation,names,plotTitle)
            cla(ax);hold(ax,'on');handles=gobjects(1,numel(names));
            for index=1:numel(names),handles(index)=plot(ax,simulation.Time,simulation.state(names{index}),'LineWidth',1.3,'DisplayName',names{index});end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');title(ax,plotTitle);legend(ax,'show','Location','best');
        end
    end
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
result=any(strcmp(value,{'research_legacy','high_contrast'}));
end

function handles=researchLegPlot(ax,simulation,names,labels,plotTitle)
cla(ax);hold(ax,'on');handles=gobjects(1,numel(names));
for index=1:numel(names)
    handles(index)=plot(ax,simulation.Time,simulation.state(names{index}), ...
        '-','LineWidth',1.3,'DisplayName',labels{index});
end
allLegNames={'alphaBL','dalphaBL','alphaFL','dalphaFL', ...
    'alphaBR','dalphaBR','alphaFR','dalphaFR'};
allValues=zeros(numel(simulation.Time),numel(allLegNames));
for index=1:numel(allLegNames)
    allValues(:,index)=simulation.state(allLegNames{index});
end
hold(ax,'off');grid(ax,'on');
xlabel(ax,'Stride Time  $[\sqrt{l_0/g}]$','Interpreter','latex','FontSize',12);
title(ax,plotTitle,'FontSize',12);legend(ax,'show','Interpreter','latex');
xlim(ax,[0 simulation.Time(end)]);ylim(ax,paddedSourceLimits(allValues,.05));
end

function handles=researchGRF(ax,simulation)
forces=simulation.GroundReactionForces;
if isempty(forces)
    vertical=zeros(numel(simulation.Time),4);
elseif size(forces,2)>=12
    vertical=forces(:,9:12);
elseif size(forces,2)>=4
    vertical=forces(:,1:4);
else
    error('lmz:slip_quadruped:ResearchGRF', ...
        'Research GRF plot requires four vertical channels.');
end
order=[1 2 4 3];labels={'LH','LF','RF','RH'};
colors=[217 83 25;217 83 25;0 114 189;0 114 189]/256;
styles={'-',':',':','-'};widths=[2 2.5 2.5 2];
cla(ax);hold(ax,'on');handles=gobjects(1,4);
for index=1:4
    handles(index)=plot(ax,simulation.Time,vertical(:,order(index)), ...
        styles{index},'Color',colors(index,:),'LineWidth',widths(index), ...
        'DisplayName',labels{index});
end
hold(ax,'off');grid(ax,'on');box(ax,'on');
xlabel(ax,'Stride Time  $[\sqrt{l_0/g}]$','Interpreter','latex','FontSize',12);
ylabel(ax,'Vertical GRF  $[m_0g]$','Interpreter','latex','FontSize',12);
title(ax,'Ground Reaction Forces');legend(ax,'show','Location','northeast');
xlim(ax,[0 simulation.Time(end)]);ylim(ax,paddedSourceLimits(vertical,.10));
setappdata(ax,'lmzResearchGraphicsQualifications',struct( ...
    'sourceUpdateSwapCorrected',true,'sourceConstructionOrder','LH LF RF RH'));
end

function handles=researchOscillator(ax,simulation)
labels={'FR','FL','BL','BR'};centers=[1 1;-1 1;-1 -1;1 -1];
events={'FR_TD','FR_LO';'FL_TD','FL_LO';'BL_TD','BL_LO';'BR_TD','BR_LO'};
radius=.62;cla(ax);hold(ax,'on');axis(ax,'equal');box(ax,'on');
xlim(ax,[-2 2]);ylim(ax,[-2 2]);set(ax,'XTick',[],'YTick',[]);
title(ax,'Oscillator Cycles');handles=gobjects(1,22);slot=0;
slot=slot+1;handles(slot)=plot(ax,[0 0],[-2 2],'k-','LineWidth',.75);
slot=slot+1;handles(slot)=plot(ax,[-2 2],[0 0],'k-','LineWidth',.75);
theta=linspace(0,2*pi,300);period=max(simulation.Time(end),eps);
for leg=1:4
    center=centers(leg,:);times=eventPair(simulation.EventRecords,events(leg,:));
    angles=2*pi*times/period;arcEnd=angles(2);
    if arcEnd<angles(1),arcEnd=arcEnd+2*pi;end
    arc=linspace(angles(1),arcEnd,100);
    slot=slot+1;handles(slot)=patch(ax, ...
        [center(1) center(1)+radius*cos(arc) center(1)], ...
        [center(2) center(2)+radius*sin(arc) center(2)],[.8 .8 .8], ...
        'EdgeColor','none');
    slot=slot+1;handles(slot)=plot(ax,center(1)+radius*cos(theta), ...
        center(2)+radius*sin(theta),'k-','LineWidth',1.5);
    slot=slot+1;handles(slot)=plot(ax, ...
        [center(1) center(1)+radius*cos(angles(1))], ...
        [center(2) center(2)+radius*sin(angles(1))],'r-','LineWidth',1.5);
    slot=slot+1;handles(slot)=plot(ax, ...
        [center(1) center(1)+radius*cos(angles(2))], ...
        [center(2) center(2)+radius*sin(angles(2))],'b-','LineWidth',1.5);
    slot=slot+1;handles(slot)=text(ax,center(1), ...
        center(2)+1.35*radius,labels{leg}, ...
        'HorizontalAlignment','center','FontWeight','bold');
end
hold(ax,'off');
end

function value=eventPair(records,names)
value=[0 0];
for index=1:2
    match=find(strcmp({records.Name},names{index}),1);
    if ~isempty(match),value(index)=records(match).Time;end
end
end

function limits=paddedSourceLimits(values,fraction)
minimum=min(values(:));maximum=max(values(:));
if ~isfinite(minimum)||~isfinite(maximum)
    limits=[-1 1];return
end
if minimum==maximum
    scale=max(1,abs(minimum));limits=minimum+scale*[-fraction fraction];return
end
if fraction==.10
    limits=[minimum*(1-fraction*sign(minimum)), ...
        maximum*(1+fraction*sign(maximum))];
    if limits(2)<=limits(1)
        padding=fraction*(maximum-minimum);limits=[minimum-padding maximum+padding];
    end
else
    padding=fraction*(maximum-minimum);limits=[minimum-padding maximum+padding];
end
end
