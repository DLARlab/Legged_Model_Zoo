classdef StrideTransitionMap
    %STRIDETRANSITIONMAP Default identity map between stride coordinates.
    methods
        function value=map(~,terminalState,varargin)
            if ~isnumeric(terminalState)||~isreal(terminalState)|| ...
                    any(~isfinite(terminalState(:)))
                error('lmz:MultiStride:TransitionState', ...
                    'Terminal state must be finite real numeric data.');
            end
            value=terminalState(:);
        end
    end
end
