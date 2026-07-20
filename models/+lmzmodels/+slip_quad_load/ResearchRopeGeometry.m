classdef ResearchRopeGeometry
    %RESEARCHROPEGEOMETRY Source four-point zero-area tugline patch path.
    methods (Static)
        function geometry=compute(quadrupedCenter,loadCenter)
            quadrupedCenter=validatePoint(quadrupedCenter,'quadruped center');
            loadCenter=validatePoint(loadCenter,'load center');
            vertices=[quadrupedCenter;quadrupedCenter;loadCenter;loadCenter];
            metadata=lmzmodels.slip_quad_load.ResearchRopeGeometry.provenance();
            metadata.startFrame='quadruped_center_of_mass';
            metadata.endFrame='load_center';metadata.styleKey='rope';
            metadata.startPoint=quadrupedCenter;metadata.endPoint=loadCenter;
            geometry=lmz.viz.PatchGeometry('quadLoadRope',vertices,1:4,metadata);
        end

        function value=provenance()
            value=struct( ...
                'sourceRepository','DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights', ...
                'sourceCommit','19f3133073c988cc0c3424a647b4adbb60a90b99', ...
                'sourcePath','Stored_Functions/Graphics/SLIP_Animation_Quad_Load.m', ...
                'sourceFunction','DrawRopeLoad_and_SetRopeLoad', ...
                'sourceLines','291-294 and 372-374', ...
                'adaptation',['The duplicate-endpoint XData/YData path is retained ', ...
                    'as a zero-area PatchGeometry rather than simplified to a line.'], ...
                'numericConstants',struct('pointCount',4,'duplicateEndpoints',true));
        end
    end
end

function value=validatePoint(value,description)
if ~isnumeric(value)||~isreal(value)||numel(value)~=2||any(~isfinite(value(:)))
    error('lmz:slip_quad_load:ResearchPoint', ...
        '%s must contain two finite real coordinates.',description);
end
value=reshape(value,1,2);
end
