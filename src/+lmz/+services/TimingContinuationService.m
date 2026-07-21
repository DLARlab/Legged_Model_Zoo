classdef TimingContinuationService
    %TIMINGCONTINUATIONSERVICE Trace an explicit one-dimensional timing family.
    methods
        function result=run(~,problem,seed,options,context)
            if nargin<4||isempty(options),options=struct();end
            if nargin<5||isempty(context)
                context=lmz.api.RunContext.synchronous(0);
            end
            if ~isa(problem,'lmz.schedule.TimingFamilyProblem')
                error('lmz:Timing:FamilyProblemType', ...
                    'TimingContinuationService requires TimingFamilyProblem.');
            end
            if ~isstruct(options)||~isscalar(options)
                error('lmz:Timing:FamilyOptions', ...
                    'Timing family options must be a scalar struct.');
            end
            context.check();
            [first,pair]=firstAndPair(problem,seed,options,context);
            rankOptions=selectFields(options,{ ...
                'RankTolerance','FiniteDifferenceStep'});
            diagnostics=lmz.solvers.RankAwareNonlinearSolver().analyze( ...
                problem,first.DecisionValues,first.ParameterValues, ...
                rankOptions,context);
            if diagnostics.Nullity~=1
                error('lmz:Timing:FamilyDimension', ...
                    ['Timing family continuation requires Jacobian nullity ' ...
                    'one; measured nullity is %d.'],diagnostics.Nullity);
            end
            if isempty(pair)
                radius=fieldOr(options,'SecondSeedRadius',0.01);
                seedOptions=rankOptions;
                seedOptions.ExpectedLocalDimension=1;
                pair=lmz.services.SeedService().makeSecondSeed( ...
                    problem,first,radius,seedOptions,context);
            end
            continuation=fieldOr(options,'ContinuationOptions',struct());
            if isa(continuation,'lmz.continuation.ContinuationOptions')
                continuation=continuation.toStruct();
            end
            if ~isstruct(continuation)||~isscalar(continuation)
                error('lmz:Timing:FamilyContinuationOptions', ...
                    'ContinuationOptions must be a scalar struct.');
            end
            continued=lmz.services.ContinuationService().run( ...
                problem,pair,continuation,context);
            provenance=continued.Provenance;
            provenance.Workflow='timing-family-continuation';
            descriptor=problem.getDescriptor();
            provenance.ProblemConfiguration=descriptor.configuration;
            provenance.TimingFamily=true;
            provenance.TimingGauges=cell(numel(problem.Gauges),1);
            for index=1:numel(problem.Gauges)
                provenance.TimingGauges{index}= ...
                    problem.Gauges(index).toStruct();
            end
            provenance.TimingFamilyProblemContract=struct( ...
                'ProviderClass',class(problem.Provider), ...
                'FixedInitialState',problem.FixedInitialState, ...
                'FixedPhysicalParameters',problem.FixedPhysicalParameters, ...
                'InputSchedule',problem.InputSchedule.toStruct(), ...
                'BaseConfiguration', ...
                problem.BaseProblem.getDescriptor().configuration);
            result=lmz.data.ContinuationResult(continued.Branch, ...
                continued.Snapshots,continued.TerminationReason, ...
                continued.Options,continued.Diagnostics, ...
                continued.SourcePair,continued.RandomSeed,provenance);
        end
    end
end

function [first,pair]=firstAndPair(problem,seed,options,context)
pair=[];
if isa(seed,'lmz.data.SolutionPair')
    pair=seed;first=pair.First;return
end
if isa(seed,'lmz.data.Solution')
    first=seed;
elseif isa(seed,'lmz.schedule.EventSchedule')
    u=problem.decisionFromSchedule(seed);
    evaluation=problem.evaluate(u,[],context,false);
    first=problem.makeSolution(u,[],evaluation);
else
    u=seed(:);
    evaluation=problem.evaluate(u,[],context,false);
    first=problem.makeSolution(u,[],evaluation);
end
tolerance=fieldOr(options,'ResidualTolerance',1e-8);
evaluation=problem.evaluate(first.DecisionValues, ...
    first.ParameterValues,context,false);
if evaluation.ScaledResidualNorm>tolerance
    error('lmz:Timing:FamilySeedResidual', ...
        'Timing family seed residual exceeds the configured tolerance.');
end
end

function value=selectFields(source,names)
value=struct();
for index=1:numel(names)
    if isfield(source,names{index}),value.(names{index})=source.(names{index});end
end
end

function value=fieldOr(source,name,fallback)
if isfield(source,name),value=source.(name);else,value=fallback;end
end
