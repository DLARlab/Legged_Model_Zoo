classdef TestNoInteractivePromptInCore < matlab.unittest.TestCase
    %TESTNOINTERACTIVEPROMPTINCORE Guard reusable multi-stride runtime code.
    methods (Test)
        function coreUsesNoInteractiveInput(testCase)
            files=[lmz.compat.Files.recursive(fullfile( ...
                lmz.util.ProjectPaths.root(),'src','+lmz','+multistride'), ...
                '*.m',true);dir(fullfile(lmz.util.ProjectPaths.root(), ...
                'src','+lmz','+services','MultiStrideSimulationService.m'))];
            for index=1:numel(files)
                source=fileread(fullfile(files(index).folder,files(index).name));
                testCase.verifyEmpty(regexp(source, ...
                    '\<(input|questdlg|uigetfile|uiputfile)\s*\(', ...
                    'once'),files(index).name);
            end
        end
    end
end
