classdef MissingStridePolicy
    %MISSINGSTRIDEPOLICY Validated policy for absent stride specifications.
    properties (SetAccess=private)
        Id
    end

    methods
        function obj=MissingStridePolicy(value)
            if nargin<1||isempty(value),value='error_if_missing';end
            value=char(value);
            if ~any(strcmp(value,lmz.multistride.MissingStridePolicy.values()))
                error('lmz:MultiStride:MissingStridePolicy', ...
                    'Unknown missing-stride policy %s.',value);
            end
            obj.Id=value;
        end

        function value=toStruct(obj)
            value=struct('Id',obj.Id);
        end

        function value=char(obj)
            value=obj.Id;
        end
    end

    methods (Static)
        function value=values()
            value={'error_if_missing','carry_forward', ...
                'carry_forward_and_solve_timings','predictor_corrector', ...
                'request_user','provider_callback'};
        end

        function obj=from(value)
            if isa(value,'lmz.multistride.MissingStridePolicy')
                obj=value;
            elseif isstruct(value)&&isfield(value,'Id')
                obj=lmz.multistride.MissingStridePolicy(value.Id);
            else
                obj=lmz.multistride.MissingStridePolicy(value);
            end
        end
    end
end
