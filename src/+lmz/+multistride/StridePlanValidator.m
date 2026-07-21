classdef StridePlanValidator
    %STRIDEPLANVALIDATOR Structural validation for complete or partial plans.
    methods (Static)
        function report=validate(plan,varargin)
            if ~isa(plan,'lmz.multistride.StridePlan')||~isscalar(plan)
                error('lmz:MultiStride:StridePlan','A scalar StridePlan is required.');
            end
            requireComplete=false;
            if nargin>1,requireComplete=logical(varargin{1});end
            if plan.CompletedStrideCount~=numel(plan.StrideSpecs)|| ...
                    plan.CompletedStrideCount>plan.RequestedStrideCount
                error('lmz:MultiStride:StridePlanCount', ...
                    'Completed, requested, and stored stride counts disagree.');
            end
            for index=1:numel(plan.StrideSpecs)
                spec=plan.StrideSpecs(index);spec.validate();
                if spec.Index~=index
                    error('lmz:MultiStride:StrideIndex', ...
                        'Stride specifications must have consecutive indices.');
                end
                if any(strcmp(spec.CompletionStatus,{'missing','failed','partial'}))
                    error('lmz:MultiStride:StoredIncompleteStride', ...
                        'Only supplied or completed strides belong in the completed prefix.');
                end
            end
            if requireComplete&&plan.CompletedStrideCount~=plan.RequestedStrideCount
                error('lmz:MultiStride:IncompletePlan', ...
                    'The stride plan is incomplete.');
            end
            report=struct('Valid',true,'Complete', ...
                plan.CompletedStrideCount==plan.RequestedStrideCount, ...
                'RequestedStrideCount',plan.RequestedStrideCount, ...
                'CompletedStrideCount',plan.CompletedStrideCount);
        end
    end
end
