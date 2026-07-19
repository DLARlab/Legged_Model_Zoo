classdef BranchCatalog < handle
    properties (SetAccess=private), Entries={}; end
    methods
        function add(obj,branch,metadata),obj.Entries{end+1}=struct('Branch',branch,'Metadata',metadata);end
        function value=count(obj),value=numel(obj.Entries);end
    end
end
