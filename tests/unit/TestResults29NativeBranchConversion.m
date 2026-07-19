classdef TestResults29NativeBranchConversion < matlab.unittest.TestCase
    methods (Test)
        function exactRoundTripAndPointMetadata(testCase)
            catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();path=catalog.defaultBranchPath();loaded=load(path,'results');
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());branch=lmzmodels.slip_quadruped.Results29Adapter.loadBranch(path,problem);
            testCase.verifyEqual(lmzmodels.slip_quadruped.Results29Adapter.encode(branch),loaded.results);
            point=branch.point(267);testCase.verifyEqual(numel(point.DecisionValues),22);testCase.verifyEqual(numel(point.ParameterValues),7);
            testCase.verifyEqual(point.Classification.Abbreviation,'PF');testCase.verifyEqual(point.Provenance.PointSource.ColumnIndex,267);
            testCase.verifyEqual(point.Provenance.PointSource.SHA256,catalog.record(path).sha256);
        end
    end
end
