classdef ProjectPaths
    %PROJECTPATHS Canonical locations belonging to this checkout.
    methods (Static)
        function path = root()
            persistent projectRoot
            if isempty(projectRoot)
                sourceFile = mfilename('fullpath');
                projectRoot = fileparts(fileparts(fileparts(fileparts(sourceFile))));
                projectRoot = lmz.util.ProjectPaths.canonical(projectRoot);
            end
            path = projectRoot;
        end

        function path = src()
            path = fullfile(lmz.util.ProjectPaths.root(), 'src');
        end

        function path = models()
            path = fullfile(lmz.util.ProjectPaths.root(), 'models');
        end

        function path = catalog()
            path = fullfile(lmz.util.ProjectPaths.root(), 'catalog');
        end

        function path = tests()
            path = fullfile(lmz.util.ProjectPaths.root(), 'tests');
        end

        function path = examples()
            path = fullfile(lmz.util.ProjectPaths.root(), 'examples');
        end

        function path = temporary()
            path = fullfile(tempdir(), 'legged_model_zoo');
        end

        function path = checkpoints()
            path = fullfile(lmz.util.ProjectPaths.temporary(), 'checkpoints');
        end
    end

    methods (Static, Access=private)
        function path = canonical(path)
            [ok, attributes] = fileattrib(path);
            if ~ok
                error('lmz:ProjectPaths:MissingPath', ...
                    'Project path does not exist: %s', path);
            end
            path = attributes.Name;
        end
    end
end
