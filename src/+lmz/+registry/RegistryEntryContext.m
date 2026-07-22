classdef RegistryEntryContext
    %REGISTRYENTRYCONTEXT Trusted catalog metadata bound to a model instance.
    properties (SetAccess = private)
        Manifest
        ProblemDescriptors
        CatalogDirectory
        CodeRoot
        TrustedNamespace
        External
    end
    methods
        function obj = RegistryEntryContext(manifest, catalogDirectory, ...
                codeRoot, external)
            obj.Manifest = manifest;
            obj.ProblemDescriptors = manifest.problemDescriptors;
            obj.CatalogDirectory = catalogDirectory;
            obj.CodeRoot = codeRoot;
            obj.TrustedNamespace = manifest.trustedNamespace;
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

        function provider = createProvider(obj, className, expectedClass, varargin)
            %CREATEPROVIDER Instantiate a declaratively named trusted provider.
            % Provider names come from inert catalog JSON, but execution is
            % permitted only after the class resolves uniquely inside the
            % registered model/plugin code root and package namespace.
            if ~ischar(className) || isempty(regexp(className, ...
                    '^[A-Za-z][A-Za-z0-9_.]*$', 'once'))
                error('lmz:Registry:ProviderClass', ...
                    'Provider class names must be dotted MATLAB identifiers.');
            end
            implementation = obj.Manifest.implementationClass;
            separator = find(implementation == '.', 1, 'last');
            if isempty(separator)
                error('lmz:Registry:ProviderNamespace', ...
                    'The registered implementation class has no package.');
            end
            modelNamespace = implementation(1:separator - 1);
            prefix = [modelNamespace '.'];
            if ~strncmp(className, prefix, numel(prefix))
                error('lmz:Registry:ProviderNamespace', ...
                    ['Provider %s is outside the registered model package ' ...
                    '%s.'], className, modelNamespace);
            end
            matches = which(className, '-all');
            if isempty(matches)
                error('lmz:Registry:MissingProvider', ...
                    'Registered provider class is unavailable: %s', className);
            end
            if ischar(matches), matches = {matches}; end
            canonicalMatches = cell(size(matches));
            for index = 1:numel(matches)
                canonicalMatches{index} = ...
                    lmz.util.PathGuard.canonical(matches{index}, true);
            end
            canonicalMatches = unique(canonicalMatches);
            if numel(canonicalMatches) ~= 1
                error('lmz:Registry:AmbiguousProvider', ...
                    'Registered provider class is shadowed: %s', className);
            end
            if ~lmz.util.PathGuard.isWithin(obj.CodeRoot, canonicalMatches{1})
                error('lmz:Registry:ProviderOutsideRoot', ...
                    'Provider %s resolves outside its trusted code root.', ...
                    className);
            end
            constructor = str2func(className);
            provider = constructor(varargin{:});
            if nargin >= 3 && ~isempty(expectedClass) && ...
                    ~isa(provider, expectedClass)
                error('lmz:Registry:ProviderContract', ...
                    'Provider %s must implement %s.', className, expectedClass);
            end
        end
    end
end
