classdef XAccumPlanAdapter
    %XACCUMPLANADAPTER Exact bridge between X_accum and native StridePlan.
    methods (Static)
        function plan=decode(vector,varargin)
            plan=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan( ...
                vector,varargin{:});
        end

        function plan=toPlan(vector,varargin)
            parser=inputParser;
            addParameter(parser,'ProblemId','n_stride_simulation',@isTextScalar);
            addParameter(parser,'StartSectionId','apex',@isIdentifier);
            addParameter(parser,'StopSectionId','apex',@isIdentifier);
            addParameter(parser,'CompletionPolicy','error_if_missing');
            addParameter(parser,'EnergyPolicy', ...
                lmz.multistride.EnergyConsistencyPolicy());
            parse(parser,varargin{:});options=parser.Results;
            decoded=lmzmodels.slip_quad_load.XAccumAdapter.decode(vector);
            first=decoded.FirstStride;indices= ...
                lmzmodels.slip_quad_load.FirstStrideLayout.indices();
            invariant=first.Vector(indices.TransitionInvariantParameters);
            physical=physicalStruct(invariant);
            initialState=[0;first.QuadrupedState(:);first.LoadState(:); ...
                first.LoadParameters(1);0];
            specs=lmz.multistride.StrideSpec.empty(0,1);
            controls=struct('PreSwingStiffness', ...
                first.Vector(indices.PreSwingStiffness), ...
                'PostSwingStiffness',first.Vector(indices.PostSwingStiffness));
            specs(1,1)=makeSpec(1,first.EventTiming,physical,controls, ...
                options,'legacy_first_stride');
            previousPost=controls.PostSwingStiffness;
            for stride=2:decoded.StrideCount
                later=decoded.LaterStrides(stride-1);
                controls=struct('PreSwingStiffness',previousPost(:), ...
                    'PostSwingStiffness',later.PostSwingStiffness(:));
                specs(stride,1)=makeSpec(stride,later.EventTiming,physical, ...
                    controls,options,'legacy_later_block');
                previousPost=controls.PostSwingStiffness;
            end
            provenance=struct('SchemaVersion','1.0.0', ...
                'LegacyCodec','slip_quad_load.X_accum', ...
                'LegacyLayout','44+13*(N-1)', ...
                'ImportedStrideCount',decoded.StrideCount);
            plan=lmz.multistride.StridePlan('ModelId','slip_quad_load', ...
                'ProblemId',char(options.ProblemId), ...
                'RequestedStrideCount',decoded.StrideCount, ...
                'CompletedStrideCount',decoded.StrideCount, ...
                'InitialState',initialState, ...
                'DefaultPhysicalParameters',physical,'StrideSpecs',specs, ...
                'CompletionPolicy',options.CompletionPolicy, ...
                'EnergyPolicy',options.EnergyPolicy,'Provenance',provenance);
        end

        function vector=encode(plan)
            if ~isa(plan,'lmz.multistride.StridePlan')|| ...
                    ~strcmp(plan.ModelId,'slip_quad_load')
                error('lmz:QuadLoad:XAccumPlan', ...
                    'A slip_quad_load StridePlan is required.');
            end
            lmz.multistride.StridePlanValidator.validate(plan,true);
            if numel(plan.InitialState)~=18
                error('lmz:QuadLoad:PlanInitialState', ...
                    'Quad-load plan initial state must contain 18 values.');
            end
            physical=plan.DefaultPhysicalParameters;
            invariant=invariantVector(physical);
            firstSpec=plan.StrideSpecs(1);firstSchedule=scheduleTimes( ...
                firstSpec.EventSchedule);
            firstControls=validateControls(firstSpec.ControlParameters);
            indices=lmzmodels.slip_quad_load.FirstStrideLayout.indices();
            first=zeros(lmzmodels.slip_quad_load.FirstStrideLayout.Length,1);
            state=plan.InitialState(:);first(indices.QuadrupedState)=state(2:14);
            first(indices.EventTiming)=firstSchedule;
            first(indices.TransitionInvariantParameters)=invariant;
            first(indices.PreSwingStiffness)=firstControls.PreSwingStiffness;
            first(indices.PostSwingStiffness)=firstControls.PostSwingStiffness;
            first(indices.LoadState)=[state(15)-state(1);state(16)];
            vector=lmzmodels.slip_quad_load.FirstStrideLayout.encode(first);
            for stride=2:plan.CompletedStrideCount
                spec=plan.StrideSpecs(stride);
                controls=validateControls(spec.ControlParameters);
                block=struct('EventTiming',scheduleTimes(spec.EventSchedule), ...
                    'PostSwingStiffness',controls.PostSwingStiffness);
                vector=[vector; ...
                    lmzmodels.slip_quad_load.LaterStrideLayout.encode(block)]; %#ok<AGROW>
            end
            vector=lmzmodels.slip_quad_load.XAccumAdapter.encode(vector);
        end

        function vector=toXAccum(plan)
            vector=lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(plan);
        end

        function [value,diagnostics]=truncate(vector,count)
            plan=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan(vector);
            original=plan.CompletedStrideCount;plan=plan.truncate(count);
            value=lmzmodels.slip_quad_load.XAccumPlanAdapter.encode(plan);
            diagnostics=struct('OriginalStrideCount',original, ...
                'RetainedStrideCount',count,'OriginalLength',numel(vector), ...
                'RetainedLength',numel(value),'ExplicitTruncation',true);
        end
    end
end

function value=physicalStruct(invariant)
invariant=invariant(:);
value=struct('TransitionInvariantIndices',[23 32:36 39:44], ...
    'TransitionInvariantVector',invariant, ...
    'QuadrupedInvariantVector',invariant(1:6), ...
    'LoadVector',invariant(7:12));
end
function value=invariantVector(physical)
if ~isstruct(physical)||~isfield(physical,'TransitionInvariantVector')
    error('lmz:QuadLoad:PlanPhysicalParameters', ...
        'Plan physical parameters lack TransitionInvariantVector.');
end
value=physical.TransitionInvariantVector(:);
if numel(value)~=12||any(~isfinite(value))
    error('lmz:QuadLoad:PlanPhysicalParameters', ...
        'Transition-invariant parameter vector must contain 12 finite values.');
end
end
function spec=makeSpec(index,times,physical,controls,options,source)
spec=lmz.multistride.StrideSpec('Index',index, ...
    'StartSectionId',char(options.StartSectionId), ...
    'StopSectionId',char(options.StopSectionId), ...
    'StartStateSide','post','StopStateSide','pre', ...
    'EventSchedule',scheduleStruct(times), ...
    'PhysicalParameters',physical,'ControlParameters',controls, ...
    'InitialStateSource',source,'CompletionStatus','supplied', ...
    'Diagnostics',struct('LegacyBlockIndex',index), ...
    'Lineage',struct('Source','X_accum','StrideIndex',index));
end
function value=scheduleStruct(times)
names=lmzmodels.slip_quad_load.LaterStrideLayout.baseNames();times=times(:);
[~,order]=sort(times);
value=struct();value.Names=names(:);value.Times=times;
value.ReturnTime=times(9);value.OccurrenceOrder=names(order).';
value.Chart='legacy_named_cyclic';value.MinimumGap=0;
end
function value=scheduleTimes(schedule)
if ~isstruct(schedule)||~isfield(schedule,'Times')
    error('lmz:QuadLoad:PlanSchedule','Stride schedule lacks named times.');
end
value=schedule.Times(:);
if numel(value)~=9||any(~isfinite(value))
    error('lmz:QuadLoad:PlanSchedule', ...
        'Quad-load stride schedule must contain nine finite times.');
end
end
function value=validateControls(source)
required={'PreSwingStiffness','PostSwingStiffness'};
if ~isstruct(source)||~all(isfield(source,required))
    error('lmz:QuadLoad:PlanControls','Stride controls are incomplete.');
end
value=source;value.PreSwingStiffness=value.PreSwingStiffness(:);
value.PostSwingStiffness=value.PostSwingStiffness(:);
if numel(value.PreSwingStiffness)~=4|| ...
        numel(value.PostSwingStiffness)~=4|| ...
        any(~isfinite([value.PreSwingStiffness;value.PostSwingStiffness]))
    error('lmz:QuadLoad:PlanControls', ...
        'Pre/post swing controls must contain four finite values each.');
end
end
function value=isTextScalar(source)
value=ischar(source)||(isstring(source)&&isscalar(source));
end
function value=isIdentifier(source)
value=isTextScalar(source)&&~isempty(regexp(char(source), ...
    '^[A-Za-z][A-Za-z0-9_]*$','once'));
end
