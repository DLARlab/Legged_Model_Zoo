function [violations,report]=check_matlab_compatibility(projectRoot)
%CHECK_MATLAB_COMPATIBILITY Static audit against the MATLAB R2019b target.
if nargin<1,projectRoot=lmz.util.ProjectPaths.root();end
roots={'src','models','tests','examples','tools'};
files={};
for index=1:numel(roots)
    folder=fullfile(projectRoot,roots{index});
    if exist(folder,'dir')==7,files=[files collectMFiles(folder)];end %#ok<AGROW>
end
topLevel={'startup.m','legged_model_zoo.m','run_tests.m'};
for index=1:numel(topLevel)
    path=fullfile(projectRoot,topLevel{index});
    if exist(path,'file')==2,files{end+1}=path;end %#ok<AGROW>
end

violations={};counts=struct('Files',numel(files),'UIComponents',0, ...
    'OptimizationOptions',0,'JSONCalls',0,'TableCalls',0, ...
    'DatetimeCalls',0,'StringCalls',0,'UnitTestCalls',0, ...
    'GuardedExportGraphicsCalls',0, ...
    'VideoWriterCalls',0,'RecursiveDirCalls',0);
postR2019b={'exportapp','copygraphics','orderedcolors','clim','turbo'};
for fileIndex=1:numel(files)
    path=files{fileIndex};raw=fileread(path);code=withoutComments(raw);
    relative=relativePath(projectRoot,path);
    counts.UIComponents=counts.UIComponents+countMatches(code, ...
        '\<(uifigure|uigridlayout|uiaxes|uispinner)\>');
    counts.OptimizationOptions=counts.OptimizationOptions+ ...
        countMatches(code,'\<optimoptions\s*\(');
    counts.JSONCalls=counts.JSONCalls+ ...
        countMatches(code,'\<json(en|de)code\s*\(');
    counts.TableCalls=counts.TableCalls+ ...
        countMatches(code,'\<(struct2table|table2struct|cell2table|readtable|writetable)\s*\(');
    counts.DatetimeCalls=counts.DatetimeCalls+ ...
        countMatches(code,'\<datetime\s*\(');
    counts.StringCalls=counts.StringCalls+ ...
        countMatches(code,'\<(string|strings|isstring)\s*\(');
    counts.UnitTestCalls=counts.UnitTestCalls+ ...
        countMatches(code,'\<(runtests|matlab\.unittest)\>');
    counts.RecursiveDirCalls=counts.RecursiveDirCalls+ ...
        countMatches(code,'\<dir\s*\([^\)]*["'']\*\*');
    for apiIndex=1:numel(postR2019b)
        api=postR2019b{apiIndex};
        if ~isempty(regexp(code,['\<' api '\s*\('],'once'))
            violations{end+1}=sprintf('%s: %s is newer than R2019b.',relative,api); %#ok<AGROW>
        end
    end
    exportCalls=countMatches(code,'\<exportgraphics\s*\(');
    if exportCalls>0
        guarded=~isempty(regexp(code, ...
            'exist\s*\(\s*[''" ]exportgraphics[''" ]\s*,\s*[''" ]file[''" ]\s*\)\s*==\s*2', ...
            'once'));
        if guarded
            counts.GuardedExportGraphicsCalls= ...
                counts.GuardedExportGraphicsCalls+exportCalls;
        else
            violations{end+1}=sprintf( ...
                '%s: exportgraphics is not protected by an R2019b fallback.',relative); %#ok<AGROW>
        end
    end
    videoCalls=countMatches(code,'\<VideoWriter\s*\(');
    counts.VideoWriterCalls=counts.VideoWriterCalls+videoCalls;
    if videoCalls>0&&~isempty(regexp(code,['VideoWriter\s*\([^\)]*' ...
            '[''" ]MPEG-4[''" ]'],'once'))&& ...
            isempty(regexp(code,'try[\s\S]*VideoWriter[\s\S]*catch','once'))
        violations{end+1}=sprintf( ...
            '%s: MPEG-4 profile construction needs a platform guard.',relative); %#ok<AGROW>
    end
end

release=version('-release');runtimeVerified=strcmpi(release,'2019b');
report=struct('TargetRelease','R2019b','RuntimeRelease',release, ...
    'RuntimeVerified',runtimeVerified,'StaticOnly',~runtimeVerified, ...
    'Checks',{{'language syntax','uifigure/uigridlayout', ...
    'optimoptions names','exportgraphics','VideoWriter profiles', ...
    'datetime/string usage','JSON functions','table APIs','recursive dir syntax', ...
    'matlab.unittest options'}},'Counts',counts, ...
    'ViolationCount',numel(violations));
end

function files=collectMFiles(folder)
entries=dir(folder);files={};
for index=1:numel(entries)
    name=entries(index).name;
    if entries(index).isdir
        if strcmp(name,'.')||strcmp(name,'..'),continue,end
        files=[files collectMFiles(fullfile(folder,name))]; %#ok<AGROW>
    elseif numel(name)>=2&&strcmpi(name(end-1:end),'.m')
        files{end+1}=fullfile(folder,name); %#ok<AGROW>
    end
end
end

function code=withoutComments(raw)
lines=regexp(raw,'\r\n|\n|\r','split');
for index=1:numel(lines)
    marker=find(lines{index}=='%',1);
    if ~isempty(marker),lines{index}=lines{index}(1:marker-1);end
end
code=strjoin(lines,sprintf('\n'));
end

function value=countMatches(code,expression)
value=numel(regexp(code,expression,'match'));
end

function value=relativePath(root,path)
prefix=[root filesep];value=path;
if strncmp(path,prefix,numel(prefix)),value=path(numel(prefix)+1:end);end
end
