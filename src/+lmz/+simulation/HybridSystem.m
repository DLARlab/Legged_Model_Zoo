classdef (Abstract) HybridSystem < handle
    %HYBRIDSYSTEM Stable extension contract for trusted hybrid model code.
    methods (Abstract)
        value = stateSchema(obj)
        value = initialState(obj, request)
        value = initialMode(obj, request)
        value = mode(obj, modeId)
        value = eventPolicy(obj, request)
        value = resetMap(obj, eventId)
        value = namedOutputs(obj, time, states, modes, eventRecords, request)
    end
end
