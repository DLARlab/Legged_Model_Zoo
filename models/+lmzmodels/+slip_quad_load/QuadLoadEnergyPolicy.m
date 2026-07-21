classdef QuadLoadEnergyPolicy < lmz.multistride.EnergyConsistencyPolicy
    %QUADLOADENERGYPOLICY Source-aware parameter-switch energy accounting.
    methods
        function obj=QuadLoadEnergyPolicy(varargin)
            obj@lmz.multistride.EnergyConsistencyPolicy(varargin{:});
        end

        function value=mechanicalEnergy(~,state,specification)
            state=validateState(state);[physical,controls]=parts(specification);
            effective=effectivePhysical(physical);post=effectivePost(controls);
            quadVelocity=state([2 4]);pitchRate=state(6);
            legAngles=state([7 9 11 13]);legRates=state([8 10 12 14]);
            loadVelocity=state(16);quadX=state(1);quadY=state(3);
            loadX=state(15);loadY=state(17);
            distance=hypot(quadX-loadX,quadY-loadY);
            ropeExtension=max(0,distance-effective.Load(4));
            kinetic=.5*sum(quadVelocity.^2)+ ...
                .5*effective.Quadruped(2)*pitchRate^2+ ...
                .5*effective.Quadruped(3)^2*sum(legRates.^2)+ ...
                .5*effective.Load(2)*loadVelocity^2;
            swing=.5*sum(post.*(legAngles.^2));
            rope=.5*effective.Load(5)*ropeExtension^2;
            slope=effective.Load(6);
            gravity=cos(slope)*quadY-sin(slope)*quadX- ...
                effective.Load(2)*sin(slope)*loadX;
            value=kinetic+swing+rope+gravity;
        end

        function [delta,details]=parameterTransitionEnergy(~,state,before,after)
            state=validateState(state);[~,beforeControls]=parts(before);
            [~,afterControls]=parts(after);
            beforePost=effectivePost(beforeControls);
            afterPost=effectivePost(afterControls);
            angles=state([7 9 11 13]);
            perLeg=.5*(afterPost-beforePost).*(angles.^2);
            delta=sum(perLeg);
            details=struct('Convention', ...
                'swing potential 0.5*abs(k)*alpha^2 at parameter activation', ...
                'RawBefore',beforeControls.PostSwingStiffness(:), ...
                'RawAfter',afterControls.PostSwingStiffness(:), ...
                'EffectiveBefore',beforePost,'EffectiveAfter',afterPost, ...
                'LegAngles',angles,'PerLegDelta',perLeg,'EnergyDelta',delta);
        end

        function value=declaredExternalWork(obj,transitionSpec)
            value=declaredExternalWork@ ...
                lmz.multistride.EnergyConsistencyPolicy(obj,transitionSpec);
        end

        function diagnostics=validateTransition(obj,state,before,after,transitionSpec)
            if nargin<5||isempty(transitionSpec),transitionSpec=0;end
            [beforePhysical,beforeControls]=parts(before);
            [afterPhysical,afterControls]=parts(after);
            transitionPolicy=lmz.multistride.ParameterTransitionPolicy();
            parameterDiagnostics=transitionPolicy.validate( ...
                beforePhysical,afterPhysical);
            validateControlFields(beforeControls);validateControlFields(afterControls);
            [delta,details]=obj.parameterTransitionEnergy(state,before,after);
            declaredWork=obj.declaredExternalWork(transitionSpec);
            acceptance=obj.assess(delta,declaredWork,true);
            diagnostics=acceptance;diagnostics.ParameterTransition=parameterDiagnostics;
            diagnostics.EnergyModel=details;
            diagnostics.EffectivePhysicalBefore=effectivePhysical(beforePhysical);
            diagnostics.EffectivePhysicalAfter=effectivePhysical(afterPhysical);
        end
    end
end

function state=validateState(source)
if ~isnumeric(source)||~isreal(source)||numel(source)~=18|| ...
        any(~isfinite(source(:)))
    error('lmz:QuadLoad:EnergyState', ...
        'Energy evaluation requires one finite 18-entry physical state.');
end
state=source(:);
end
function [physical,controls]=parts(source)
if isa(source,'lmz.multistride.StrideSpec')
    physical=source.PhysicalParameters;controls=source.ControlParameters;
elseif isstruct(source)&&all(isfield(source,{'PhysicalParameters','ControlParameters'}))
    physical=source.PhysicalParameters;controls=source.ControlParameters;
else
    error('lmz:QuadLoad:EnergySpecification', ...
        'Energy evaluation requires physical and control parameters.');
end
if ~isstruct(physical)||~isstruct(controls)
    error('lmz:QuadLoad:EnergySpecification', ...
        'Energy parameter groups must be named structs.');
end
end
function value=effectivePhysical(source)
if ~all(isfield(source,{'QuadrupedInvariantVector','LoadVector'}))
    error('lmz:QuadLoad:EnergyPhysical', ...
        'Quad-load physical parameters are incomplete.');
end
quadruped=abs(source.QuadrupedInvariantVector(:));load=source.LoadVector(:);
if numel(quadruped)~=6||numel(load)~=6||any(~isfinite([quadruped;load]))
    error('lmz:QuadLoad:EnergyPhysical', ...
        'Quad-load physical parameter dimensions are invalid.');
end
quadruped(5)=min(.9,max(.1,quadruped(5)));
value=struct('Quadruped',quadruped,'Load',load, ...
    'QuadrupedUsesAbsoluteValue',true,'BackAttachmentClamped',true);
end
function value=effectivePost(source)
if ~isfield(source,'PostSwingStiffness')
    error('lmz:QuadLoad:EnergyControls','Post-swing stiffness is missing.');
end
value=abs(source.PostSwingStiffness(:));
if numel(value)~=4||any(~isfinite(value))
    error('lmz:QuadLoad:EnergyControls', ...
        'Post-swing stiffness must contain four finite values.');
end
end
function validateControlFields(source)
allowed={'PreSwingStiffness','PostSwingStiffness'};names=fieldnames(source);
if ~all(ismember(names,allowed))||~all(isfield(source,allowed))
    error('lmz:MultiStride:UnknownEnergyEffect', ...
        'Unknown quad-load controls have no declared energy model.');
end
end
