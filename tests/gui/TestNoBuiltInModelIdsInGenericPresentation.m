classdef TestNoBuiltInModelIdsInGenericPresentation < matlab.unittest.TestCase
    methods (Test)
        function genericLayersContainNoCanonicalIdsOrModelPackages(testCase)
            root=lmz.util.ProjectPaths.root();
            folders={fullfile(root,'src','+lmz','+gui'), ...
                fullfile(root,'src','+lmz','+services'), ...
                fullfile(root,'src','+lmz','+workflow')};
            forbidden={'slip_quadruped','slip_biped','slip_quad_load', ...
                'tutorial_hopper','lmzmodels.','RoadMap preset'};
            violations={};
            for folderIndex=1:numel(folders)
                files=dir(fullfile(folders{folderIndex},'**','*.m'));
                for fileIndex=1:numel(files)
                    path=fullfile(files(fileIndex).folder,files(fileIndex).name);
                    source=fileread(path);
                    for tokenIndex=1:numel(forbidden)
                        if contains(source,forbidden{tokenIndex})
                            violations{end+1}=sprintf('%s: %s', ...
                                path,forbidden{tokenIndex}); %#ok<AGROW>
                        end
                    end
                end
            end
            testCase.verifyEmpty(violations);
        end
    end
end
