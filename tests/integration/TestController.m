classdef TestController < matlab.unittest.TestCase
    methods(Test),function smoke(t),s=lmz.gui.AppState(lmz.core.ModelRegistry());c=lmz.gui.AppController(s);c.selectModel('slip_quadruped');c.selectProblem('periodic_orbit');t.verifyClass(s.Problem,'lmz.problems.PeriodicOrbitProblem');end,end
end
