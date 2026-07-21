classdef RectangularTimingProvider < lmz.schedule.ContactConstraintProvider
    %RECTANGULARTIMINGPROVIDER Deterministic timing solver test fixture.
    properties (SetAccess=private)
        Mode
        TargetEvent = 0.4
        TargetReturn = 1.0
    end
    methods
        function obj=RectangularTimingProvider(mode)
            allowed={'square','underdetermined','rejected_crossing', ...
                'bound_endpoint'};
            if ~ischar(mode)||~any(strcmp(mode,allowed))
                error('lmztest:TimingProviderMode','Unknown timing fixture mode.');
            end
            obj.Mode=mode;
        end

        function value=eventNames(~),value={'impact'};end

        function value=evaluate(obj,initialState,physicalParameters, ...
                schedule,context,includeSimulation) %#ok<INUSD>
            context.check();
            eventTime=schedule.namedTimes({'impact'});
            contact=eventTime-obj.TargetEvent;bindings=[];
            if strcmp(obj.Mode,'bound_endpoint')
                contact=[contact;schedule.ReturnTime-obj.TargetReturn];
                section=zeros(0,1);
                accepted=abs(contact(2))<=1e-7;
                bindings=[struct('Kind','event','EventName','impact'); ...
                    struct('Kind','return','EventName','')];
            elseif strcmp(obj.Mode,'underdetermined')
                section=zeros(0,1);accepted=true;
            else
                section=schedule.ReturnTime-obj.TargetReturn;
                accepted=abs(section)<=1e-7;
            end
            if strcmp(obj.Mode,'rejected_crossing'),accepted=false;end
            terminal=initialState(:);
            crossing=struct('SectionId',schedule.StopSectionId, ...
                'SectionValue',conditionalValue(section), ...
                'DirectionalDerivative',-1,'CrossingDirection',-1, ...
                'Grazing',false,'EventId','','ModeBefore','flight', ...
                'ModeAfter','flight','Time',schedule.ReturnTime, ...
                'PreState',terminal,'PostState',terminal,'State',terminal, ...
                'StateSide','post','Occurrence',1,'Accepted',accepted, ...
                'RejectionReason',conditionalReason(accepted));
            value=struct('ContactResidual',contact, ...
                'SectionResidual',section,'TerminalState',terminal, ...
                'SectionCrossing',crossing,'Simulation',[], ...
                'Diagnostics',struct('FixtureMode',obj.Mode, ...
                'EnergyValid',true));
            if ~isempty(bindings),value.ContactRowBindings=bindings;end
        end
    end
end

function value=conditionalValue(source)
if isempty(source),value=0;else,value=source(1);end
end

function value=conditionalReason(accepted)
if accepted,value='';else,value='fixture-rejection';end
end
