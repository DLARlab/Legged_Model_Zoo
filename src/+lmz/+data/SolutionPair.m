classdef SolutionPair
    properties (SetAccess=private), First; Second; RequestedRadius; AchievedRadius; Diagnostics; end
    methods
        function obj=SolutionPair(first,second,requested,achieved,diagnostics)
            obj.First=first; obj.Second=second; obj.RequestedRadius=requested; obj.AchievedRadius=achieved; obj.Diagnostics=diagnostics;
        end
    end
end
