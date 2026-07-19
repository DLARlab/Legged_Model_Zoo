classdef AppState < handle
    %APPSTATE Mutable presentation state, independent of UI widgets.
    properties
        ModelId = ''
        ProblemId = ''
        ExampleId = 'default_stride'
        Simulation = []
        Status = 'Ready'
    end
end
