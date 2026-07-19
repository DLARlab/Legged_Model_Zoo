classdef MultiStrideSimulator
    %MULTISTRIDESIMULATOR Source-equivalent stride stitching and public output.
    methods
        function result=run(obj,xAccum,context,options)
            if nargin<3||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if nargin<4,options=struct();end
            enforce=fieldOr(options,'EnforceEventTiming',false);
            raw=obj.runRaw(xAccum,context,enforce);
            observables=lmzmodels.slip_quad_load.ObservableProvider.compute(raw);
            decoded=lmzmodels.slip_quad_load.XAccumAdapter.decode(xAccum);
            parameters=struct('stride_count',raw.StrideCount, ...
                'per_stride_parameters',raw.Parameters, ...
                'quadruped',decoded.FirstStride.QuadrupedParameters, ...
                'load',decoded.FirstStride.LoadParameters);
            diagnostics=struct('Evaluator','migrated-Quad_Load_ZeroFun_Transition_v2', ...
                'DuplicateSamplesRemoved',raw.DuplicateSamplesRemoved, ...
                'EventTimingEnforced',logical(enforce),'StrideCount',raw.StrideCount, ...
                'StrideBoundaries',raw.StrideBoundaries,'RawResidual',raw.Residual);
            provenance=struct('sourceRepository', ...
                'https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git', ...
                'sourceCommit','19f3133073c988cc0c3424a647b4adbb60a90b99', ...
                'sourceFile','Stored_Functions/SimulateQuadLoadStrides.m');
            interim=lmz.api.SimulationResult(raw.Time, ...
                lmzmodels.slip_quad_load.PhysicalStateSchema.create(),raw.States, ...
                raw.Modes,observables,parameters,diagnostics,provenance, ...
                'EventRecords',raw.EventRecords, ...
                'GroundReactionForces',raw.GroundReactionForces);
            kinematics=lmzmodels.slip_quad_load.KinematicsProvider.compute(interim);
            result=lmz.api.SimulationResult(interim.Time,interim.StateSchema, ...
                interim.States,interim.Modes,interim.Observables,interim.Parameters, ...
                interim.Diagnostics,interim.Provenance,'EventRecords',interim.EventRecords, ...
                'GroundReactionForces',interim.GroundReactionForces,'Kinematics',kinematics);
        end
        function raw=runRaw(~,xAccum,context,enforceEventTiming)
            if nargin<3||isempty(context),context=lmz.api.RunContext.synchronous(0);end
            if nargin<4,enforceEventTiming=false;end
            xAccum=lmzmodels.slip_quad_load.XAccumAdapter.encode(xAccum);
            decoded=lmzmodels.slip_quad_load.XAccumAdapter.decode(xAccum);
            strideCount=decoded.StrideCount;current=decoded.FirstStride.Vector;trueVector=xAccum;
            firstIndices=lmzmodels.slip_quad_load.FirstStrideLayout.indices();
            residual=[];residual9=[];legacyTime=[];legacyStates=[];legacyGrf=[];legacyTug=[];
            parameterRows=zeros(strideCount,17);allRecords=struct([]);allModes=struct( ...
                'back_left',logical([]),'front_left',logical([]), ...
                'back_right',logical([]),'front_right',logical([]),'stride_index',[]);
            boundaries=repmat(struct('StrideIndex',0,'StartTime',0,'EndTime',0, ...
                'RawStartIndex',0,'RawEndIndex',0),strideCount,1);
            evaluator=lmzmodels.slip_quad_load.LegacyQuadLoadEvaluator();
            for stride=1:strideCount
                context.check();one=evaluator.evaluateStride(current,context,enforceEventTiming);
                offset=0;if ~isempty(legacyTime),offset=legacyTime(end);end
                shifted=one.LegacyTime+offset;rawStart=numel(legacyTime)+1;
                legacyTime=[legacyTime;shifted];legacyStates=[legacyStates;one.LegacyStates]; %#ok<AGROW>
                legacyGrf=[legacyGrf;one.LegacyGroundReactionForces];legacyTug=[legacyTug;one.LegacyTuglineForce]; %#ok<AGROW>
                residual=[residual;one.Residual];residual9=[residual9;one.Residual(1:min(9,numel(one.Residual)))]; %#ok<AGROW>
                parameterRows(stride,:)=one.Parameters;
                modeNames={'back_left','front_left','back_right','front_right'};
                rawModes=lmzmodels.slip_quad_load.LegacyQuadLoadEvaluator.contactModes(one.LegacyTime,one.Schedule);
                for modeIndex=1:4,allModes.(modeNames{modeIndex})=[allModes.(modeNames{modeIndex});rawModes.(modeNames{modeIndex})];end %#ok<AGROW>
                allModes.stride_index=[allModes.stride_index;stride*ones(numel(one.LegacyTime),1)]; %#ok<AGROW>
                records=one.EventRecords;
                for recordIndex=1:numel(records),records(recordIndex).Time=records(recordIndex).Time+offset;records(recordIndex).StrideIndex=stride;end
                if isempty(allRecords),allRecords=records;else,allRecords=[allRecords;records];end %#ok<AGROW>
                boundaries(stride)=struct('StrideIndex',stride,'StartTime',offset, ...
                    'EndTime',shifted(end),'RawStartIndex',rawStart,'RawEndIndex',numel(legacyTime));
                if stride==1
                    trueVector(firstIndices.EventTiming)=one.Parameters(1:9).';
                else
                    laterIndices=lmzmodels.slip_quad_load.LaterStrideLayout.globalIndices(stride);
                    trueVector(laterIndices.EventTiming)=one.Parameters(1:9).';
                end
                if stride<strideCount
                    later=decoded.LaterStrides(stride);next=zeros( ...
                        lmzmodels.slip_quad_load.FirstStrideLayout.Length,1);
                    next(firstIndices.QuadrupedState)=one.LegacyStates(end,2:14).';
                    next(firstIndices.LoadState(1))=one.LegacyStates(end,15)-one.LegacyStates(end,1);
                    next(firstIndices.LoadState(2))=one.LegacyStates(end,16);
                    next(firstIndices.EventTiming)=later.EventTiming;
                    next(firstIndices.PreSwingStiffness)=current(firstIndices.PostSwingStiffness);
                    next(firstIndices.PostSwingStiffness)=later.PostSwingStiffness;
                    carry=firstIndices.TransitionInvariantParameters;
                    next(carry)=xAccum(carry);current=next;
                end
                context.progress(stride/strideCount,sprintf('Simulated load-pulling stride %d of %d.',stride,strideCount));
            end
            [time,keep]=unique(legacyTime,'last');modes=subsetModes(allModes,keep);
            raw=struct('Residual',residual,'FirstNineResiduals',residual9, ...
                'Time',time,'States',legacyStates(keep,:), ...
                'GroundReactionForces',legacyGrf(keep,:), ...
                'TuglineForce',legacyTug(keep,:), ...
                'Modes',modes,'Parameters',parameterRows,'EventRecords',allRecords, ...
                'EventStates',vertcat(allRecords.State),'StrideBoundaries',boundaries, ...
                'StrideCount',strideCount,'XAccumTrue',trueVector, ...
                'LegacyTime',legacyTime,'LegacyStates',legacyStates, ...
                'LegacyGroundReactionForces',legacyGrf,'LegacyTuglineForce',legacyTug, ...
                'DuplicateSamplesRemoved',numel(legacyTime)-numel(time));
        end
    end
end
function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
function value=subsetModes(modes,indices)
value=struct();names=fieldnames(modes);
for index=1:numel(names),item=modes.(names{index});value.(names{index})=item(indices);end
end
