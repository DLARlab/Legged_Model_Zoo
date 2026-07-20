classdef RegistryEntryContext
    %REGISTRYENTRYCONTEXT Trusted catalog metadata bound to a model instance.
    properties (SetAccess = private)
        Manifest
        ProblemDescriptors
        CatalogDirectory
        CodeRoot
        External
    end
    methods
        function obj = RegistryEntryContext(manifest, catalogDirectory, ...
                codeRoot, external)
            obj.Manifest = manifest;
            obj.ProblemDescriptors = manifest.problemDescriptors;
            obj.CatalogDirectory = catalogDirectory;
            obj.CodeRoot = codeRoot;
            obj.External = logical(external);
        end

        function descriptor = problemDescriptor(obj, problemId)
            descriptor = [];
            for index = 1:numel(obj.ProblemDescriptors)
                candidate = obj.ProblemDescriptors{index};
                if strcmp(candidate.id, problemId)
                    descriptor = candidate;
                    break
                end
            end
            if isempty(descriptor)
                error('lmz:Registry:UnknownProblem', ...
                    'Unknown problem %s for model %s.', ...
                    problemId, obj.Manifest.id);
            end
        end
    end
end
