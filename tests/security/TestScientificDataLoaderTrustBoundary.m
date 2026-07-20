classdef TestScientificDataLoaderTrustBoundary < matlab.unittest.TestCase
    methods (Test)
        function legacyAdaptersRejectUnsafeNestedValues(testCase)
            path = [tempname '.mat']; cleanup = onCleanup(@() deleteFile(path));
            X_accum = zeros(44, 1); %#ok<NASGU>
            malicious = @sin; %#ok<NASGU>
            save(path, 'X_accum', 'malicious');
            testCase.verifyError(@() ...
                lmzmodels.slip_quad_load.XAccumAdapter.loadDataset(path), ...
                'lmz:Mat:UnsafeTopLevelType');
            clear cleanup
        end

        function resultsAdaptersRejectWrongTypesAfterSafeLoad(testCase)
            path = [tempname '.mat']; cleanup = onCleanup(@() deleteFile(path));
            results = 'not numeric'; %#ok<NASGU>
            save(path, 'results');
            testCase.verifyError(@() ...
                lmzmodels.slip_biped.Results14Adapter.loadBranch(path), ...
                'lmz:slip_biped:LegacyFormat');
            clear cleanup
        end
    end
end
function deleteFile(path), if exist(path, 'file') == 2, delete(path); end, end
