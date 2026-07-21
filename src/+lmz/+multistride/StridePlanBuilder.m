classdef (Abstract) StridePlanBuilder
    %STRIDEPLANBUILDER Extensible construction and completion orchestration.
    methods
        function result=build(obj,request,context)
            if nargin<3||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if ~isa(request,'lmz.multistride.MultiStrideRequest')
                error('lmz:MultiStride:Request','MultiStrideRequest is required.');
            end
            if isempty(request.StridePlan)
                plan=obj.initialPlan(request,context);
            else
                plan=request.StridePlan.clone();
            end
            if request.NumberOfStrides<plan.CompletedStrideCount
                plan=plan.truncate(request.NumberOfStrides);
            elseif request.NumberOfStrides>plan.CompletedStrideCount
                plan=plan.withRequestedStrideCount(request.NumberOfStrides);
            end
            plan=plan.withPolicies(request.CompletionPolicy, ...
                request.EnergyPolicy,request.FailurePolicy);
            options=struct('ProviderCallback',request.ProviderCallback, ...
                'ParameterOverrides',request.ParameterOverrides, ...
                'DeclaredWork',request.DeclaredWork);
            result=lmz.multistride.StridePlanCompletionService().complete( ...
                obj,plan,options,context);
        end
    end

    methods (Abstract)
        plan=initialPlan(obj,request,context)
        plan=completeNext(obj,plan,options,context)
    end
end
