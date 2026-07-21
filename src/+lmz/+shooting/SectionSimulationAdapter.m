classdef SectionSimulationAdapter
    %SECTIONSIMULATIONADAPTER Model-owned direct section propagation contract.
    methods
        function value=simulateSegment(~,varargin)
            value=[]; %#ok<NASGU>
            error('lmz:Shooting:SimulationAdapterNotImplemented', ...
                'The model must implement simulateSegment.');
        end
        function value=validateResult(~,value)
            required={'TerminalState','TerminalCoordinates', ...
                'ContactResiduals','SectionResidual','EnergyResidual', ...
                'Crossing','Simulation','PhysicalValidity','Diagnostics'};
            if ~isstruct(value)||~isscalar(value)||~all(isfield(value,required))
                error('lmz:Shooting:SegmentResult', ...
                    'A section segment result is incomplete.');
            end
            numericFields={'TerminalState','TerminalCoordinates', ...
                'ContactResiduals','SectionResidual','EnergyResidual'};
            for index=1:numel(numericFields)
                item=value.(numericFields{index});
                if ~isnumeric(item)||~isreal(item)||any(~isfinite(item(:)))
                    error('lmz:Shooting:SegmentResult', ...
                        'Segment result field %s must be finite real data.', ...
                        numericFields{index});
                end
            end
            value.TerminalState=value.TerminalState(:);
            value.TerminalCoordinates=value.TerminalCoordinates(:);
            value.ContactResiduals=value.ContactResiduals(:);
            value.SectionResidual=value.SectionResidual(:);
            value.EnergyResidual=value.EnergyResidual(:);
            value.PhysicalValidity=logical(value.PhysicalValidity);
        end
        function value=toStruct(obj)
            value=struct('Class',class(obj),'Version','1.0.0');
        end
    end
end
