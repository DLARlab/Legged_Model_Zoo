classdef ResponsiveGridPolicy
    %RESPONSIVEGRIDPOLICY Compute scroll content size without hiding controls.
    properties (SetAccess=private)
        PreferredSize
        MinimumContentSize
    end

    methods
        function obj=ResponsiveGridPolicy(preferred,minimum)
            if nargin<1,preferred=[1120 740];end
            if nargin<2,minimum=[880 570];end
            obj.PreferredSize=reshape(preferred,1,2);
            obj.MinimumContentSize=reshape(minimum,1,2);
        end

        function value=contentSize(obj,available)
            available=reshape(available,1,2);
            value=max(obj.MinimumContentSize,available);
        end

        function value=isPreferred(obj,available)
            value=all(reshape(available,1,2)>=obj.PreferredSize);
        end
    end
end
