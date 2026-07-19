function startup
%STARTUP Add only the two Legged Model Zoo code roots.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'models'));
end
