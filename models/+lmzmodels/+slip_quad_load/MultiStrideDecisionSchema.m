classdef MultiStrideDecisionSchema
    %MULTISTRIDEDECISIONSCHEMA Central schema for 44+13*(N-1) X_accum.
    methods (Static)
        function schema = create(strideCount,defaults)
            if nargin<1,strideCount=1;end
            expected=lmzmodels.slip_quad_load.MultiStrideDecisionSchema.expectedLength(strideCount);
            if nargin<2||isempty(defaults),defaults=zeros(expected,1);end
            defaults=defaults(:);
            if numel(defaults)~=expected||any(~isfinite(defaults))
                error('lmz:QuadLoad:SchemaDefaults','Schema defaults do not match the stride count.');
            end
            names=lmzmodels.slip_quad_load.FirstStrideLayout.names();
            groups=[repmat({'first_stride_state'},1,13), ...
                repmat({'first_stride_events'},1,9), ...
                repmat({'quadruped_parameters'},1,14), ...
                repmat({'first_stride_load_state'},1,2), ...
                repmat({'load_parameters'},1,6)];
            for stride=2:strideCount
                names=[names,lmzmodels.slip_quad_load.LaterStrideLayout.names(stride)]; %#ok<AGROW>
                groups=[groups,repmat({sprintf('stride_%d_events',stride)},1,9), ...
                    repmat({sprintf('stride_%d_post_swing',stride)},1,4)]; %#ok<AGROW>
            end
            specs=lmz.schema.VariableSpec.empty(0,1);
            for index=1:numel(names)
                scale=max(1,abs(defaults(index)));
                [role,energyEffect]= ...
                    lmzmodels.slip_quad_load.MultiStrideDecisionSchema.metadataFor( ...
                    names{index},groups{index});
                specs(index,1)=lmz.schema.VariableSpec(names{index}, ...
                    'Label',strrep(names{index},'_',' '),'Group',groups{index}, ...
                    'DefaultValue',defaults(index),'Scale',scale, ...
                    'Unit',lmzmodels.slip_quad_load.MultiStrideDecisionSchema.unitFor(names{index}), ...
                    'Role',role,'EnergyEffect',energyEffect); %#ok<AGROW>
            end
            schema=lmz.schema.VariableSchema(specs,'1.0.0');
        end
        function count = strideCount(vectorOrLength)
            if isnumeric(vectorOrLength)&&isscalar(vectorOrLength)&& ...
                    vectorOrLength==fix(vectorOrLength)&&vectorOrLength>=44
                count=(vectorOrLength-44)/13+1;
            else
                count=(numel(vectorOrLength)-44)/13+1;
            end
            if ~isfinite(count)||count<1||count~=fix(count)
                error('lmz:QuadLoad:XAccumLength', ...
                    'X_accum length must be 44+13*(N-1).');
            end
        end
        function lengthValue = expectedLength(strideCount)
            if ~isscalar(strideCount)||strideCount<1||strideCount~=fix(strideCount)
                error('lmz:QuadLoad:StrideCount','Stride count must be a positive integer.');
            end
            lengthValue=44+13*(strideCount-1);
        end
    end
    methods (Static, Access=private)
        function [role,energyEffect] = metadataFor(name,group)
            if contains(group,'events')
                role='schedule';energyEffect='invariant';
            elseif contains(group,'post_swing')
                role='control';energyEffect='state_dependent';
            elseif strcmp(group,'quadruped_parameters')
                if startsWith(name,'swing_pre_')||startsWith(name,'swing_post_')
                    role='control';
                else
                    role='physical';
                end
                energyEffect='state_dependent';
            elseif strcmp(group,'load_parameters')
                role='physical';energyEffect='state_dependent';
            else
                role='physical';energyEffect='unknown';
            end
        end

        function unit = unitFor(name)
            if ~isempty(regexp(name,'(^|_)t(BL|FL|BR|FR)_(TD|LO)$|tAPEX$','once'))
                unit='sqrt(l0/g)';
            elseif ~isempty(strfind(name,'phi'))||~isempty(strfind(name,'alpha'))|| ...
                    ~isempty(strfind(name,'angle'))
                unit='rad';
            elseif ~isempty(strfind(name,'stiffness'))
                unit='normalized stiffness';
            else
                unit='normalized';
            end
        end
    end
end
