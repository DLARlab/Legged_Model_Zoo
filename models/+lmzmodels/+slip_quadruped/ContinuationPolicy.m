classdef ContinuationPolicy
    %CONTINUATIONPOLICY Model-owned gait/feasibility continuation rules.
    properties
        RequireSameGait = false
        ResidualTolerance = 1e-6
        DuplicateTolerance = 1e-7
    end
    methods
        function obj = ContinuationPolicy(options)
            if nargin < 1, return, end
            names = fieldnames(options);
            for index = 1:numel(names)
                if isprop(obj,names{index}), obj.(names{index}) = options.(names{index}); end
            end
        end
        function [accepted, reason] = accepts(obj, first, second)
            accepted = first.Feasibility.Valid && second.Feasibility.Valid;
            reason = '';
            if ~accepted, reason = 'infeasible-seed'; return, end
            if obj.RequireSameGait && isfield(first.Classification,'Abbreviation') && ...
                    isfield(second.Classification,'Abbreviation') && ...
                    ~strcmp(first.Classification.Abbreviation,second.Classification.Abbreviation)
                accepted = false; reason = 'gait-transition';
            end
        end
    end
end
