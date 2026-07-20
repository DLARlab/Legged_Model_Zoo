classdef TestResearchRendererPerformance < matlab.unittest.TestCase
    methods (Test)
        function lifecycleAndGeometryStayWithinConservativeBudgets(testCase)
            helperRoot=fullfile(lmz.util.ProjectPaths.root(), ...
                'tools','maintainers');
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(helperRoot));
            report=benchmark_research_renderers(struct( ...
                'Repetitions',2,'UpdateCount',100, ...
                'CaptureFrames',true,'Verbose',true));

            testCase.verifyEqual(report.RuntimeRelease,version('-release'));
            testCase.verifyEqual(report.UpdateCount,100);
            testCase.verifyFalse(report.SourceRepositoryRuntimeDependency);
            testCase.verifyEqual(report.RuntimeRoots,{'src','models','catalog'});
            testCase.verifyEqual({report.Records.ModelId}, ...
                {'slip_quadruped','slip_biped','slip_quad_load'});

            % R2025b macOS arm64 measurements are substantially below these
            % limits. The large floors protect slower CI graphics backends
            % while still detecting lost handle reuse or accidental loops.
            budgets=struct('ConstructionSeconds',8, ...
                'Update100Seconds',10,'ProfileSwitchSeconds',8, ...
                'CaptureFrameSeconds',15);
            names=fieldnames(budgets);
            for index=1:numel(report.Records)
                record=report.Records(index);
                testCase.verifyTrue(record.StableHandleIdentity, ...
                    [record.ModelId ' replaced graphics handles during updates.']);
                testCase.verifyTrue(record.ProfileSwitchPreservedIndex);
                testCase.verifyTrue(record.ProfileSwitchRetainedResearchClass);
                testCase.verifyEqual(record.HandleCountAfterSwitch, ...
                    record.HandleCount);
                testCase.verifyGreaterThan(record.HandleCount,10);
                testCase.verifyGreaterThan(record.CaptureSize(1),10);
                testCase.verifyGreaterThan(record.CaptureSize(2),10);
                for budgetIndex=1:numel(names)
                    name=names{budgetIndex};
                    testCase.verifyLessThanOrEqual(record.(name),budgets.(name), ...
                        sprintf('%s %s exceeded %.1f seconds.', ...
                        record.ModelId,name,budgets.(name)));
                end
            end

            testCase.verifyEqual(report.Ground.QuadrupedVertexCount,20002);
            testCase.verifyEqual(report.Ground.BipedVertexCount,20002);
            testCase.verifyLessThanOrEqual( ...
                report.Ground.QuadrupedSeconds,5);
            testCase.verifyLessThanOrEqual(report.Ground.BipedSeconds,5);
            testCase.verifyEqual(report.QuadrupedPhase.UpdateCount,100);
            testCase.verifyEqual(report.QuadrupedPhase.BarCount,4);
            testCase.verifyLessThanOrEqual( ...
                report.QuadrupedPhase.UpdateSeconds,5);
        end
    end
end
