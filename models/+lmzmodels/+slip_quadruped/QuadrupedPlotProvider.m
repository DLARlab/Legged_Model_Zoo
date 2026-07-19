classdef QuadrupedPlotProvider
    %QUADRUPEDPLOTPROVIDER Named trajectory, GRF, and phase plots.
    methods (Static)
        function handles=plotTorso(ax,simulation)
            names={'dx','y','dy','phi','dphi'};labels={'dx','y','dy','phi','dphi'};
            handles=gobjects(1,numel(names));cla(ax);hold(ax,'on');
            for index=1:numel(names),handles(index)=plot(ax,simulation.Time,simulation.state(names{index}),'LineWidth',1.4,'DisplayName',labels{index});end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');title(ax,'Torso states');legend(ax,'show','Location','best');
        end
        function handles=plotBackLegs(ax,simulation)
            handles=lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotNamed(ax,simulation, ...
                {'alphaBL','dalphaBL','alphaBR','dalphaBR'},'Back-leg states');
        end
        function handles=plotFrontLegs(ax,simulation)
            handles=lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotNamed(ax,simulation, ...
                {'alphaFL','dalphaFL','alphaFR','dalphaFR'},'Front-leg states');
        end
        function handles=plotGRF(ax,simulation)
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
        function handles=plotOscillator(ax,simulation)
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
        function figures=createFigures(simulation,visible)
            if nargin<2,visible='on';end
            titles={'Quadruped torso and legs','Quadruped GRF','Quadruped oscillator'};
            figures=gobjects(1,3);for index=1:3,figures(index)=figure('Visible',visible,'Name',titles{index});end
            layout=tiledlayout(figures(1),3,1);lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotTorso(nexttile(layout),simulation);lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotBackLegs(nexttile(layout),simulation);lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotFrontLegs(nexttile(layout),simulation);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotGRF(axes(figures(2)),simulation);
            lmzmodels.slip_quadruped.QuadrupedPlotProvider.plotOscillator(axes(figures(3)),simulation);
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
