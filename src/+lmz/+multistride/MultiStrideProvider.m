classdef (Abstract) MultiStrideProvider < handle
    %MULTISTRIDEPROVIDER Model-owned N-stride completion/simulation contract.
    methods (Abstract)
        result=simulate(obj,model,request,context)
        report=previewEnergy(obj,plan,count,energyNeutral,overrides,declaredWork,context)
        schedule=scheduleOverride(obj,plan,index,timing)
    end
end
