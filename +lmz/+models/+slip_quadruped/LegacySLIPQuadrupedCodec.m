classdef LegacySLIPQuadrupedCodec
    methods
        function q=decodeResultColumn(~,v),v=v(:);if numel(v)<29,error('lmz:LegacyFormat','Quadruped result requires 29 values.');end;q=struct('initial',lmz.models.slip_quadruped.SLIPQuadrupedModel.stateSchemaStatic().decode(v(1:13)),'events',lmz.models.slip_quadruped.SLIPQuadrupedModel.eventSchemaStatic().decode(v(14:22)),'parameters',lmz.models.slip_quadruped.SLIPQuadrupedModel.parameterSchemaStatic().decode(v(23:29)),'decision',v(1:22));end
        function [x,e,p]=split(~,z),z=z(:);if numel(z)~=29,error('lmz:LegacyFormat','Expected 29 values.');end;x=z(1:13);e=z(14:22);p=z(23:29);end
        function z=join(~,x,e,p),z=[x(:);e(:);p(:)];end
    end
end
