classdef TestQuadLoadStrideParameterGraphics < matlab.unittest.TestCase
    methods (Test)
        function capturedBoundaryCasesSelectExpectedRows(testCase)
            fixture=QuadLoadGraphicsTestSupport.fixture();
            cases=fixture.selectorCases;
            for index=1:numel(cases)
                selected=lmzmodels.slip_quad_load. ...
                    ActiveStrideParameterSelector.select( ...
                    fixture.parameterRows,cases(index).time);
                testCase.verifyEqual(selected.StrideIndex, ...
                    cases(index).strideIndex);
                testCase.verifyEqual(selected.Offset,cases(index).offset, ...
                    'AbsTol',eps);
                testCase.verifyEqual(selected.GlobalRow(1:9), ...
                    reshape(cases(index).globalFirstNine,1,[]), ...
                    'AbsTol',2e-15);
            end
        end

        function exactBoundaryUsesLaterRowForAnyStrideCount(testCase)
            rows=QuadLoadGraphicsTestSupport.fixture().parameterRows;
            third=rows(2,:);third(1:9)=[.05 .1 .15 .2 .25 .3 .35 .4 .5];
            rows=[rows;third];
            second=lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
                select(rows,rows(1,9));
            thirdSelection=lmzmodels.slip_quad_load. ...
                ActiveStrideParameterSelector.select(rows,sum(rows(1:2,9)));
            testCase.verifyEqual(second.StrideIndex,2);
            testCase.verifyEqual(thirdSelection.StrideIndex,3);
            testCase.verifyEqual(thirdSelection.Offset,sum(rows(1:2,9)), ...
                'AbsTol',eps);
            testCase.verifyEqual(thirdSelection.LocalRow,third,'AbsTol',eps);
        end

        function frameSelectionUsesSimulationTime(testCase)
            simulation=QuadLoadGraphicsTestSupport.simulation();
            selected=lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
                forFrame(simulation,2);
            testCase.verifyEqual(selected.StrideIndex,2);
            testCase.verifyEqual(selected.FrameTime,1.5,'AbsTol',eps);
            testCase.verifyError(@() ...
                lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
                forFrame(simulation,0), ...
                'lmz:slip_quad_load:GraphicsFrame');
        end

        function invalidDurationsAreRejected(testCase)
            rows=QuadLoadGraphicsTestSupport.fixture().parameterRows;
            rows(2,9)=0;
            testCase.verifyError(@() ...
                lmzmodels.slip_quad_load.ActiveStrideParameterSelector. ...
                select(rows,1), ...
                'lmz:slip_quad_load:GraphicsDuration');
        end
    end
end
