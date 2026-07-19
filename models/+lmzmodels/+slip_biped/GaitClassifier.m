classdef GaitClassifier
    %GAITCLASSIFIER Source-compatible walk/hop/skip/run classification.
    methods (Static)
        function value=classify(decision,varargin)
            if numel(decision)~=12 || any(~isfinite(decision(:)))
                error('lmz:slip_biped:GaitInput', ...
                    'Gait classification requires one finite 12-entry decision.');
            end
            x=decision(:); code=NaN;
            if x(9)<x(8) && x(11)<x(10)
                code=0;
            else
                threshold=1e-6;
                leftLeading=x(9)-x(11)>threshold && x(8)-x(10)>threshold;
                rightLeading=x(11)-x(9)>threshold && x(10)-x(8)>threshold;
                if ~leftLeading && ~rightLeading
                    code=1;
                elseif (leftLeading && x(8)<=x(11) && x(10)<=x(9)) || ...
                        (rightLeading && x(10)<=x(9) && x(8)<=x(11))
                    code=2;
                elseif (leftLeading && x(8)>x(11) && x(10)<=x(9)) || ...
                        (rightLeading && x(10)>x(9) && x(8)<=x(11))
                    code=3;
                end
            end
            if isnan(code)
                name='unclassified';abbreviation='?';color=[0.4 0.4 0.4];style=':';
            else
                names={'walking','hopping','skipping','running'};
                abbreviations={'W','HP','SK','R'};
                colors={[0.18 0.55 0.34],[0.55 0.32 0.75], ...
                    [0.9 0.55 0.1],[0.15 0.42 0.78]};
                styles={'-','--','-.','-'};
                name=names{code+1};abbreviation=abbreviations{code+1};
                color=colors{code+1};style=styles{code+1};
            end
            subtype='';
            if ~isempty(varargin), subtype=varargin{1}; end
            if strcmpi(subtype,'asymmetric running') || strcmpi(subtype,'AR1')
                name='asymmetric running';abbreviation='AR';
                color=[0.78 0.22 0.28];style='--';
            end
            value=struct('Code',code,'Name',name,'Abbreviation',abbreviation, ...
                'Subtype',subtype,'Color',color,'LineStyle',style, ...
                'Method','Gaitidentify compatibility', ...
                'SourceCommit','4595146c5881a5313bc8fe92de85099193ef9be9');
        end
    end
end
