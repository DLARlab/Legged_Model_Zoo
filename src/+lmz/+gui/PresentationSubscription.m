classdef PresentationSubscription < handle
    %PRESENTATIONSUBSCRIPTION Deterministic event-bus subscription token.
    properties (SetAccess=private)
        Id
        IsActive = true
    end
    properties (Access=private)
        Bus
    end

    methods
        function obj = PresentationSubscription(bus,id)
            obj.Bus = bus;
            obj.Id = id;
        end

        function dispose(obj)
            if ~obj.IsActive, return, end
            obj.IsActive = false;
            bus = obj.Bus;
            obj.Bus = [];
            if ~isempty(bus) && isvalid(bus)
                bus.unsubscribe(obj.Id);
            end
        end

        function delete(obj)
            obj.dispose();
        end
    end
end
