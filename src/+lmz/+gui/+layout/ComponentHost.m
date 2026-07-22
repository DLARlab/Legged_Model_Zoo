classdef ComponentHost < handle
    %COMPONENTHOST Own one component root without imposing a tab hierarchy.
    properties (SetAccess=private)
        Root
        Mode
        Component = []
    end

    methods
        function obj=ComponentHost(parent,mode,titleText,tag)
            if nargin<2||isempty(mode),mode='workspace';end
            if nargin<3,titleText='';end
            if nargin<4,tag='lmz-component-host';end
            obj.Mode=char(mode);
            if strcmp(obj.Mode,'classic_tabs')
                obj.Root=uitab(parent,'Title',titleText,'Tag',tag);
            else
                obj.Root=uipanel(parent,'BorderType','none','Tag',tag);
            end
        end

        function setComponent(obj,value)
            obj.Component=value;
        end

        function delete(obj)
            if ~isempty(obj.Component)&&isa(obj.Component,'handle')&& ...
                    isvalid(obj.Component)
                obj.Component.dispose();
            end
            obj.Component=[];
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];
        end
    end

    methods (Static)
        function [root,options,baseArguments]=create( ...
                parent,titleText,tag,varargin)
            parser=inputParser;
            addParameter(parser,'HostMode','classic_tabs', ...
                @(value)ischar(value)||(isstring(value)&&isscalar(value)));
            addParameter(parser,'OverlayController',[], ...
                @(value)isempty(value)||isa(value, ...
                'lmz.gui.branch.BranchOverlayController'));
            addParameter(parser,'Placement',struct(), ...
                @(value)isstruct(value)&&isscalar(value));
            addParameter(parser,'ErrorHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            addParameter(parser,'StatusHandler',[], ...
                @(value)isempty(value)||isa(value,'function_handle'));
            parse(parser,varargin{:});
            options=struct('HostMode',char(parser.Results.HostMode), ...
                'OverlayController',parser.Results.OverlayController, ...
                'Placement',parser.Results.Placement);
            host=lmz.gui.layout.ComponentHost(parent,options.HostMode, ...
                titleText,tag);
            root=host.Root;
            % The component, not this short-lived helper, owns the root.
            host.Root=[];
            baseArguments={'ErrorHandler',parser.Results.ErrorHandler, ...
                'StatusHandler',parser.Results.StatusHandler};
        end
    end
end
