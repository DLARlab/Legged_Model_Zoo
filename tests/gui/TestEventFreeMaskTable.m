classdef TestEventFreeMaskTable < matlab.unittest.TestCase
    methods (Test)
        function tableEditsUpdateExplicitEventAndReturnMasks(testCase)
            [app,~,cleanup]=Round9GUITestSupport.makeApp( ...
                'tutorial_hopper','section_return_timing'); %#ok<ASGLU>
            solveTab=app.tab('solve');controller=app.Controller;
            data=solveTab.EventMaskTable.Data;
            testCase.verifyEqual(data(:,1),{'impact';'return_time'});
            testCase.verifyTrue(all(cell2mat(data(:,2))));
            testCase.verifyEqual(solveTab.EventMaskTable.ColumnEditable, ...
                [false true]);

            solveTab.EventMaskTable.Data{1,2}=false;
            callback=solveTab.EventMaskTable.CellEditCallback;
            callback(solveTab.EventMaskTable,[]);drawnow;
            configuration=controller.State.ProblemConfiguration;
            testCase.verifyEqual(configuration.FixedEventMask,true);
            testCase.verifyTrue(configuration.FreeReturnTime);
            testCase.verifyFalse(solveTab.EventMaskTable.Data{1,2});

            solveTab.EventMaskTable.Data{end,2}=false;
            callback(solveTab.EventMaskTable,[]);drawnow;
            configuration=controller.State.ProblemConfiguration;
            testCase.verifyFalse(configuration.FreeReturnTime);
            editor=controller.timingEditorData();
            testCase.verifyEqual(editor.FreeMask,false);
            testCase.verifyFalse(editor.ReturnTimeFree);
            testCase.verifyEqual(controller.Events.LastDispatchErrors,{});
            clear cleanup
        end
    end
end
