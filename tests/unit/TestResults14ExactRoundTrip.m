classdef TestResults14ExactRoundTrip < matlab.unittest.TestCase
    methods (Test)
        function everyBranchRoundTripsExactly(testCase)
            catalog=lmzmodels.slip_biped.GaitMapCatalog.default();records=catalog.branchRecords();
            for index=1:numel(records)
                path=fullfile(catalog.RootPath,records(index).relativePath);loaded=load(path,'results');
                branch=catalog.loadBranch(path,[],true);
                testCase.verifyEqual(lmzmodels.slip_biped.Results14Adapter.encode(branch),loaded.results);
            end
        end
    end
end
