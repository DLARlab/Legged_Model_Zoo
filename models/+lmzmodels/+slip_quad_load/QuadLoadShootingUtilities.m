classdef QuadLoadShootingUtilities
    %QUADLOADSHOOTINGUTILITIES Named conversions for load shooting segments.
    methods (Static)
        function value=coordinateNames(sectionId)
            if nargin<1||isempty(sectionId),sectionId='apex';end
            switch sectionId
                case 'apex'
                    value={'quad_dx','quad_y','quad_phi','quad_dphi', ...
                        'alphaBL','dalphaBL','alphaFL','dalphaFL', ...
                        'alphaBR','dalphaBR','alphaFR','dalphaFR', ...
                        'load_x','load_dx'};
                case 'stride_boundary'
                    value={'quad_dx','quad_y','quad_dy', ...
                        'quad_phi','quad_dphi','alphaBL','dalphaBL', ...
                        'alphaFL','dalphaFL','alphaBR','dalphaBR', ...
                        'alphaFR','dalphaFR','load_x','load_dx'};
                otherwise
                    error('lmz:QuadLoad:ShootingSection', ...
                        'Unsupported quad-load shooting section %s.', ...
                        sectionId);
            end
        end

        function value=sectionStateSchema(sectionId)
            if nargin<1,sectionId='apex';end
            value=lmz.shooting.SectionStateSchema( ...
                lmzmodels.slip_quad_load.PhysicalStateSchema.create(), ...
                lmzmodels.slip_quad_load.QuadLoadShootingUtilities. ...
                coordinateNames(sectionId));
        end

        function [value,translation]=localState(state)
            schema=lmzmodels.slip_quad_load.PhysicalStateSchema.create();
            schema.validateVector(state);value=state(:);translation=value(1);
            value(1)=0;value(15)=value(15)-translation;
        end

        function value=eventSchedule(source)
            if isa(source,'lmz.schedule.EventSchedule')
                value=source;return
            end
            if ~isstruct(source)||~isfield(source,'Times')|| ...
                    numel(source.Times)~=9
                error('lmz:QuadLoad:ShootingSchedule', ...
                    'A quad-load shooting schedule requires nine event times.');
            end
            names=lmzmodels.slip_quad_load.ContactConstraintProvider().eventNames();
            times=source.Times(:);
            value=lmz.schedule.EventSchedule.fromCyclic(names,times(1:8), ...
                times(9),'MinimumGap',max(1e-12,fieldOr(source, ...
                'MinimumGap',0)),'StartSectionId',fieldOr(source, ...
                'StartSectionId','apex'),'StopSectionId',fieldOr(source, ...
                'StopSectionId','apex'));
        end

        function value=scheduleVector(schedule)
            schedule=lmzmodels.slip_quad_load.QuadLoadShootingUtilities. ...
                eventSchedule(schedule);
            names=lmzmodels.slip_quad_load.ContactConstraintProvider().eventNames();
            value=[schedule.namedTimes(names);schedule.ReturnTime];
        end

        function value=vector(state,schedule,physical,postControls,preControls)
            [state,~]=lmzmodels.slip_quad_load.QuadLoadShootingUtilities. ...
                localState(state);
            schedule=lmzmodels.slip_quad_load.QuadLoadShootingUtilities. ...
                scheduleVector(schedule);
            invariant=physical.TransitionInvariantVector(:);
            postControls=postControls(:);preControls=preControls(:);
            if numel(invariant)~=12||numel(postControls)~=4|| ...
                    numel(preControls)~=4|| ...
                    any(~isfinite([invariant;postControls;preControls]))
                error('lmz:QuadLoad:ShootingSegmentData', ...
                    'Quad-load segment physical/control data are invalid.');
            end
            indices=lmzmodels.slip_quad_load.FirstStrideLayout.indices();
            value=zeros(44,1);value(indices.QuadrupedState)=state(2:14);
            value(indices.LoadState)=[state(15);state(16)];
            value(indices.EventTiming)=schedule;
            value(indices.TransitionInvariantParameters)=invariant;
            value(indices.PreSwingStiffness)=preControls;
            value(indices.PostSwingStiffness)=postControls;
            value=lmzmodels.slip_quad_load.FirstStrideLayout.encode(value);
        end

        function value=node(state,index,free,lineage,sectionId)
            if nargin<3,free=true;end
            if nargin<4,lineage=struct();end
            if nargin<5,sectionId='apex';end
            [local,translation]= ...
                lmzmodels.slip_quad_load.QuadLoadShootingUtilities. ...
                localState(state);
            sectionSchema=lmzmodels.slip_quad_load. ...
                QuadLoadShootingUtilities.sectionStateSchema(sectionId);
            mask=repmat(logical(free),sectionSchema.count(),1);
            lineage.NodeIndex=index;
            value=lmz.shooting.ShootingNode('SectionId',sectionId, ...
                'StateSide','post','StateSchema',sectionSchema, ...
                'FullState',local,'WorldTranslation',translation, ...
                'FreeCoordinateMask',mask,'Symmetry', ...
                struct('Id','planar_translation'),'Lineage',lineage);
        end

        function value=energySpecification(mode,declaredWork,scale,tolerance)
            if nargin<1||isempty(mode),mode='energy_neutral';end
            if nargin<2||isempty(declaredWork),declaredWork=0;end
            if nargin<3||isempty(scale),scale=1;end
            if nargin<4||isempty(tolerance),tolerance=1e-8;end
            value=struct('Mode',mode,'DeclaredWork',declaredWork, ...
                'Tolerance',scale,'AcceptanceTolerance',tolerance);
        end

        function value=emptySchema()
            value=lmz.schema.VariableSchema( ...
                lmz.schema.VariableSpec.empty(0,1),'1.0.0');
        end
    end
end

function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
