classdef BaseTab < handle
    %BASETAB Shared lifecycle, event, capability, busy, and test behavior.
    properties (SetAccess=protected)
        Controller
        EventBus
        Preferences
        Root
        Id = ''
        RefreshCount = 0
        IsBusy = false
        Capabilities = struct()
        HostMode = 'classic_tabs'
    end
    properties (Access=protected)
        ErrorHandler = []
        StatusHandler = []
        ActionControls = {}
        CancelControls = {}
        CapabilityName = ''
    end
    properties (Access=private)
        Subscriptions = {}
        IsDisposed = false
    end

    methods
        function obj = BaseTab(parent,controller,eventBus,preferences,varargin)
            obj.Controller = controller;
            obj.EventBus = eventBus;
            obj.Preferences = preferences;
            parser = inputParser;
            addParameter(parser,'ErrorHandler',[],@(value)isempty(value)||isa(value,'function_handle'));
            addParameter(parser,'StatusHandler',[],@(value)isempty(value)||isa(value,'function_handle'));
            parse(parser,varargin{:});
            obj.ErrorHandler = parser.Results.ErrorHandler;
            obj.StatusHandler = parser.Results.StatusHandler;
            if nargin>=1 && ~isempty(parent), obj.Root = parent; end
        end

        function build(~)
            % Subclasses own their widget construction.
        end

        function refresh(obj,varargin)
            obj.RefreshCount = obj.RefreshCount+1;
        end

        function setBusy(obj,value,varargin)
            obj.IsBusy = logical(value);
            obj.applyControlState();
        end

        function setCapabilities(obj,value)
            if isempty(value), value = struct(); end
            obj.Capabilities = value;
            obj.applyControlState();
        end

        function setSelection(~,varargin)
            % Optional focused update for subclasses.
        end

        function hooks = testHooks(obj)
            hooks = struct('Id',obj.Id,'Root',obj.Root, ...
                'RefreshCount',obj.RefreshCount,'IsBusy',obj.IsBusy, ...
                'HostMode',obj.HostMode, ...
                'SubscriptionCount',numel(obj.Subscriptions), ...
                'Controls',obj.controlMap());
        end

        function dispose(obj)
            if obj.IsDisposed, return, end
            obj.IsDisposed = true;
            subscriptions = obj.Subscriptions;
            obj.Subscriptions = {};
            for index = 1:numel(subscriptions)
                token = subscriptions{index};
                if ~isempty(token)&&isvalid(token), delete(token); end
            end
            obj.beforeDelete();
            if ~isempty(obj.Root)&&isvalid(obj.Root), delete(obj.Root); end
            obj.Root = [];
        end

        function delete(obj)
            obj.dispose();
        end
    end

    methods (Access=protected)
        function subscribe(obj,topics)
            workflowTopic=lmz.gui.PresentationEvents.WorkflowChanged;
            if ~any(strcmp(topics,workflowTopic))
                topics{end+1}=workflowTopic;
            end
            token = obj.EventBus.subscribe(topics,@(batch)obj.receiveEvents(batch));
            obj.Subscriptions{end+1} = token;
        end

        function receiveEvents(obj,batch)
            if obj.IsDisposed, return, end
            names = {batch.Name};
            runIndex = find(strcmp(names,lmz.gui.PresentationEvents.RunStateChanged),1,'last');
            if ~isempty(runIndex)
                payload = batch(runIndex).Payload;
                busy = ~isempty(obj.Controller.State.CurrentRun) || ...
                    recordingIsActive(obj.Controller.State);
                if isstruct(payload)&&isfield(payload,'Busy'), busy = payload.Busy;
                end
                obj.setBusy(busy,payload);
            end
            if any(ismember(names,{lmz.gui.PresentationEvents.ModelChanged, ...
                    lmz.gui.PresentationEvents.WorkflowChanged, ...
                    lmz.gui.PresentationEvents.ProblemChanged}))
                try
                    obj.setCapabilities(obj.Controller.capabilities());
                catch
                end
            end
            obj.onPresentationEvents(batch);
        end

        function onPresentationEvents(obj,batch)
            obj.refresh(batch);
        end

        function applyControlState(obj)
            capabilityEnabled = true;
            if ~isempty(obj.CapabilityName)&&isfield(obj.Capabilities,obj.CapabilityName)
                capabilityEnabled = logical(obj.Capabilities.(obj.CapabilityName));
            end
            setEnabled(obj.ActionControls,capabilityEnabled&&~obj.IsBusy);
            setEnabled(obj.CancelControls,obj.cancelControlsEnabled());
        end

        function value=cancelControlsEnabled(obj)
            value=obj.IsBusy&&~recordingIsActive(obj.Controller.State);
        end

        function controls = controlMap(~)
            controls = struct();
        end

        function beforeDelete(~)
        end

        function reportError(obj,exception)
            if isa(obj.ErrorHandler,'function_handle')
                obj.ErrorHandler(exception);
            else
                warning('lmz:GUI:Callback','%s',exception.message);
            end
        end

        function reportStatus(obj,message)
            if isa(obj.StatusHandler,'function_handle')
                obj.StatusHandler(message);
            end
        end
    end
end

function setEnabled(controls,value)
state = 'off'; if value, state = 'on'; end
for index = 1:numel(controls)
    control = controls{index};
    if ~isempty(control)&&isvalid(control)&&isprop(control,'Enable')
        control.Enable = state;
    end
end
end

function value=recordingIsActive(state)
recording=state.RecordingState;
value=isstruct(recording)&&isscalar(recording)&& ...
    isfield(recording,'Active')&&islogical(recording.Active)&& ...
    isscalar(recording.Active)&&recording.Active;
end
