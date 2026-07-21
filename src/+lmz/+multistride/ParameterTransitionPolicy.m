classdef ParameterTransitionPolicy
    %PARAMETERTRANSITIONPOLICY Rules for carrying parameters between strides.
    properties (SetAccess=private)
        CopyPhysicalExactly
        AllowControlOverrides
        AllowPhysicalOverrides
    end

    methods
        function obj=ParameterTransitionPolicy(varargin)
            parser=inputParser;
            addParameter(parser,'CopyPhysicalExactly',true,@isLogicalScalar);
            addParameter(parser,'AllowControlOverrides',true,@isLogicalScalar);
            addParameter(parser,'AllowPhysicalOverrides',false,@isLogicalScalar);
            parse(parser,varargin{:});values=parser.Results;
            obj.CopyPhysicalExactly=logical(values.CopyPhysicalExactly);
            obj.AllowControlOverrides=logical(values.AllowControlOverrides);
            obj.AllowPhysicalOverrides=logical(values.AllowPhysicalOverrides);
        end

        function diagnostics=validate(obj,before,after)
            same=isequaln(before,after);
            if obj.CopyPhysicalExactly&&~same&&~obj.AllowPhysicalOverrides
                error('lmz:MultiStride:PhysicalParameterTransition', ...
                    'Physical parameters must be copied exactly between strides.');
            end
            diagnostics=struct('PhysicalParametersEqual',same, ...
                'CopyPhysicalExactly',obj.CopyPhysicalExactly, ...
                'AllowPhysicalOverrides',obj.AllowPhysicalOverrides, ...
                'AllowControlOverrides',obj.AllowControlOverrides);
        end

        function value=toStruct(obj)
            value=struct('CopyPhysicalExactly',obj.CopyPhysicalExactly, ...
                'AllowControlOverrides',obj.AllowControlOverrides, ...
                'AllowPhysicalOverrides',obj.AllowPhysicalOverrides);
        end
    end
end

function value=isLogicalScalar(source)
value=(islogical(source)||isnumeric(source))&&isscalar(source)&&isfinite(source);
end
