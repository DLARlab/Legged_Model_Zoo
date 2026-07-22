classdef BranchComponentGroup < handle
    %BRANCHCOMPONENTGROUP Owning host-neutral branch UI component.
    properties (SetAccess=private)
        Root = []
        Controls = struct()
        Id
    end
    methods
        function obj=BranchComponentGroup(id)
            obj.Id=char(id);
        end
        function value=testHooks(obj)
            value=struct('Id',obj.Id,'Root',obj.Root, ...
                'Controls',obj.Controls,'OwnsRoot',true);
        end
        function delete(obj)
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];obj.Controls=struct();
        end
    end

    methods (Access=protected)
        function own(obj,root,controls)
            if isempty(root)||~isvalid(root)
                error('lmz:GUI:BranchComponentRoot', ...
                    'A branch component must own a valid UI root.');
            end
            obj.Root=root;obj.Controls=controls;
        end
    end
end
