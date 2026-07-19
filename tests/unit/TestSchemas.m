classdef TestSchemas < matlab.unittest.TestCase
    methods(Test)
        function roundTrip(t),s=lmz.models.slip_quadruped.SLIPQuadrupedModel.stateSchemaStatic();x=s.defaults();t.verifyEqual(s.encode(s.decode(x)),x);t.verifyEqual(s.width(),13);end
        function invalidScale(t),e=lmz.core.NamedVectorSchema.entry('x','x','g','1',1,0,2,1);e.scale=0;t.verifyError(@()lmz.core.NamedVectorSchema(e),'lmz:Validation');end
        function loadCodecRoundTrip(t),c=lmz.models.slip_quad_load.LegacyQuadLoadCodec();for n=1:4,v=(1:(44+13*(n-1))).';t.verifyEqual(c.encode(c.decode(v)),v);t.verifyEqual(c.strideCount(v),n);end,end
    end
end
