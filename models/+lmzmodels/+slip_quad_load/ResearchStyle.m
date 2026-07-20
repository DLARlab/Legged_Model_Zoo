classdef ResearchStyle
    %RESEARCHSTYLE Explicit deterministic load-specific legacy styling.
    methods (Static)
        function value=defaults()
            value=struct();
            value.load=struct('faceColor',[0 0 0],'faceAlpha',0.3, ...
                'edgeColor',[0 0 0],'lineWidth',2);
            value.rope=struct('faceColor',[0 0 0],'faceAlpha',0.3, ...
                'edgeColor',[0 0 0],'lineWidth',2);
            value.axes=struct('backgroundColor',[1 1 1], ...
                'xOffsets',[-3 1.5],'yLimits',[-0.1 2], ...
                'plotBoxAspect',[2 1 1], ...
                'title','SLIP Quad-Load Animation');
            value.qualifications=struct( ...
                'ropeRepresentation',['Source rope is a zero-area four-point patch ', ...
                    'with duplicated endpoints, not a two-point line.'], ...
                'detailedMode',['Source stores AnimationMode but the load animation ', ...
                    'does not draw its quadruped phase diagram.'], ...
                'recording','Renderer contains no playback or recording loop.');
        end

        function value=resolve(profile)
            value=lmzmodels.slip_quad_load.ResearchStyle.defaults();
            if nargin>=1&&~isempty(profile)&&isa(profile,'lmz.viz.VisualizationProfile')
                value=mergeRecursive(value,profile.Style);
            end
        end
    end
end

function value=mergeRecursive(first,second)
value=first;if isempty(second),return,end
names=fieldnames(second);
for index=1:numel(names)
    name=names{index};incoming=second.(name);
    if isfield(value,name)&&isstruct(value.(name))&&isstruct(incoming)
        value.(name)=mergeRecursive(value.(name),incoming);
    else
        value.(name)=incoming;
    end
end
end
