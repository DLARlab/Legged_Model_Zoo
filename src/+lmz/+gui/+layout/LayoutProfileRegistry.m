classdef LayoutProfileRegistry
    %LAYOUTPROFILEREGISTRY Built-in placement profiles for the workbench.
    methods (Static)
        function values=all()
            values=[ ...
                lmz.gui.layout.LayoutProfile('scientific_workbench', ...
                'Scientific workbench','PreferredSize',[1120 740], ...
                'MinimumContentSize',[880 570], ...
                'SidebarRatio',[3.35 1.85]); ...
                lmz.gui.layout.LayoutProfile('classic_tabs', ...
                'Classic tabs','PreferredSize',[1120 740], ...
                'MinimumContentSize',[880 570], ...
                'SidebarRatio',[3.35 1.85])];
        end

        function ids=list()
            values=lmz.gui.layout.LayoutProfileRegistry.all();
            ids=arrayfun(@(item)item.Id,values,'UniformOutput',false);
            ids=reshape(ids,1,[]);
        end

        function value=get(id)
            id=char(id);values=lmz.gui.layout.LayoutProfileRegistry.all();
            index=find(arrayfun(@(item)strcmp(item.Id,id),values),1);
            if isempty(index)
                error('lmz:GUI:LayoutProfile','Unknown layout profile %s.',id);
            end
            value=values(index);
        end

        function id=defaultFor(capabilities,hasBranchData)
            if nargin<1||isempty(capabilities),capabilities=struct();end
            if nargin<2,hasBranchData=false;end
            branchOriented=logical(hasBranchData);
            if isfield(capabilities,'continue')
                branchOriented=branchOriented&&logical(capabilities.('continue'));
            end
            if branchOriented,id='scientific_workbench';else,id='classic_tabs';end
        end
    end
end
