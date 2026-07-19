classdef BipedPlotProvider
    %BIPEDPLOTPROVIDER State, force, and footfall plots.
    methods (Static)
        function handles=plotBody(ax,simulation)
            handles=lmzmodels.slip_biped.BipedPlotProvider.plotNamed(ax,simulation, ...
                {'x','dx','y','dy'},'Body states');
        end
        function handles=plotLegs(ax,simulation)
            handles=lmzmodels.slip_biped.BipedPlotProvider.plotNamed(ax,simulation, ...
                {'alphaL','dalphaL','alphaR','dalphaR'},'Leg states');
        end
        function handles=plotGRF(ax,simulation)
            forces=simulation.GroundReactionForces;cla(ax);hold(ax,'on');
            labels={'Left |F|','Right |F|','Left F_x','Right F_x','Left F_y','Right F_y'};
            handles=gobjects(1,size(forces,2));
            for index=1:size(forces,2)
                handles(index)=plot(ax,simulation.Time,forces(:,index),'LineWidth',1.3, ...
                    'DisplayName',labels{index});
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');ylabel(ax,'GRF');
            title(ax,'Ground reaction forces');legend(ax,'show','Location','best');
        end
        function handles=plotFootfall(ax,simulation)
            fields={'left','right'};labels={'Left','Right'};phase=simulation.Time/simulation.Time(end);
            cla(ax);hold(ax,'on');handles=gobjects(1,2);
            for index=1:2
                handles(index)=stairs(ax,phase,index+0.35*double(simulation.Modes.(fields{index})), ...
                    'LineWidth',2,'DisplayName',labels{index});
            end
            for index=1:numel(simulation.EventRecords)
                xline(ax,simulation.EventRecords(index).Time/simulation.Time(end),':', ...
                    'HandleVisibility','off');
            end
            hold(ax,'off');grid(ax,'on');xlim(ax,[0 1]);ylim(ax,[0.7 2.7]);
            yticks(ax,1:2);yticklabels(ax,labels);xlabel(ax,'Normalized stride');
            title(ax,'Footfall phases');
        end
        function figures=createFigures(simulation,visible)
            if nargin<2,visible='on';end
            figures=gobjects(1,3);
            figures(1)=figure('Visible',visible,'Name','Biped states');
            layout=tiledlayout(figures(1),2,1);
            lmzmodels.slip_biped.BipedPlotProvider.plotBody(nexttile(layout),simulation);
            lmzmodels.slip_biped.BipedPlotProvider.plotLegs(nexttile(layout),simulation);
            figures(2)=figure('Visible',visible,'Name','Biped GRF');
            lmzmodels.slip_biped.BipedPlotProvider.plotGRF(axes(figures(2)),simulation);
            figures(3)=figure('Visible',visible,'Name','Biped footfall');
            lmzmodels.slip_biped.BipedPlotProvider.plotFootfall(axes(figures(3)),simulation);
        end
    end
    methods (Static, Access=private)
        function handles=plotNamed(ax,simulation,names,plotTitle)
            cla(ax);hold(ax,'on');handles=gobjects(1,numel(names));
            for index=1:numel(names)
                handles(index)=plot(ax,simulation.Time,simulation.state(names{index}), ...
                    'LineWidth',1.3,'DisplayName',names{index});
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');title(ax,plotTitle);
            legend(ax,'show','Location','best');
        end
    end
end
