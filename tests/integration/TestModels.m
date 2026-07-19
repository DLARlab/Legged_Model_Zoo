classdef TestModels < matlab.unittest.TestCase
    methods(Test),function finiteSimulation(t),r=lmz.core.ModelRegistry();for id={'slip_quadruped','jerboa_biped','slip_quad_load'},m=r.create(id{1});p=m.createProblem('periodic_orbit',struct());s=m.simulate(struct('decision',p.decisionSchema().defaults()));t.verifyTrue(all(isfinite(s.state(:))));t.verifyEqual(size(s.state,1),numel(s.time));end,end,end
end
