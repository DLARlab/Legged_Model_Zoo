classdef TestQuadLoadMultipleShootingCodec < matlab.unittest.TestCase
    methods (Test)
        function fixedControlThreeStrideLayoutIsNamedAndRectangular(testCase)
            problem=lmzmodels.slip_quad_load. ...
                QuadLoadMultipleShootingProblem([],struct( ...
                'NumberOfStrides',3,'EnergyMode','diagnostic_only'));
            codec=problem.Codec;decision=codec.decisionDefaults();
            testCase.verifyEqual(codec.unknownCount(),69);
            testCase.verifyEqual(sum(codec.FreeNodeMask(:)),42);
            testCase.verifyFalse(any(codec.FreeControlMask(:)));
            names=codec.DecisionSchema.names();
            testCase.verifyEqual(numel(unique(names)),numel(names));
            decoded=codec.decode(decision);
            testCase.verifyEqual(numel(decoded.Nodes),4);
            testCase.verifyEqual(numel(decoded.Schedules),3);
            for index=1:3
                schedule=decoded.Schedules{index};
                testCase.verifyGreaterThan(min(diff( ...
                    [0;schedule.times();schedule.ReturnTime])),0);
            end
        end

        function strideBoundaryUsesFifteenCoordinateNodes(testCase)
            configuration=struct('NumberOfStrides',2, ...
                'SectionId','stride_boundary', ...
                'EventFreeMask',[true false], ...
                'EnergyMode','diagnostic_only');
            problem=lmzmodels.slip_quad_load. ...
                QuadLoadMultipleShootingProblem([],configuration);
            decision=problem.Codec.decisionDefaults();
            residual=problem.evaluateShooting(decision,[], ...
                lmz.api.RunContext.synchronous(0),false);

            testCase.verifySize(problem.Codec.FreeNodeMask,[3 15]);
            testCase.verifyEqual(sum(problem.Codec.FreeNodeMask(:)),30);
            testCase.verifyEqual(problem.Codec.unknownCount(),46);
            testCase.verifyEqual(numel(residual.scaled()),46);
            testCase.verifyEqual(numel(residual.InterfaceDefects),2);
            testCase.verifyEqual(arrayfun(@(item)numel(item.Values), ...
                residual.Blocks).',[8 15 8 15]);
            testCase.verifyFalse(any(contains( ...
                {residual.Blocks.Name},'section_residual')));
            testCase.verifyTrue(ismember('quad_dy',problem.Horizon. ...
                Nodes{2}.StateSchema.CoordinateNames));

            configuration.FreeNodeMask=false(3,14);
            exception=captureException(@() ...
                lmzmodels.slip_quad_load.QuadLoadMultipleShootingProblem( ...
                [],configuration));
            testCase.verifyEqual(exception.identifier, ...
                'lmz:QuadLoad:ShootingNodeMask');
            testCase.verifyNotEmpty(strfind(exception.message, ...
                'NumberOfNodes-by-15'));
        end

        function mixedSectionsAreRejectedInsteadOfRelabeled(testCase)
            configuration=struct('NumberOfStrides',1, ...
                'StartSectionId','apex', ...
                'StopSectionId','stride_boundary');
            testCase.verifyError(@()lmzmodels.slip_quad_load. ...
                QuadLoadMultipleShootingProblem([],configuration), ...
                'lmz:QuadLoad:HorizonMixedSection');
        end
    end
end

function exception=captureException(callback)
exception=[];
try
    callback();
catch caught
    exception=caught;
end
if isempty(exception)
    error('lmz:Test:ExpectedException','Expected callback to throw.');
end
end
