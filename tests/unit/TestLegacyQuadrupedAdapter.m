classdef TestLegacyQuadrupedAdapter < matlab.unittest.TestCase
    methods (Test)
        function exactRoundTrip(testCase)
            path=fullfile(lmz.util.ProjectPaths.examples(),'data','slip_quadruped','RoadMap','PK_20_2.mat');loaded=load(path,'results');raw=loaded.results(:,1:3);
            registry=lmz.registry.ModelRegistry.discover();problem=registry.createModel('slip_quadruped').createProblem('periodic_apex',struct());branch=lmzmodels.slip_quadruped.Results29Adapter.decode(raw,problem,struct());
            testCase.verifyEqual(lmzmodels.slip_quadruped.Results29Adapter.encode(branch),raw);
            testCase.verifyClass(branch,'lmz.data.SolutionBranch');testCase.verifyEqual(branch.ModelId,'slip_quadruped');
        end
        function rejectsWrongRows(testCase)
            testCase.verifyError(@()lmzmodels.slip_quadruped.Results29Adapter.decode(zeros(28,2)), ...
                'lmz:slip_quadruped:LegacyFormat');
        end
    end
end
