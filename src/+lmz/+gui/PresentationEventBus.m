classdef PresentationEventBus < handle
    %PRESENTATIONEVENTBUS Batched, leak-testable presentation notifications.
    properties (SetAccess=private)
        LastDispatchErrors = {}
    end
    properties (Access=private)
        Subscribers = struct('Id',{},'Topics',{},'Callback',{})
        NextSubscriberId = 1
        TransactionDepth = 0
        PendingNames = {}
        PendingPayloads = {}
        TransactionCounter = 0
        IsDisposing = false
    end

    methods
        function token = subscribe(obj,topics,callback)
            if ischar(topics)||isstring(topics), topics = cellstr(topics); end
            if ~iscell(topics)||isempty(topics)
                error('lmz:GUI:PresentationTopics', ...
                    'At least one presentation topic is required.');
            end
            topics = unique(cellfun(@char,topics,'UniformOutput',false),'stable');
            for index = 1:numel(topics)
                lmz.gui.PresentationEvents.validate(topics{index});
            end
            if ~isa(callback,'function_handle')
                error('lmz:GUI:PresentationCallback', ...
                    'Presentation callback must be a function handle.');
            end
            id = obj.NextSubscriberId;
            obj.NextSubscriberId = obj.NextSubscriberId+1;
            obj.Subscribers(end+1) = struct('Id',id,'Topics',{topics}, ...
                'Callback',callback);
            token = lmz.gui.PresentationSubscription(obj,id);
        end

        function guard = beginTransaction(obj)
            obj.TransactionDepth = obj.TransactionDepth+1;
            guard = onCleanup(@()obj.finishTransaction());
        end

        function publish(obj,name,payload)
            if nargin<3, payload = struct(); end
            lmz.gui.PresentationEvents.validate(name);
            name = char(name);
            if obj.TransactionDepth>0
                index = find(strcmp(name,obj.PendingNames),1);
                if isempty(index)
                    obj.PendingNames{end+1} = name;
                    obj.PendingPayloads{end+1} = payload;
                else
                    obj.PendingPayloads{index} = payload;
                end
                return
            end
            obj.dispatch({name},{payload});
        end

        function unsubscribe(obj,id)
            if obj.IsDisposing||isempty(obj.Subscribers), return, end
            obj.Subscribers([obj.Subscribers.Id]==id) = [];
        end

        function value = subscriptionCount(obj)
            value = numel(obj.Subscribers);
        end

        function value = transactionCount(obj)
            value = obj.TransactionCounter;
        end

        function finishTransaction(obj)
            % Public for the onCleanup callback; callers should use beginTransaction.
            if obj.TransactionDepth<=0, return, end
            obj.TransactionDepth = obj.TransactionDepth-1;
            if obj.TransactionDepth~=0||isempty(obj.PendingNames), return, end
            names = obj.PendingNames;
            payloads = obj.PendingPayloads;
            obj.PendingNames = {};
            obj.PendingPayloads = {};
            [~,order] = sort(lmz.gui.PresentationEvents.order(names));
            obj.dispatch(names(order),payloads(order));
        end

        function delete(obj)
            obj.IsDisposing = true;
            obj.Subscribers = struct('Id',{},'Topics',{},'Callback',{});
            obj.PendingNames = {};
            obj.PendingPayloads = {};
        end
    end

    methods (Access=private)
        function dispatch(obj,names,payloads)
            obj.TransactionCounter = obj.TransactionCounter+1;
            transactionId = obj.TransactionCounter;
            timestamp = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
            batch = repmat(struct('Name','','Payload',struct(), ...
                'Timestamp',timestamp,'TransactionId',transactionId),1,numel(names));
            for index = 1:numel(names)
                batch(index).Name = names{index};
                batch(index).Payload = payloads{index};
            end
            obj.LastDispatchErrors = {};
            subscriberIds = [obj.Subscribers.Id];
            for subscriberIndex = 1:numel(subscriberIds)
                current = find([obj.Subscribers.Id]==subscriberIds(subscriberIndex),1);
                if isempty(current), continue, end
                subscriber = obj.Subscribers(current);
                selected = ismember(names,subscriber.Topics);
                if ~any(selected), continue, end
                try
                    subscriber.Callback(batch(selected));
                catch exception
                    obj.LastDispatchErrors{end+1} = exception;
                end
            end
        end
    end

end
