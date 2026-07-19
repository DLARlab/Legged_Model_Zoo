classdef (Abstract) Renderer < handle
    methods (Abstract),initialize(obj,axesHandle,model,visualSpec,firstFrame);update(obj,frame);reset(obj);destroy(obj);end
end
