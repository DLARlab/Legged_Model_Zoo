classdef QuadLoadStrideTransitionMap < lmz.multistride.StrideTransitionMap
    %QUADLOADSTRIDETRANSITIONMAP Exact source local-state stride transfer.
    methods
        function value=map(~,terminalState,varargin)
            if ~isnumeric(terminalState)||~isreal(terminalState)|| ...
                    numel(terminalState)~=18||any(~isfinite(terminalState(:)))
                error('lmz:QuadLoad:TransitionState', ...
                    'Quad-load terminal state must contain 18 finite values.');
            end
            physical=struct();
            if ~isempty(varargin),physical=extractPhysical(varargin{1});end
            height=terminalState(17);
            if isstruct(physical)&&isfield(physical,'LoadVector')
                load=physical.LoadVector(:);
                if numel(load)~=6||any(~isfinite(load))
                    error('lmz:QuadLoad:TransitionParameters', ...
                        'Load parameter vector must contain six finite values.');
                end
                height=load(1);
            end
            terminalState=terminalState(:);
            value=[0;terminalState(2:14); ...
                terminalState(15)-terminalState(1);terminalState(16);height;0];
        end

        function value=mapWithDiagnostics(obj,terminalState,varargin)
            local=obj.map(terminalState,varargin{:});terminalState=terminalState(:);
            value=struct('LocalState',local, ...
                'WorldTranslation',terminalState(1), ...
                'LoadRelativePosition',terminalState(15)-terminalState(1), ...
                'SourceQuadrupedState',terminalState(2:14), ...
                'SourceLoadState',[terminalState(15)-terminalState(1);terminalState(16)]);
        end

        function states=toWorld(~,localStates,translation)
            if ~isnumeric(localStates)||size(localStates,2)~=18|| ...
                    any(~isfinite(localStates(:)))||~isnumeric(translation)|| ...
                    ~isscalar(translation)||~isfinite(translation)
                error('lmz:QuadLoad:WorldState', ...
                    'Local states or translation are invalid.');
            end
            states=localStates;states(:,1)=states(:,1)+translation;
            states(:,15)=states(:,15)+translation;
        end

        function controls=carryControls(~,previousControls,postOverride)
            previous=validateControls(previousControls);
            post=previous.PostSwingStiffness;
            if nargin>=3&&~isempty(postOverride),post=postOverride(:);end
            if numel(post)~=4||any(~isfinite(post))
                error('lmz:QuadLoad:TransitionControls', ...
                    'Post-swing override must contain four finite values.');
            end
            controls=struct('PreSwingStiffness', ...
                previous.PostSwingStiffness,'PostSwingStiffness',post);
        end
    end
end

function value=extractPhysical(source)
if isa(source,'lmz.multistride.StrideSpec'),value=source.PhysicalParameters; ...
else,value=source;end
end
function value=validateControls(source)
if ~isstruct(source)||~all(isfield(source, ...
        {'PreSwingStiffness','PostSwingStiffness'}))
    error('lmz:QuadLoad:TransitionControls','Previous stride controls are incomplete.');
end
value=source;value.PreSwingStiffness=value.PreSwingStiffness(:);
value.PostSwingStiffness=value.PostSwingStiffness(:);
if numel(value.PreSwingStiffness)~=4||numel(value.PostSwingStiffness)~=4|| ...
        any(~isfinite([value.PreSwingStiffness;value.PostSwingStiffness]))
    error('lmz:QuadLoad:TransitionControls','Previous stride controls are invalid.');
end
end
