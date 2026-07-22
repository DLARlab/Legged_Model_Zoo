classdef TestDataProviderNoCoreModelBranch < matlab.unittest.TestCase
    methods (Test)
        function genericBranchAndWorkflowCodeHasNoBuiltInCases(testCase)
            root=lmz.util.ProjectPaths.root();
            files=[{fullfile(root,'src','+lmz','+services', ...
                'BranchService.m')};workflowFiles(root)];
            forbidden={'slip_quadruped','slip_biped','slip_quad_load', ...
                'tutorial_hopper','lmzmodels.','RoadMapCatalog', ...
                'GaitMapCatalog','ScientificDatasetCatalog', ...
                'Results29Adapter','Results14Adapter','XAccum'};
            for fileIndex=1:numel(files)
                text=fileread(files{fileIndex});
                for tokenIndex=1:numel(forbidden)
                    testCase.verifyEmpty(strfind(text,forbidden{tokenIndex}), ...
                        sprintf('%s contains model-specific token %s.', ...
                        files{fileIndex},forbidden{tokenIndex}));
                end
            end
        end
    end
end

function files=workflowFiles(root)
records=dir(fullfile(root,'src','+lmz','+workflow','*.m'));
files=cell(numel(records),1);
for index=1:numel(records)
    files{index}=fullfile(records(index).folder,records(index).name);
end
end
