classdef LayoutProfile
    %LAYOUTPROFILE Declarative placement policy for the application shell.
    properties (SetAccess=private)
        Id
        Label
        PreferredSize
        MinimumContentSize
        SidebarRatio
    end

    methods
        function obj=LayoutProfile(id,label,varargin)
            parser=inputParser;
            addRequired(parser,'id',@isIdentifier);
            addRequired(parser,'label',@(value)ischar(value)|| ...
                (isstring(value)&&isscalar(value)));
            addParameter(parser,'PreferredSize',[1120 740],@isSize);
            addParameter(parser,'MinimumContentSize',[880 570],@isSize);
            addParameter(parser,'SidebarRatio',[3.35 1.85],@isRatio);
            parse(parser,id,label,varargin{:});
            obj.Id=char(parser.Results.id);
            obj.Label=char(parser.Results.label);
            obj.PreferredSize=reshape(parser.Results.PreferredSize,1,2);
            obj.MinimumContentSize=reshape( ...
                parser.Results.MinimumContentSize,1,2);
            obj.SidebarRatio=reshape(parser.Results.SidebarRatio,1,2);
        end

        function value=toStruct(obj)
            value=struct('id',obj.Id,'label',obj.Label, ...
                'preferredSize',obj.PreferredSize, ...
                'minimumContentSize',obj.MinimumContentSize, ...
                'sidebarRatio',obj.SidebarRatio);
        end
    end
end

function value=isIdentifier(source)
value=(ischar(source)||(isstring(source)&&isscalar(source)))&& ...
    ~isempty(regexp(char(source),'^[a-z][a-z0-9_]*$','once'));
end
function value=isSize(source)
value=isnumeric(source)&&numel(source)==2&& ...
    all(isfinite(source))&&all(source>0);
end
function value=isRatio(source)
value=isSize(source)&&all(source>=0.1);
end
