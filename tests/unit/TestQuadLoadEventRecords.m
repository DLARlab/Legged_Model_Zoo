classdef TestQuadLoadEventRecords < matlab.unittest.TestCase
    methods (Test)
        function recordsExposeEverySourceEventAndState(testCase)
            fixture=loadFixture();expected=fixture.Entries(2);tolerance=fixture.Tolerances;
            dataset=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default().load( ...
                'individual_1_tr_to_rl');
            raw=lmzmodels.slip_quad_load.MultiStrideSimulator().runRaw( ...
                dataset.XAccum,lmz.api.RunContext.synchronous(503),false);
            records=raw.EventRecords;names={'BL_TD','BL_LO','FL_TD','FL_LO', ...
                'BR_TD','BR_LO','FR_TD','FR_LO','APEX'};
            testCase.verifyEqual(numel(records),18);
            testCase.verifyEqual({records(1:9).Name},names);
            testCase.verifyEqual({records(10:18).Name},names);
            testCase.verifyEqual([records.StrideIndex],[ones(1,9) 2*ones(1,9)]);
            testCase.verifyEqual(raw.EventStates,expected.EventStates, ...
                'AbsTol',tolerance.StateAbsolute,'RelTol',tolerance.StateRelative);
            testCase.verifyEqual([records(1:9).Time],raw.Parameters(1,1:9), ...
                'AbsTol',tolerance.TimeAbsolute);
            testCase.verifyEqual([records(10:18).Time]-raw.StrideBoundaries(2).StartTime, ...
                raw.Parameters(2,1:9),'AbsTol',tolerance.TimeAbsolute);
        end
    end
end
function baseline=loadFixture()
loaded=load(fullfile(lmz.util.ProjectPaths.tests(),'fixtures','baselines', ...
    'slip_quad_load','source_baselines.mat'),'baseline');baseline=loaded.baseline;
end
