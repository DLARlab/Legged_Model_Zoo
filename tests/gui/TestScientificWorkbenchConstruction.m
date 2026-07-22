classdef TestScientificWorkbenchConstruction < matlab.unittest.TestCase
    methods (Test)
        function constructsSixHostNeutralComponents(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            layout=Round11GUITestSupport.scientificLayout(app);
            testCase.verifyEqual(sort(fieldnames(layout.ComponentMap)), ...
                sort({'branches';'solution';'simulation';'solve'; ...
                'continuation';'optimization'}));
            values=struct2cell(layout.ComponentMap);
            testCase.verifyTrue(all(cellfun(@(item)strcmp( ...
                item.testHooks().HostMode,'workspace'),values)));
            testCase.verifyTrue(isgraphics(layout.StatusPanel.Area));
            clear cleanup
        end
    end
end
