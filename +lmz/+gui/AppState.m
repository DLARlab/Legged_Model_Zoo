classdef AppState < handle
    properties, Registry; SelectedModelId=''; Model=[]; Problem=[]; SelectedSolution=[]; Branches={}; Log={}; Busy=false; CancellationRequested=false; end
    methods, function obj=AppState(registry),obj.Registry=registry;end;function cancel(obj),obj.CancellationRequested=true;end;function resetCancellation(obj),obj.CancellationRequested=false;end;end
end
