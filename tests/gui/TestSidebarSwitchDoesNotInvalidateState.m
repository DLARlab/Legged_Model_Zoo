classdef TestSidebarSwitchDoesNotInvalidateState < matlab.unittest.TestCase
    methods (Test)
        function switchingIsPresentationOnly(testCase)
            [app,~,cleanup]=Round11GUITestSupport.makeApp();
            before=stateSnapshot(app.Controller.State);
            layout=Round11GUITestSupport.scientificLayout(app);
            ids=Round11GUITestSupport.sidebarIds(layout);
            for index=1:numel(ids)
                layout.SidebarHost.select(ids{index});drawnow;
            end
            testCase.verifyEqual(stateSnapshot(app.Controller.State),before);
            clear cleanup
        end
    end
end

function value=stateSnapshot(state)
value=struct('ModelId',state.ModelId,'ProblemId',state.ProblemId, ...
    'DatasetCount',numel(state.Datasets), ...
    'ActiveDatasetId',state.ActiveDatasetId, ...
    'LockedSelection',state.LockedSelection, ...
    'SolveResult',state.SolveResult,'SeedPair',state.SeedPair, ...
    'ContinuationResult',state.ContinuationResult);
end
