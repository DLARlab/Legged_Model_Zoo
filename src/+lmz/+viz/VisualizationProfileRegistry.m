classdef VisualizationProfileRegistry < handle
    %VISUALIZATIONPROFILEREGISTRY Resolve model/problem profile policy.
    properties (SetAccess=private)
        ModelRegistry
    end
    properties (Access=private)
        ConfigCache
    end
    methods
        function obj=VisualizationProfileRegistry(modelRegistry)
            if nargin<1,modelRegistry=lmz.registry.ModelRegistry.discover();end
            if ~isa(modelRegistry,'lmz.registry.ModelRegistry')
                error('lmz:Graphics:Registry','ModelRegistry is required.');
            end
            obj.ModelRegistry=modelRegistry;
            obj.ConfigCache=containers.Map('KeyType','char','ValueType','any');
        end

        function config=configForModel(obj,modelId)
            modelId=lmz.registry.ModelRegistry.canonicalModelId(modelId);
            if isKey(obj.ConfigCache,modelId),config=obj.ConfigCache(modelId);return,end
            config=obj.ModelRegistry.getGraphicsConfig(modelId);
            obj.ConfigCache(modelId)=config;
        end

        function profiles=profilesForProblem(obj,modelId,problemId)
            descriptor=obj.ModelRegistry.getProblemDescriptor(modelId,problemId);
            profiles=obj.configForModel(modelId).profilesForMaturity(descriptor.maturity);
        end

        function profile=defaultProfile(obj,modelId,problemId)
            descriptor=obj.ModelRegistry.getProblemDescriptor(modelId,problemId);
            config=obj.configForModel(modelId);
            profile=config.getProfile(config.defaultForMaturity(descriptor.maturity));
        end

        function profile=resolve(obj,modelId,problemId,profileId)
            if nargin<4||isempty(profileId)
                profile=obj.defaultProfile(modelId,problemId);return
            end
            descriptor=obj.ModelRegistry.getProblemDescriptor(modelId,problemId);
            profile=obj.configForModel(modelId).getProfile(profileId);
            if ~profile.appliesTo(descriptor.maturity)
                error('lmz:Graphics:ProfileNotApplicable', ...
                    'Profile %s does not apply to %s problems.', ...
                    profile.Id,descriptor.maturity);
            end
        end

        function clearCache(obj)
            obj.ConfigCache=containers.Map('KeyType','char','ValueType','any');
        end
    end
end
