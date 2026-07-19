function startup
%STARTUP Add only the Legged Model Zoo repository root to the MATLAB path.
root=fileparts(mfilename('fullpath'));if ~contains([path pathsep],[root pathsep]),addpath(root);end
end
