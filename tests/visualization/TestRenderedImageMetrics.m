classdef TestRenderedImageMetrics < matlab.unittest.TestCase
    methods (Test)
        function identicalImagesHavePerfectPortableMetrics(testCase)
            imageData=uint8(255*ones(80,100,3));
            imageData(20:60,30:70,1)=20;imageData(20:60,30:70,2)=90;
            result=lmz.viz.ImageMetrics.compare(imageData,imageData);
            testCase.verifyEqual(result.NormalizedRMSE,0,'AbsTol',eps);
            testCase.verifyEqual(result.EdgeMapOverlap,1,'AbsTol',eps);
            testCase.verifyEqual(result.ForegroundBoundingBoxAgreement,1,'AbsTol',eps);
            testCase.verifyEqual(result.ColorClusterAgreement,1,'AbsTol',eps);
        end

        function smallShiftProducesBoundedNonidenticalMetrics(testCase)
            first=ones(80,100,3);first(20:60,30:70,:)=0.2;
            second=ones(80,100,3);second(21:61,31:71,:)=0.2;
            result=lmz.viz.ImageMetrics.compare(first,second);
            testCase.verifyGreaterThan(result.NormalizedRMSE,0);
            testCase.verifyLessThan(result.NormalizedRMSE,0.2);
            testCase.verifyGreaterThan(result.EdgeMapOverlap,0.4);
            testCase.verifyGreaterThan(result.ForegroundBoundingBoxAgreement,0.85);
            testCase.verifyEqual(result.ColorClusterAgreement,1,'AbsTol',eps);
        end
    end
end
