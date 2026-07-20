function value=release_commit(root)
value='UNKNOWN';
[status,output]=system(sprintf('git -C "%s" rev-parse HEAD', ...
    strrep(root,'"','\"')));
if status==0
    candidate=strtrim(output);
    if ~isempty(regexp(candidate,'^[0-9a-f]{40}$','once')),value=candidate;end
end
end
