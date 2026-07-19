classdef TestAnimationTimeline < matlab.unittest.TestCase
    methods(Test),function prePostDuplicate(t),r=struct('time',[0;1;1;2],'state',[0;1;2;3]);t.verifyEqual(lmz.hybrid.TrajectoryInterpolator.sample(r,1,'pre'),1);t.verifyEqual(lmz.hybrid.TrajectoryInterpolator.sample(r,1,'post'),2);end,end
end
