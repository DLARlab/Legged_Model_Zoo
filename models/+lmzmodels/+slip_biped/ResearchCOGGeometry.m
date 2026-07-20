classdef ResearchCOGGeometry
    %RESEARCHCOGGEOMETRY Source-faithful quartered center-of-gravity symbol.
    methods (Static)
        function geometry=compute(x,y)
            if nargin==1
                center=x;
                if ~isnumeric(center)||numel(center)~=2
                    error('lmz:slip_biped:COGGeometry', ...
                        'COG center must contain finite x and y coordinates.');
                end
                x=center(1);y=center(2);
            end
            if ~isnumeric(x)||~isscalar(x)||~isfinite(x)|| ...
                    ~isnumeric(y)||~isscalar(y)||~isfinite(y)
                error('lmz:slip_biped:COGGeometry', ...
                    'COG center must contain finite x and y coordinates.');
            end
            phi=linspace(0,pi/2,10);
            horizontal=[0,0.1*sin(phi),0];
            vertical=[0,0.1*cos(phi),0];
            xData=[horizontal;horizontal;-horizontal;-horizontal].'+x;
            yData=[vertical;-vertical;-vertical;vertical].'+y;
            vertices=[xData(:),yData(:)];
            count=size(xData,1);faces=zeros(4,count);
            for quadrant=1:4
                faces(quadrant,:)=(quadrant-1)*count+(1:count);
            end
            metadata=lmzmodels.slip_biped.ResearchCOGGeometry.provenance();
            metadata.radius=0.1;
            metadata.faceColors=[1 1 1;0 0 0;1 1 1;0 0 0];
            geometry=lmz.viz.PatchGeometry('bipedCOG',vertices,faces,metadata);
        end

        function value=provenance()
            value=struct( ...
                'sourceRepository','DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions', ...
                'sourceCommit','4595146c5881a5313bc8fe92de85099193ef9be9', ...
                'sourcePath','Stored_Functions/Graphics/SLIP_Model_Graphics_PointFeet_BipedalDemo.m', ...
                'sourceFunction','constructor_and_update_COGPatch', ...
                'sourceLines','118-124 and 180-186', ...
                'adaptation','Four source quadrant columns flattened into four explicit faces.');
        end
    end
end
