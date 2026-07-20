classdef ResearchBodyGeometry
    %RESEARCHBODYGEOMETRY Source-faithful circular biped body geometry.
    methods (Static)
        function geometry=compute(x,y)
            if nargin==1
                center=x;
                if ~isnumeric(center)||numel(center)~=2
                    error('lmz:slip_biped:BodyGeometry', ...
                        'Body center must contain finite x and y coordinates.');
                end
                x=center(1);y=center(2);
            end
            if ~isnumeric(x)||~isscalar(x)||~isfinite(x)|| ...
                    ~isnumeric(y)||~isscalar(y)||~isfinite(y)
                error('lmz:slip_biped:BodyGeometry', ...
                    'Body center must contain finite x and y coordinates.');
            end
            angle=linspace(0,2*pi,40);
            vertices=[x+0.2*sin(angle(:)),y+0.2*cos(angle(:))];
            metadata=lmzmodels.slip_biped.ResearchBodyGeometry.provenance();
            metadata.radius=0.2;metadata.vertexCount=40;
            geometry=lmz.viz.PatchGeometry('bipedBody',vertices,1:40,metadata);
        end

        function value=provenance()
            value=struct( ...
                'sourceRepository','DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions', ...
                'sourceCommit','4595146c5881a5313bc8fe92de85099193ef9be9', ...
                'sourcePath','Stored_Functions/Graphics/DrawBody.m', ...
                'sourceFunction','DrawBody_and_SetDrawBody', ...
                'sourceLines','DrawBody:42-48; SetDrawBody:4-9', ...
                'adaptation','Pure numeric post-update vertices; no graphics handles.');
        end
    end
end
