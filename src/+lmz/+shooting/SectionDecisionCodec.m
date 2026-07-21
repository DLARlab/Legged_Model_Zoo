classdef SectionDecisionCodec
    %SECTIONDECISIONCODEC Stable model boundary for section-local decisions.
    methods
        function schema=decisionSchema(~,varargin)
            schema=[]; %#ok<NASGU>
            error('lmz:Shooting:DecisionCodecNotImplemented', ...
                'The model must implement decisionSchema.');
        end
        function value=encode(~,varargin)
            value=[]; %#ok<NASGU>
            error('lmz:Shooting:DecisionCodecNotImplemented', ...
                'The model must implement encode.');
        end
        function value=decode(~,varargin)
            value=[]; %#ok<NASGU>
            error('lmz:Shooting:DecisionCodecNotImplemented', ...
                'The model must implement decode.');
        end
        function value=toStruct(obj)
            value=struct('Class',class(obj),'Version','1.0.0');
        end
    end
end
