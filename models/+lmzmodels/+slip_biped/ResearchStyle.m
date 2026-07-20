classdef ResearchStyle
    %RESEARCHSTYLE Deterministic styling for source-derived biped graphics.
    methods (Static)
        function value=defaults()
            value=struct();
            value.body=struct('faceColor',[1 1 1],'edgeColor',[0 0 0], ...
                'lineWidth',5);
            value.cog=struct('faceColors',[1 1 1;0 0 0;1 1 1;0 0 0], ...
                'edgeColor',[0 0 0],'lineWidth',3);
            value.spring=struct('faceColor',[0 0 0], ...
                'edgeColor',[0 68 158]/256,'lineWidth',5);
            value.leftLeg=struct('faceColor',[202 202 202]/256, ...
                'edgeColor',[0 0 0],'lineWidth',3);
            value.rightLeg=struct('faceColor',[1 1 1], ...
                'edgeColor',[0 0 0],'lineWidth',3);
            value.ground=struct( ...
                'maskFaceColor',[1 1 1],'maskEdgeColor',[0 0 0], ...
                'maskLineWidth',0.5,'hatchFaceColor',[0 0 0], ...
                'hatchEdgeColor',[0 0 0],'hatchLineWidth',0.5);
            value.axes=struct('backgroundColor',[1 1 1], ...
                'xFollowHalfWidth',1.5,'yLimits',[-0.3 2]);
            value.qualifications=struct( ...
                'defaultColorPolicy',['Source patch defaults varied by MATLAB release; ', ...
                    'documented black outlines and ground are frozen explicitly.']);
        end

        function value=resolve(profile)
            value=lmzmodels.slip_biped.ResearchStyle.defaults();
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
