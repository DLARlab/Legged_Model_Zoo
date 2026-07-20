classdef BipedPlotProvider
    %BIPEDPLOTPROVIDER State, force, and footfall plots.
    methods (Static)
        function handles=plotBody(ax,simulation,profile)
            if nargin<3,profile=[];end
            handles=lmzmodels.slip_biped.BipedPlotProvider.plotNamed(ax,simulation, ...
                {'x','dx','y','dy'},'Body states',profile, ...
                {'$x$','$\dot{x}$','$y$','$\dot{y}$'});
        end
        function handles=plotLegs(ax,simulation,profile)
            if nargin<3,profile=[];end
            handles=lmzmodels.slip_biped.BipedPlotProvider.plotNamed(ax,simulation, ...
                {'alphaL','dalphaL','alphaR','dalphaR'},'Leg states',profile, ...
                {'$\alpha_L$','$\dot{\alpha}_L$', ...
                '$\alpha_R$','$\dot{\alpha}_R$'});
        end
        function handles=plotGRF(ax,simulation,profile)
            if nargin<3,profile=[];end
            forces=simulation.GroundReactionForces;cla(ax);hold(ax,'on');
            if isResearch(profile)
                if isempty(forces)
                    vertical=zeros(numel(simulation.Time),2);
                elseif size(forces,2)>=6
                    vertical=forces(:,5:6);
                elseif size(forces,2)>=2
                    vertical=forces(:,end-1:end);
                else
                    error('lmz:slip_biped:ResearchGRF', ...
                        'Research GRF plot requires left/right vertical channels.');
                end
                handles=gobjects(1,2);labels={'Left vertical','Right vertical'};
                for index=1:2
                    handles(index)=plot(ax,simulation.Time,vertical(:,index), ...
                        'LineWidth',1.5,'DisplayName',labels{index});
                end
                hold(ax,'off');grid(ax,'on');box(ax,'on');
                xlabel(ax,'Time $[\sqrt{l_0/g}]$','Interpreter','latex');
                ylabel(ax,'Vertical GRF $[m_0g]$','Interpreter','latex');
                title(ax,'Left/right vertical ground reaction forces');
                legend(ax,'show','Location','best');
                setappdata(ax,'lmzResearchGraphicsQualifications',struct( ...
                    'sourceChannels','left/right vertical only'));
                return
            end
            labels={'Left |F|','Right |F|','Left F_x','Right F_x','Left F_y','Right F_y'};
            handles=gobjects(1,size(forces,2));
            for index=1:size(forces,2)
                handles(index)=plot(ax,simulation.Time,forces(:,index),'LineWidth',1.3, ...
                    'DisplayName',labels{index});
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');ylabel(ax,'GRF');
            title(ax,'Ground reaction forces');legend(ax,'show','Location','best');
        end
        function handles=plotFootfall(ax,simulation,profile)
            if nargin<3,profile=[];end
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
            if isResearch(profile)
                setappdata(ax,'lmzResearchGraphicsQualifications',struct( ...
                    'sourceEquivalent',false,'kind','LMZ analytical enrichment'));
            end
        end
        function handles=plotEnergyAndGait(ax,simulation,profile)
            %PLOTENERGYANDGAIT Display LMZ analytical enrichments explicitly.
            if nargin<3,profile=[];end
            observables=simulation.Observables;energy=[];gait='Unavailable';
            if isstruct(observables)&&isfield(observables,'total_energy')&& ...
                    isnumeric(observables.total_energy)&& ...
                    all(isfinite(observables.total_energy(:)))
                candidate=observables.total_energy(:);
                if isscalar(candidate)
                    energy=repmat(candidate,numel(simulation.Time),1);
                elseif numel(candidate)==numel(simulation.Time)
                    energy=candidate;
                end
            end
            if isstruct(observables)&&isfield(observables,'gait_name')
                value=observables.gait_name;
                if isstring(value)&&isscalar(value),value=char(value);end
                if ischar(value)&&~isempty(strtrim(value)),gait=strtrim(value);end
            end
            if isstruct(observables)&&isfield(observables,'gait_abbreviation')
                abbreviation=observables.gait_abbreviation;
                if isstring(abbreviation)&&isscalar(abbreviation)
                    abbreviation=char(abbreviation);
                end
                if ischar(abbreviation)&&~isempty(strtrim(abbreviation))
                    gait=sprintf('%s (%s)',gait,strtrim(abbreviation));
                end
            end
            cla(ax);hold(ax,'on');
            if isempty(energy)
                energy=nan(size(simulation.Time));
            end
            handles.Energy=plot(ax,simulation.Time,energy,'LineWidth',1.5, ...
                'DisplayName','Total energy');
            hold(ax,'off');grid(ax,'on');box(ax,'on');
            xlabel(ax,'Time $[\sqrt{l_0/g}]$','Interpreter','latex');
            ylabel(ax,'Total energy $[m_0 g l_0]$','Interpreter','latex');
            title(ax,'Energy and gait classification');
            handles.GaitLabel=text(ax,.02,.92,['Gait: ' gait], ...
                'Units','normalized','Interpreter','none', ...
                'FontWeight','bold','VerticalAlignment','top', ...
                'Tag','lmz.biped.gait_label');
            if isResearch(profile)
                setappdata(ax,'lmzResearchGraphicsQualifications',struct( ...
                    'sourceEquivalent',false, ...
                    'kind','LMZ energy/gait analytical enrichment'));
            end
        end
        function figures=createFigures(simulation,visible,profile)
            if nargin<2,visible='on';end
            if nargin<3,profile=[];end
            figures=gobjects(1,3);
            figures(1)=figure('Visible',visible,'Name','Biped states');
            layout=tiledlayout(figures(1),2,1);
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotBody(nexttile(layout),simulation,profile);
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotLegs(nexttile(layout),simulation,profile);
            figures(2)=figure('Visible',visible,'Name','Biped GRF');
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotGRF(axes(figures(2)),simulation,profile);
            figures(3)=figure('Visible',visible,'Name','Biped footfall');
            lmzmodels.slip_biped.BipedPlotProvider. ...
                plotFootfall(axes(figures(3)),simulation,profile);
        end
    end
    methods (Static, Access=private)
        function handles=plotNamed(ax,simulation,names,plotTitle,profile,labels)
            if nargin<5,profile=[];end
            if nargin<6,labels=names;end
            cla(ax);hold(ax,'on');handles=gobjects(1,numel(names));
            for index=1:numel(names)
                handles(index)=plot(ax,simulation.Time,simulation.state(names{index}), ...
                    'LineWidth',1.3,'DisplayName',labels{index});
            end
            hold(ax,'off');grid(ax,'on');xlabel(ax,'Time');title(ax,plotTitle);
            if isResearch(profile)
                xlabel(ax,'Time $[\sqrt{l_0/g}]$','Interpreter','latex');
                legend(ax,'show','Location','best','Interpreter','latex');
            else
                legend(ax,'show','Location','best');
            end
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
