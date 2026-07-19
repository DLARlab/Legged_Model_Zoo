classdef TestReadmeRoadMapContract < matlab.unittest.TestCase
    methods (Test)
        function tutorialIsComplete(testCase)
            text=fileread(fullfile(lmz.util.ProjectPaths.root(),'README.md'));
            required={'## SLIP Quadruped RoadMap Tutorial','Built-in RoadMap','hover','lock','animation','GRF','oscillator','adjacent','second seed','pause','resume','checkpoint','legacy MAT'};
            for index=1:numel(required),testCase.verifyNotEmpty(strfind(lower(text),lower(required{index})));end %#ok<STREMP>
        end
    end
end
