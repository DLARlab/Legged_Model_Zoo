classdef LaterStrideLayout
    %LATERSTRIDELAYOUT Exact 13-value addition for every later stride.
    properties (Constant)
        Length = 13
    end
    methods (Static)
        function value = baseNames()
            value={'tBL_TD','tBL_LO','tFL_TD','tFL_LO', ...
                'tBR_TD','tBR_LO','tFR_TD','tFR_LO','tAPEX', ...
                'swing_post_BL','swing_post_FL','swing_post_BR','swing_post_FR'};
        end
        function value = names(strideIndex)
            if nargin<1,strideIndex=2;end
            if ~isscalar(strideIndex)||strideIndex<2||strideIndex~=fix(strideIndex)
                error('lmz:QuadLoad:StrideIndex','Later-stride index must be an integer of at least two.');
            end
            base=lmzmodels.slip_quad_load.LaterStrideLayout.baseNames();value=cell(size(base));
            for index=1:numel(base),value{index}=sprintf('stride%d_%s',strideIndex,base{index});end
        end
        function value = globalIndices(strideIndex)
            if ~isscalar(strideIndex)||strideIndex<2||strideIndex~=fix(strideIndex)
                error('lmz:QuadLoad:StrideIndex', ...
                    'Later-stride index must be an integer of at least two.');
            end
            startIndex=lmzmodels.slip_quad_load.FirstStrideLayout.Length+1+ ...
                lmzmodels.slip_quad_load.LaterStrideLayout.Length*(strideIndex-2);
            block=startIndex:startIndex+lmzmodels.slip_quad_load.LaterStrideLayout.Length-1;
            value=struct('Block',block,'EventTiming',block(1:9), ...
                'PostSwingStiffness',block(10:13));
        end
        function validate(vector)
            if ~isnumeric(vector)||~isreal(vector)||numel(vector)~=13||any(~isfinite(vector(:)))
                error('lmz:QuadLoad:LaterStrideLayout', ...
                    'Each later-stride block must contain 13 finite real values.');
            end
        end
        function value = decode(vector,strideIndex)
            if nargin<2,strideIndex=2;end
            lmzmodels.slip_quad_load.LaterStrideLayout.validate(vector);vector=vector(:);
            names=lmzmodels.slip_quad_load.LaterStrideLayout.names(strideIndex);
            value=struct('StrideIndex',strideIndex,'Vector',vector, ...
                'Named',cell2struct(num2cell(vector),names(:),1), ...
                'EventTiming',vector(1:9),'PostSwingStiffness',vector(10:13));
        end
        function vector = encode(value)
            if isnumeric(value),vector=value(:);
            elseif isstruct(value)&&isfield(value,'Vector'),vector=value.Vector(:);
            elseif isstruct(value)&&all(isfield(value,{'EventTiming','PostSwingStiffness'}))
                vector=[value.EventTiming(:);value.PostSwingStiffness(:)];
            else,error('lmz:QuadLoad:LaterStrideEncode','Unsupported later-stride value.');end
            lmzmodels.slip_quad_load.LaterStrideLayout.validate(vector);
        end
    end
end
