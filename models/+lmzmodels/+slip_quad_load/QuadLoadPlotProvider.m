classdef QuadLoadPlotProvider
    %QUADLOADPLOTPROVIDER Scientific multi-stride analysis views.
    methods (Static)
        function handles=plotBodyAndLegs(ax,simulation)
            names={'quad_dx','quad_y','quad_dy','quad_phi','quad_dphi', ...
                'alphaBL','dalphaBL','alphaFL','dalphaFL','alphaBR','dalphaBR','alphaFR','dalphaFR'};
            handles=plotNamed(ax,simulation,names,'Quadruped body and leg states');
        end
        function handles=plotLoad(ax,simulation)
            handles=plotNamed(ax,simulation,{'load_x','load_dx','load_y','load_dy'},'Load states');
        end
        function handles=plotGRF(ax,simulation)
            labels={'BL','FL','BR','FR'};components={simulation.GroundReactionForces(:,1:4), ...
                simulation.GroundReactionForces(:,5:8),simulation.GroundReactionForces(:,9:12)};
            styles={'-','--',':'};componentLabels={'mag','x','y'};handles=gobjects(1,12);cla(ax);hold(ax,'on');slot=0;
            for component=1:3
                for leg=1:4,slot=slot+1;handles(slot)=plot(ax,simulation.Time,components{component}(:,leg), ...
                        'LineStyle',styles{component},'LineWidth',1.2, ...
                        'DisplayName',sprintf('%s %s',labels{leg},componentLabels{component}));end
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');ylabel(ax,'GRF');title(ax,'Ground reaction forces');legend(ax,'show','Location','best');
        end
        function handles=plotTugline(ax,simulation,experimental)
            if nargin<3,experimental=[];end
            cla(ax);hold(ax,'on');handles=gobjects(0);handles(end+1)=plot(ax,simulation.Observables.normalized_stride_time, ...
                simulation.Observables.tugline_force,'LineWidth',1.8,'DisplayName','Simulated');
            if ~isempty(experimental)
                if iscell(experimental),experimental=vertcat(experimental{:});end
                time=linspace(0,simulation.Observables.stride_count,numel(experimental));
                handles(end+1)=plot(ax,time,experimental(:),'--','LineWidth',1.4,'DisplayName','Observed');
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Stride time');ylabel(ax,'Tugline force');title(ax,'Tugline force');legend(ax,'show','Location','best');
        end
        function handles=plotFootfall(ax,simulation,experimental)
            if nargin<3,experimental=[];end
            phases=simulation.Parameters.per_stride_parameters(:,1:8)./simulation.Parameters.per_stride_parameters(:,9);
            phases=phases+((0:size(phases,1)-1).');order=[1 2 3 4 7 8 5 6];phases=phases(:,order);
            cla(ax);hold(ax,'on');handles=gobjects(0);colors=lines(4);
            for stride=1:size(phases,1)
                for leg=1:4
                    x=phases(stride,2*leg-1:2*leg);handles(end+1)=plot(ax,x,[leg leg],'-','LineWidth',7,'Color',colors(leg,:)); %#ok<AGROW>
                end
            end
            if ~isempty(experimental)
                for stride=1:size(experimental,1),for leg=1:4
                        plot(ax,experimental(stride,2*leg-1:2*leg),[leg+.18 leg+.18],':','LineWidth',2,'Color',colors(leg,:));
                    end,end
            end
            hold(ax,'off');grid(ax,'on');yticks(ax,1:4);yticklabels(ax,{'BL','FL','FR','BR'});xlabel(ax,'Stride time');title(ax,'Footfall sequence');
        end
        function handles=plotSensitivity(ax,sensitivity)
            cla(ax);handles=gobjects(0);if isempty(fieldnames(sensitivity)),title(ax,'No sensitivity data');return,end
            if isfield(sensitivity,'percs')&&isfield(sensitivity,'C')
                handles=plot(ax,sensitivity.percs,sensitivity.C.','LineWidth',1.2);grid(ax,'on');xlabel(ax,'Perturbation (%)');ylabel(ax,'Objective');title(ax,'Sensitivity');
                if isfield(sensitivity,'names'),legend(ax,cellstr(sensitivity.names),'Location','best');end
            end
        end
        function handles=plotR2(ax,r2)
            labels={'Stride duration','Footfall','Tugline','Weighted'};
            values=[r2.strideduration,r2.footfalltiming,r2.loadingforce,r2.weighted];
            cla(ax);handles=bar(ax,values);xticks(ax,1:4);xticklabels(ax,labels);ylim(ax,[min(0,min(values)-.1),1]);grid(ax,'on');ylabel(ax,'R^2');title(ax,'Fit quality');
        end
    end
end
function handles=plotNamed(ax,simulation,names,plotTitle)
cla(ax);hold(ax,'on');handles=gobjects(1,numel(names));
for index=1:numel(names),handles(index)=plot(ax,simulation.Time,simulation.state(names{index}),'LineWidth',1.2,'DisplayName',names{index});end
hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');title(ax,plotTitle);legend(ax,'show','Location','best');
end
