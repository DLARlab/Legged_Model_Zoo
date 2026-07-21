classdef ContactConstraintProvider < lmz.schedule.ContactConstraintProvider
    %CONTACTCONSTRAINTPROVIDER Exact one-stride load contact/apex rows.
    methods
        function value=eventNames(~)
            value={'BL_TD','BL_LO','FL_TD','FL_LO', ...
                'BR_TD','BR_LO','FR_TD','FR_LO'};
        end
        function value=evaluate(obj,initialState,physicalParameters, ...
                schedule,context,includeSimulation)
            if nargin<6,includeSimulation=true;end
            initial=initialState(:);parameters=physicalParameters(:);
            if numel(initial)~=15||numel(parameters)~=20
                error('lmz:Timing:QuadLoadFixedData', ...
                    ['Load timing requires 15 fixed state values and 20 ' ...
                    'fixed physical/control parameter values.']);
            end
            indices=lmzmodels.slip_quad_load.FirstStrideLayout.indices();
            vector=zeros(44,1);
            vector(indices.QuadrupedState)=initial(1:13);
            vector(indices.LoadState)=initial(14:15);
            vector(indices.EventTiming)=[schedule.namedTimes(obj.eventNames()); ...
                schedule.ReturnTime];
            vector(indices.QuadrupedParameters)=parameters(1:14);
            vector(indices.LoadParameters)=parameters(15:20);
            raw=lmzmodels.slip_quad_load.LegacyQuadLoadEvaluator().evaluateStride( ...
                vector,context,false);
            simulation=[];
            simulationValid=size(raw.States,2)==18&& ...
                size(raw.States,1)==numel(raw.Time)&& ...
                all(isfinite(raw.States(:)));
            if includeSimulation&&simulationValid
                simulation=lmzmodels.slip_quad_load.MultiStrideSimulator().run( ...
                    vector,context,struct('EnforceEventTiming',false));
            end
            crossing=lmz.schedule.ContactConstraintProvider.sectionCrossing( ...
                raw,'APEX',4,'post');
            value=struct('ContactResidual',raw.Residual(1:8), ...
                'SectionResidual',raw.Residual(9), ...
                'TerminalState',raw.States(end,:).', ...
                'SectionCrossing',crossing,'Simulation',simulation, ...
                'Diagnostics',struct('ModelId','slip_quad_load', ...
                'ResidualRows',1:9,'PeriodicityRowsIncluded',false, ...
                'HiddenEventTimeSolve',false,'SimulationValid',simulationValid, ...
                'FirstStrideVector',vector));
        end
    end
    methods (Static)
        function problem=createProblem(model,configuration)
            if nargin<2,configuration=struct();end
            if isfield(configuration,'InitialDecision')
                vector=configuration.InitialDecision(:);
                if numel(vector)>44,vector=vector(1:44);end
            else
                catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
                dataset=lmzmodels.slip_quad_load.XAccumAdapter.loadDataset( ...
                    catalog.defaultSinglePath());
                vector=dataset.XAccum(1:44);
            end
            lmzmodels.slip_quad_load.FirstStrideLayout.validate(vector);
            indices=lmzmodels.slip_quad_load.FirstStrideLayout.indices();
            initial=[vector(indices.QuadrupedState);vector(indices.LoadState)];
            parameters=[vector(indices.QuadrupedParameters); ...
                vector(indices.LoadParameters)];
            if isfield(configuration,'InitialState'),initial=configuration.InitialState(:);end
            if isfield(configuration,'PhysicalParameters'),parameters=configuration.PhysicalParameters(:);end
            provider=lmzmodels.slip_quad_load.ContactConstraintProvider();
            schedule=lmz.schedule.ContactConstraintProvider.scheduleFromConfiguration( ...
                provider.eventNames(),vector(14:21),vector(22),configuration);
            lmz.schedule.ContactConstraintProvider. ...
                assertSupportedApexSchedule(schedule,'slip_quad_load');
            problem=lmz.schedule.SectionReturnTimingProblem(model, ...
                'section_return_timing',provider,initial,parameters,schedule,configuration);
        end
    end
end
