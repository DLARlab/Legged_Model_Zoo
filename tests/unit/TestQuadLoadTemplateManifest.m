classdef TestQuadLoadTemplateManifest < matlab.unittest.TestCase
    methods (Test)
        function completeSourceLibraryIsHashBound(testCase)
            library=lmzmodels.slip_quad_load.StrideTemplateLibrary();
            records=library.records();
            testCase.verifyEqual(numel(records),4);
            testCase.verifyEqual(library.Manifest.sourceCommit, ...
                '19f3133073c988cc0c3424a647b4adbb60a90b99');
            testCase.verifyEqual( ...
                library.Manifest.extraExamplesIntroductionCommit, ...
                '1046565048ca4414fe1c507fa6c286cc780ed406');
            testCase.verifyEqual([records.strideCount],[1 2 2 2]);
            testCase.verifyEqual([records.xAccumLength],[44 57 57 57]);
            for index=1:numel(records)
                testCase.verifyTrue(library.validateHash(records(index).id));
            end
        end
    end
end
