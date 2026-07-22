classdef SolveProgress < handle
    %SOLVEPROGRESS Ordered solve lifecycle events and typed snapshots.
    properties (SetAccess=private)
        Events = {}
        Snapshots = lmz.data.SolveIterationSnapshot.empty(0,1)
        CurrentStage = ''
        Completed = false
        TerminationReason = ''
    end

    methods
        function record(obj,eventName,snapshot)
            eventName=lmz.solvers.SolveCallbacks.validateEvent(eventName);
            if ~isa(snapshot,'lmz.data.SolveIterationSnapshot')|| ...
                    ~isscalar(snapshot)
                error('lmz:Data:SolveProgressSnapshot', ...
                    'Solve progress requires one typed snapshot.');
            end
            obj.Events{end+1,1}=eventName;
            obj.Snapshots(end+1,1)=snapshot;
            obj.CurrentStage=eventName;
            if any(strcmp(eventName,{'solve_completed','solve_failed', ...
                    'controlled_stop'}))
                obj.Completed=true;obj.TerminationReason=eventName;
            end
        end

        function value=count(obj)
            value=numel(obj.Events);
        end

        function value=toStruct(obj)
            snapshots=cell(numel(obj.Snapshots),1);
            for index=1:numel(obj.Snapshots)
                snapshots{index}=obj.Snapshots(index).toStruct();
            end
            value=struct('Events',{reshape(obj.Events,[],1)}, ...
                'Snapshots',{snapshots},'CurrentStage',obj.CurrentStage, ...
                'Completed',obj.Completed, ...
                'TerminationReason',obj.TerminationReason);
        end
    end
end
