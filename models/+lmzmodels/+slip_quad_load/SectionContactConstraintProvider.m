classdef SectionContactConstraintProvider < ...
        lmz.schedule.ContactConstraintProvider
    %SECTIONCONTACTCONSTRAINTPROVIDER Direct load section timing rows.
    properties (SetAccess=private)
        Codec
        Adapter
    end

    methods
        function obj=SectionContactConstraintProvider(codec,adapter)
            if ~isa(codec, ...
                    'lmzmodels.slip_quad_load.QuadLoadSectionDecisionCodec')|| ...
                    ~isa(adapter,['lmzmodels.slip_quad_load.' ...
                    'QuadLoadSectionSimulationAdapter'])
                error('lmz:Timing:QuadLoadSectionProvider', ...
                    'Load section timing requires its codec and adapter.');
            end
            obj.Codec=codec;obj.Adapter=adapter;
        end

        function value=eventNames(obj)
            value=obj.Codec.ScheduleAdapter.Chart.Template.names();
        end

        function value=evaluate(obj,initialState,physicalParameters, ...
                schedule,context,includeSimulation)
            if nargin<6,includeSimulation=true;end
            state=initialState(:);
            obj.Codec.StateCoordinates.PhysicalSchema.validateVector(state);
            fixed=physicalParameters(:);
            if ~isequaln(fixed,obj.Codec.BaseStrideVector)
                error('lmz:Timing:QuadLoadSectionFixedData', ...
                    'Load section timing must preserve its fixed stride data.');
            end
            canonicalTimes=NaN(numel(obj.Codec.EventNames),1);
            names=schedule.names();times=schedule.times();
            for index=1:numel(names)
                target=find(strcmp(names{index},obj.Codec.EventNames),1);
                if isempty(target)
                    error('lmz:Timing:QuadLoadSectionSchedule', ...
                        'Section timing schedule contains an unknown event.');
                end
                canonicalTimes(target)=times(index);
            end
            if obj.Codec.EndpointContactIndex>0
                canonicalTimes(obj.Codec.EndpointContactIndex)= ...
                    schedule.ReturnTime;
            end
            if any(~isfinite(canonicalTimes))
                error('lmz:Timing:QuadLoadSectionSchedule', ...
                    'Section timing schedule is missing a contact event.');
            end
            decision=obj.Codec.encode( ...
                state,canonicalTimes,schedule.ReturnTime);
            propagated=obj.Adapter.evaluate( ...
                decision,fixed,context,includeSimulation);
            bindings=localBindings(obj.Codec,schedule);
            value=struct('ContactResidual', ...
                propagated.ContactResiduals(:), ...
                'ContactRowBindings',bindings, ...
                'SectionResidual',propagated.SectionResidual(:), ...
                'TerminalState',propagated.TerminalState(:), ...
                'SectionCrossing',propagated.Crossing, ...
                'Simulation',propagated.Simulation, ...
                'Diagnostics',struct('ModelId','slip_quad_load', ...
                'Formulation','section-local-contact-timing-v1', ...
                'DirectSectionIntegration',true, ...
                'StartSectionId',obj.Codec.StartSection.Id, ...
                'StopSectionId',obj.Codec.StopSection.Id, ...
                'AdapterDiagnostics',propagated.Diagnostics));
        end
    end
end

function value=localBindings(codec,schedule)
value=repmat(struct('Kind','','EventName',''), ...
    numel(codec.EventNames),1);
scheduled=schedule.names();
for index=1:numel(codec.EventNames)
    if index==codec.EndpointContactIndex
        value(index)=struct('Kind','return','EventName','');
    elseif any(strcmp(codec.EventNames{index},scheduled))
        value(index)=struct('Kind','event', ...
            'EventName',codec.EventNames{index});
    else
        value(index)=struct('Kind','always','EventName','');
    end
end
end
