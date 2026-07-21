classdef SectionTerminationPolicy
    %SECTIONTERMINATIONPOLICY Initial-root latch and return acceptance rules.
    properties (SetAccess=private)
        Section
        MinimumReturnTime
        RequiredEventSequence
        ReturnOccurrence
        InitialRootTolerance
    end
    methods
        function obj=SectionTerminationPolicy(section,varargin)
            if ~isa(section,'lmz.poincare.PoincareSection')
                error('lmz:Simulation:SectionPolicy', ...
                    'SectionTerminationPolicy requires a PoincareSection.');
            end
            parser=inputParser;
            addParameter(parser,'InitialRootTolerance',1e-9, ...
                @(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
            parse(parser,varargin{:});
            obj.Section=section;obj.MinimumReturnTime=section.MinimumReturnTime;
            obj.RequiredEventSequence=section.RequiredEventSequence;
            obj.ReturnOccurrence=section.ReturnOccurrence;
            obj.InitialRootTolerance=parser.Results.InitialRootTolerance;
        end
        function value=isArmed(obj,time,leftInitialSurface,eventHistory)
            if nargin<4,eventHistory={};end
            value=time+64*eps(max(1,abs(time)))>=obj.MinimumReturnTime&& ...
                logical(leftInitialSurface)&&obj.hasSequence(eventHistory);
        end
        function value=ignoreInitialRoot(obj,time,sectionValue,leftInitialSurface)
            value=~leftInitialSurface&&time<=obj.MinimumReturnTime&& ...
                abs(sectionValue)<=obj.InitialRootTolerance;
        end
        function [accepted,reason]=accept(obj,crossing,eventHistory)
            if ~obj.isArmed(crossing.Time,true,eventHistory)
                accepted=false;reason='section-policy-not-armed';return
            end
            [accepted,reason]=obj.Section.acceptCrossing(crossing,eventHistory);
        end
        function value=toStruct(obj)
            value=struct('SectionId',obj.Section.Id, ...
                'MinimumReturnTime',obj.MinimumReturnTime, ...
                'RequiredEventSequence',{obj.RequiredEventSequence}, ...
                'ReturnOccurrence',obj.ReturnOccurrence, ...
                'InitialRootTolerance',obj.InitialRootTolerance);
        end
    end
    methods (Access=private)
        function valid=hasSequence(obj,history)
            observed=eventIds(history);cursor=1;valid=true;
            for index=1:numel(obj.RequiredEventSequence)
                match=find(strcmp(obj.RequiredEventSequence{index}, ...
                    observed(cursor:end)),1);
                if isempty(match),valid=false;return,end
                cursor=cursor+match;
            end
        end
    end
end

function values=eventIds(history)
if isempty(history),values={};return,end
if ischar(history),values={history};return,end
if iscell(history),values=history(:).';return,end
values=cell(1,numel(history));
for index=1:numel(history)
    if isfield(history(index),'Id'),values{index}=history(index).Id; ...
    else,values{index}=history(index).Name;end
end
end
