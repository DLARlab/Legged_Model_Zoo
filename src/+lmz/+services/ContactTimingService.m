classdef ContactTimingService
    %CONTACTTIMINGSERVICE Solve explicit schedules without changing fixed data.
    methods
        function result=solve(obj,problem,seed,options,context)
            if nargin<4||isempty(options), options=struct(); end
            if nargin<5||isempty(context), context=lmz.api.RunContext.synchronous(0); end
            if ~isa(problem,'lmz.schedule.SectionReturnTimingProblem')
                error('lmz:Timing:ProblemType', ...
                    'ContactTimingService requires SectionReturnTimingProblem.');
            end
            context.check();
            if problem.unknownDimension()~=problem.residualDimension()
                error('lmz:Timing:DimensionMismatch', ...
                    'Free schedule variable and residual counts must match.');
            end
            if isa(seed,'lmz.schedule.EventSchedule')
                seedVector=problem.decisionFromSchedule(seed);
                inputSchedule=seed;
            elseif isa(seed,'lmz.data.Solution')
                seedVector=seed.DecisionValues;
                inputSchedule=problem.scheduleFromDecision(seedVector);
            else
                seedVector=seed(:);
                inputSchedule=problem.scheduleFromDecision(seedVector);
            end
            fixedState=problem.FixedInitialState;
            fixedParameters=problem.FixedPhysicalParameters;
            optionStruct=obj.optionStruct(options);
            multistart=obj.fieldOr(optionStruct,'MultistartCount',1);
            perturbation=obj.fieldOr(optionStruct,'MultistartScale',0.05);
            if ~isnumeric(multistart)||~isscalar(multistart)||multistart<1|| ...
                    multistart~=floor(multistart)
                error('lmz:Timing:MultistartCount', ...
                    'MultistartCount must be a positive integer.');
            end
            solverOptions=rmfieldIfPresent(optionStruct, ...
                {'MultistartCount','MultistartScale'});
            stream=RandStream('mt19937ar','Seed',context.RandomSeed);
            best=[]; attempts=repmat(struct('Index',0,'ExitFlag',0, ...
                'ResidualNorm',Inf,'Seed',[]),multistart,1);
            for index=1:multistart
                context.check(); trialSeed=seedVector;
                if index>1
                    trialSeed=trialSeed+perturbation*randn(stream,size(trialSeed));
                end
                solved=lmz.solvers.FsolveSolver().solve(problem,trialSeed,[], ...
                    solverOptions,context);
                attempts(index)=struct('Index',index,'ExitFlag',solved.ExitFlag, ...
                    'ResidualNorm',solved.Evaluation.ScaledResidualNorm, ...
                    'Seed',trialSeed);
                if isempty(best)||solved.Evaluation.ScaledResidualNorm< ...
                        best.Evaluation.ScaledResidualNorm
                    best=solved;
                end
            end
            solvedSchedule=problem.scheduleFromDecision(best.Solution.DecisionValues);
            details=problem.evaluateTiming(solvedSchedule,context,true);
            if ~isequaln(fixedState,problem.FixedInitialState)|| ...
                    ~isequaln(fixedParameters,problem.FixedPhysicalParameters)
                error('lmz:Timing:FixedDataMutated', ...
                    'Timing solve changed fixed initial state or physical parameters.');
            end
            descriptor=problem.getDescriptor();
            diagnostics=struct('ExitFlag',best.ExitFlag,'Output',best.Output, ...
                'ResidualNorm',best.Evaluation.ScaledResidualNorm, ...
                'Attempts',attempts,'Options',solverOptions, ...
                'InitialStateBitwiseUnchanged', ...
                isequaln(fixedState,problem.FixedInitialState), ...
                'PhysicalParametersBitwiseUnchanged', ...
                isequaln(fixedParameters,problem.FixedPhysicalParameters), ...
                'NoPeriodicityResidual',true);
            values=struct('ModelId',descriptor.modelId,'ProblemId',problem.Id, ...
                'FixedInitialState',fixedState,'FixedPhysicalParameters',fixedParameters, ...
                'InputSchedule',inputSchedule,'SolvedSchedule',solvedSchedule, ...
                'FreeMask',[solvedSchedule.freeMask();~solvedSchedule.ReturnTimeFixed], ...
                'FixedMask',[solvedSchedule.fixedMask();solvedSchedule.ReturnTimeFixed], ...
                'ContactResiduals',details.ContactResidual(:), ...
                'SectionResidual',details.SectionResidual(:), ...
                'TerminalState',details.TerminalState(:), ...
                'SectionCrossing',details.SectionCrossing, ...
                'Simulation',details.Simulation,'SolverDiagnostics',diagnostics, ...
                'RandomSeed',context.RandomSeed,'Provenance',struct( ...
                'service','ContactTimingService','formulation', ...
                'explicit-fixed-state-fixed-physics-v1'));
            result=lmz.data.ContactTimingResult(values);
            context.progress(1,'Contact timing solve complete.');
        end
    end

    methods (Static, Access=private)
        function value=optionStruct(options)
            if isa(options,'lmz.solvers.SolverOptions')
                value=options.toStruct();
            elseif isstruct(options)&&isscalar(options)
                value=options;
            else
                error('lmz:Timing:SolverOptions', ...
                    'Solver options are invalid.');
            end
        end
        function value=fieldOr(source,name,fallback)
            if isfield(source,name), value=source.(name); else, value=fallback; end
        end
    end
end

function value=rmfieldIfPresent(value,names)
for index=1:numel(names)
    if isfield(value,names{index}), value=rmfield(value,names{index}); end
end
end
