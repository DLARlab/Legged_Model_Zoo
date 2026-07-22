classdef ScrollableViewport < handle
    %SCROLLABLEVIEWPORT Stable scroll host with responsive content extent.
    properties (SetAccess=private)
        Root
        Content
    end
    properties
        ScrollbarAllowance = 18
    end
    properties (Access=private)
        RequestedScrollPosition = [0 0]
        IsRefreshing = false
    end

    methods
        function obj=ScrollableViewport(parent,varargin)
            parser=inputParser;
            addParameter(parser,'MinimumSize',[320 400], ...
                @(value)isnumeric(value)&&numel(value)==2&&all(value>0));
            addParameter(parser,'Tag','lmz-scroll-viewport', ...
                @(value)ischar(value)||(isstring(value)&&isscalar(value)));
            parse(parser,varargin{:});
            obj.Root=uipanel(parent,'BorderType','none','Scrollable','on', ...
                'Tag',char(parser.Results.Tag));
            obj.Root.AutoResizeChildren='off';
            obj.Content=lmz.gui.layout.ScrollableContentPanel(obj.Root, ...
                parser.Results.MinimumSize,[char(parser.Results.Tag) '-content']);
            obj.Root.SizeChangedFcn=@(~,~)obj.refresh();
            obj.refresh();
        end

        function refresh(obj)
            if obj.IsRefreshing||isempty(obj.Root)||~isvalid(obj.Root)|| ...
                    isempty(obj.Content)||~isvalid(obj.Content)
                return
            end
            obj.IsRefreshing=true;
            cleanup=onCleanup(@()obj.finishRefresh());
            position=obj.Root.Position;
            if isprop(obj.Root,'InnerPosition')
                position=obj.Root.InnerPosition;
            end
            available=obj.availableContentSize(position(3:4));
            obj.Content.resize(available);
            % MATLAB's scrollable panel preserves the live browser position
            % across an ordinary child resize.  Do not reapply the last
            % programmatic request here: a user may have moved the scrollbar
            % directly since that request.
            clear cleanup
        end

        function value=scrollPosition(obj)
            value=obj.RequestedScrollPosition;
        end

        function setScrollPosition(obj,value)
            validateattributes(value,{'numeric'}, ...
                {'numel',2,'finite','nonnegative'});
            obj.RequestedScrollPosition=round(reshape(value,1,2));
            obj.applyRequestedScrollPosition();
        end

        function resetScroll(obj),obj.setScrollPosition([0 0]);end

        function value=fitContentToControls(obj,floorSize)
            if nargin<2,floorSize=[360 400];end
            value=obj.Content.fitToControls(floorSize);
            obj.refresh();
        end

        function delete(obj)
            if ~isempty(obj.Root)&&isvalid(obj.Root)
                obj.Root.SizeChangedFcn=[];
            end
            if ~isempty(obj.Content)&&isvalid(obj.Content),delete(obj.Content);end
            obj.Content=[];
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];
        end
    end

    methods (Access=private)
        function value=availableContentSize(obj,clientSize)
            clientSize=max(1,reshape(clientSize,1,2));
            minimum=obj.Content.MinimumSize;
            horizontal=minimum(1)>clientSize(1);
            vertical=minimum(2)>clientSize(2);
            for iteration=1:3
                value=max(1,clientSize-obj.ScrollbarAllowance* ...
                    [vertical horizontal]);
                updatedHorizontal=minimum(1)>value(1);
                updatedVertical=minimum(2)>value(2);
                if updatedHorizontal==horizontal&&updatedVertical==vertical
                    return
                end
                horizontal=updatedHorizontal;vertical=updatedVertical;
            end
        end

        function applyRequestedScrollPosition(obj)
            if isempty(obj.Root)||~isvalid(obj.Root),return,end
            scroll(obj.Root,obj.RequestedScrollPosition);
        end

        function finishRefresh(obj)
            if isvalid(obj),obj.IsRefreshing=false;end
        end
    end
end
