classdef TestPresentationEventBus < matlab.unittest.TestCase
    methods (Test)
        function nestedTransactionsCoalesceAndDeliverOnce(testCase)
            bus=lmz.gui.PresentationEventBus();calls={};
            token=bus.subscribe(lmz.gui.PresentationEvents.all(),@capture);
            cleanup=onCleanup(@()delete(token));
            outer=bus.beginTransaction();
            testCase.verifyClass(outer,'onCleanup');
            bus.publish(lmz.gui.PresentationEvents.SelectionChanged,struct('Value',1));
            inner=bus.beginTransaction();
            testCase.verifyClass(inner,'onCleanup');
            bus.publish(lmz.gui.PresentationEvents.ModelChanged,struct('Value','first'));
            bus.publish(lmz.gui.PresentationEvents.SelectionChanged,struct('Value',2));
            clear inner
            testCase.verifyEmpty(calls);
            bus.publish(lmz.gui.PresentationEvents.StatusChanged,struct('Value','ready'));
            clear outer
            testCase.verifyNumElements(calls,1);
            names={calls{1}.Name};
            testCase.verifyEqual(names,{'ModelChanged','SelectionChanged','StatusChanged'});
            testCase.verifyEqual(calls{1}(2).Payload.Value,2);
            testCase.verifyEqual(numel(unique([calls{1}.TransactionId])),1);
            clear cleanup
            function capture(batch),calls{end+1}=batch;end
        end

        function controllerModelChangeIsOneFinalStateBatch(testCase)
            controller=lmz.gui.AppController();batches={};
            token=controller.Events.subscribe(lmz.gui.PresentationEvents.all(),@capture);
            cleanup=onCleanup(@()delete(token));
            controller.selectModel('slip_quadruped');
            testCase.verifyNumElements(batches,1);
            names={batches{1}.Name};
            testCase.verifyEqual(numel(names),numel(unique(names)));
            testCase.verifyTrue(all(ismember({'ModelChanged','ProblemChanged', ...
                'DatasetsChanged','SelectionChanged','WorkingSolutionChanged', ...
                'StatusChanged'},names)));
            testCase.verifyEqual(controller.State.ModelId,'slip_quadruped');
            testCase.verifyEqual(controller.State.WorkingSolution.ModelId,'slip_quadruped');
            clear cleanup
            function capture(batch),batches{end+1}=batch;end
        end

        function deletingSubscriptionStopsDelivery(testCase)
            bus=lmz.gui.PresentationEventBus();count=0;
            token=bus.subscribe('StatusChanged',@(~)increment());
            testCase.verifyEqual(bus.subscriptionCount(),1);
            delete(token);testCase.verifyEqual(bus.subscriptionCount(),0);
            bus.publish('StatusChanged',struct());testCase.verifyEqual(count,0);
            function increment(),count=count+1;end
        end

        function invalidTopicIsRejected(testCase)
            bus=lmz.gui.PresentationEventBus();
            testCase.verifyError(@()bus.publish('NotAnEvent',struct()), ...
                'lmz:GUI:PresentationEvent');
        end
    end
end
