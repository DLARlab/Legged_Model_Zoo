classdef AppController < handle
    properties, State; RootSolver=lmz.solvers.RootSolver(); Optimizer=lmz.solvers.OptimizationSolver(); Search=lmz.solvers.MultiStartSearch(); Continuation=lmz.continuation.PseudoArclengthContinuation(); end
    methods
        function obj=AppController(state),obj.State=state;end
        function selectModel(obj,id),obj.State.SelectedModelId=char(id);obj.State.Model=obj.State.Registry.create(id);obj.State.Problem=[];end
        function selectProblem(obj,id,options),if nargin<3,options=struct();end;obj.State.Problem=obj.State.Model.createProblem(id,options);end
        function result=simulate(obj,request),result=obj.State.Model.simulate(request);end
        function [s,r]=solve(obj,seed,options),[s,r]=obj.RootSolver.solve(obj.State.Problem,seed,options);obj.State.SelectedSolution=s;end
        function out=search(obj,seeds,options),out=obj.Search.run(obj.State.Problem,seeds,options);end
        function b=continueBranch(obj,a,bseed,options),options.CancellationCallback=@()obj.State.CancellationRequested;b=obj.Continuation.run(obj.State.Problem,a,bseed,options);obj.State.Branches{end+1}=b;end
    end
end
