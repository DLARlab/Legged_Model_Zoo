classdef TestLayoutProfileRegistry < matlab.unittest.TestCase
    methods (Test)
        function exposesStableProfiles(testCase)
            ids=lmz.gui.layout.LayoutProfileRegistry.list();
            testCase.verifyEqual(ids, ...
                {'scientific_workbench','classic_tabs'});
            profile=lmz.gui.layout.LayoutProfileRegistry.get( ...
                'scientific_workbench');
            testCase.verifyEqual(profile.SidebarRatio,[3.35 1.85]);
            testCase.verifyEqual(profile.MinimumContentSize,[880 570]);
        end
    end
end
