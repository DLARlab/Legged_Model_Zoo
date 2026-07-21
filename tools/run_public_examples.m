function report = run_public_examples
%RUN_PUBLIC_EXAMPLES Execute every top-level public example in isolation.
root=lmz.util.ProjectPaths.root();folder=fullfile(root,'examples');
entries=dir(fullfile(folder,'*.m'));names=sort({entries.name});
durations=zeros(numel(names),1);failures={};
for index=1:numel(names)
    path=fullfile(folder,names{index});started=tic;
    try
        executeExample(path);
        durations(index)=toc(started);
        fprintf('LMZ_EXAMPLE_PASS name=%s elapsed=%.6f\n', ...
            names{index},durations(index));
    catch exception
        durations(index)=toc(started);
        failures{end+1}=sprintf('%s: %s',names{index},exception.message); %#ok<AGROW>
        fprintf('LMZ_EXAMPLE_FAIL name=%s elapsed=%.6f id=%s\n', ...
            names{index},durations(index),exception.identifier);
    end
end
report=struct('Files',{names},'Durations',durations,'Failures',{failures}, ...
    'SuccessMarker','LMZ_PUBLIC_EXAMPLES_OK');
if ~isempty(failures)
    error('lmz:Examples:Failure','%d public examples failed:\n%s', ...
        numel(failures),strjoin(failures,newline));
end
fprintf('%s files=%d\n',report.SuccessMarker,numel(names));
end

function executeExample(path)
exampleOutputDirectory019f=tempname;
[created,message]=mkdir(exampleOutputDirectory019f);
if ~created
    error('lmz:Examples:OutputDirectory', ...
        'Cannot create isolated example output directory: %s',message);
end
exampleOutputCleanup019f=onCleanup( ...
    @()removeExampleOutput(exampleOutputDirectory019f));
roadmapOutputDirectory=fullfile( ...
    exampleOutputDirectory019f,'roadmap'); %#ok<NASGU>
slipQuadLoadOutputDirectory=fullfile( ...
    exampleOutputDirectory019f,'load'); %#ok<NASGU>
desktopOutputDirectory=fullfile( ...
    exampleOutputDirectory019f,'desktop'); %#ok<NASGU>
round9OutputDirectory=fullfile( ...
    exampleOutputDirectory019f,'round9'); %#ok<NASGU>
exampleRunnerCleanup019f=onCleanup(@()closeAllFigures());
run(path);clear exampleRunnerCleanup019f
clear exampleOutputCleanup019f
end

function closeAllFigures
try
    close all force
catch
    close all
end
end

function removeExampleOutput(path)
if exist(path,'dir')~=7,return,end
[removed,message]=rmdir(path,'s');
if ~removed
    error('lmz:Examples:CleanupFailed', ...
        'Cannot remove isolated example output directory: %s',message);
end
end
