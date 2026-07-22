classdef MultiStrideSimulationService
    %MULTISTRIDESIMULATIONSERVICE Dispatch through a model-owned provider.
    methods
        function result=simulate(~,model,request,context)
            if nargin<4||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            if ~isa(model,'lmz.api.LeggedModel')|| ...
                    ~isa(request,'lmz.multistride.MultiStrideRequest')
                error('lmz:MultiStride:SimulationRequest', ...
                    'A model and MultiStrideRequest are required.');
            end
            provider=model.getMultiStrideProvider();
            if isempty(provider)
                error('lmz:MultiStride:UnsupportedModel', ...
                    'The registered model does not provide N-stride simulation.');
            end
            if ~isa(provider,'lmz.multistride.MultiStrideProvider')
                error('lmz:MultiStride:ProviderContract', ...
                    ['A registered N-stride provider must implement ' ...
                    'lmz.multistride.MultiStrideProvider.']);
            end
            result=provider.simulate(model,request,context);
        end
    end
end
