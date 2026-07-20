classdef ResearchLoadGeometry
    %RESEARCHLOADGEOMETRY Pure source-faithful sled/load patch geometry.
    methods (Static)
        function geometry=compute(loadCenter)
            loadCenter=validatePoint(loadCenter,'load center');
            x=loadCenter(1);halfExtent=loadCenter(2);
            vertices=[x-halfExtent,0; x+halfExtent,0; ...
                x+halfExtent,2*halfExtent; x-halfExtent,2*halfExtent];
            metadata=lmzmodels.slip_quad_load.ResearchLoadGeometry.provenance();
            metadata.center=loadCenter;metadata.halfWidth=halfExtent;
            metadata.halfHeight=halfExtent;metadata.styleKey='load';
            geometry=lmz.viz.PatchGeometry('quadLoadBody',vertices,1:4,metadata);
        end

        function value=provenance()
            value=struct( ...
                'sourceRepository','DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights', ...
                'sourceCommit','19f3133073c988cc0c3424a647b4adbb60a90b99', ...
                'sourcePath','Stored_Functions/Graphics/ComputeLoadGraphics.m', ...
                'sourceFunction','ComputeLoadGraphics', ...
                'sourceLines','4-15', ...
                'adaptation',['The source uses load_y as both half-width and ', ...
                    'half-height. Vertices are returned without creating handles.'], ...
                'numericConstants',struct('widthScale',1,'heightScale',1));
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
