function state=release_source_state(root)
%RELEASE_SOURCE_STATE Capture commit and dirty-worktree state reproducibly.
state=struct('repositoryCommit',release_commit(root), ...
    'worktreeStatus','unknown','dirty',[]);
[status,output]=system(sprintf( ...
    'git -C "%s" status --porcelain --untracked-files=all', ...
    strrep(root,'"','\"')));
if status~=0,return,end
state.dirty=~isempty(strtrim(output));
if state.dirty,state.worktreeStatus='dirty';else,state.worktreeStatus='clean';end
end
