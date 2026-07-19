classdef TestRegistry < matlab.unittest.TestCase
    methods(Test),function discoversModels(t),r=lmz.core.ModelRegistry();t.verifyTrue(all(ismember({'slip_quadruped','jerboa_biped','slip_quad_load'},r.ids())));for id=r.ids(),m=r.create(id{1});meta=m.metadata();t.verifyEqual(meta.id,id{1});end,end,end
end
