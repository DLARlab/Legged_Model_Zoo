classdef MultipleShootingEvaluator
    %MULTIPLESHOOTINGEVALUATOR Simulate each segment once per residual call.
    properties (SetAccess=private)
        SegmentEvaluator
    end
    methods
        function obj=MultipleShootingEvaluator(segmentEvaluator)
            if ~isa(segmentEvaluator,'function_handle')&& ...
                    ~isa(segmentEvaluator,'lmz.shooting.SectionSimulationAdapter')
                error('lmz:Shooting:SegmentEvaluator', ...
                    'Segment evaluator must be a callback or SectionSimulationAdapter.');
            end
            obj.SegmentEvaluator=segmentEvaluator;
        end

        function residual=evaluate(obj,horizon,shootingSchema,decision, ...
                parameters,context,includeSimulation,formulation,configuration)
            if nargin<7,includeSimulation=false;end
            if nargin<8||isempty(formulation),formulation=horizon.Formulation;end
            if nargin<9,configuration=struct();end
            decoded=shootingSchema.decode(decision,horizon);
            segmentResults=cell(horizon.segmentCount(),1);
            blocks=lmz.data.ResidualBlock.empty(0,1);
            defects=lmz.shooting.InterfaceDefect.empty(0,1);
            physical=true;crossings=true;eventOrder=true;energyValid=true;
            contactNorms=zeros(horizon.segmentCount(),1);
            energyNorms=zeros(horizon.segmentCount(),1);
            sectionNorms=zeros(horizon.segmentCount(),1);
            for index=1:horizon.segmentCount()
                context.check();segment=horizon.Segments{index};
                request=struct('Segment',segment, ...
                    'StartNode',decoded.Nodes{index}, ...
                    'StopNode',decoded.Nodes{index+1}, ...
                    'EventSchedule',decoded.Schedules{index}, ...
                    'ControlParameters',decoded.Controls{index}, ...
                    'PhysicalParameters',struct('ProblemValues',parameters(:), ...
                    'Segment',segment.PhysicalParameters, ...
                    'DecisionOverrides',decoded.PhysicalParameters), ...
                    'DecodedDecision',decoded,'Configuration',configuration);
                value=obj.evaluateSegment(request,context,includeSimulation);
                value=lmz.shooting.SectionSimulationAdapter().validateResult(value);
                segmentResults{index}=value;
                if ~isempty(value.ContactResiduals)
                    blocks(end+1,1)=lmz.data.ResidualBlock( ...
                        sprintf('segment_%d_contact_constraints',index), ...
                        value.ContactResiduals,ones(numel(value.ContactResiduals),1)); %#ok<AGROW>
                end
                if ~isempty(value.SectionResidual)
                    blocks(end+1,1)=lmz.data.ResidualBlock( ...
                        sprintf('segment_%d_section_residual',index), ...
                        value.SectionResidual,ones(numel(value.SectionResidual),1)); %#ok<AGROW>
                end
                node=decoded.Nodes{index+1};
                names=node.StateSchema.CoordinateNames;
                defect=lmz.shooting.InterfaceDefect(index, ...
                    value.TerminalCoordinates,node.SectionCoordinates, ...
                    names,node.StateSchema.scales());
                defects(end+1,1)=defect; %#ok<AGROW>
                blocks(end+1,1)=defect.toResidualBlock(); %#ok<AGROW>
                mode=segment.EnergyWorkSpecification.Mode;
                if ~isempty(value.EnergyResidual)&&~strcmp(mode,'diagnostic_only')
                    scale=max(segment.EnergyWorkSpecification.Tolerance,eps);
                    blocks(end+1,1)=lmz.data.ResidualBlock( ...
                        sprintf('segment_%d_energy_work',index), ...
                        value.EnergyResidual,repmat(scale, ...
                        numel(value.EnergyResidual),1)); %#ok<AGROW>
                end
                contactNorms(index)=norm(value.ContactResiduals);
                sectionNorms(index)=norm(value.SectionResidual);
                energyNorms(index)=norm(value.EnergyResidual);
                physical=physical&&logical(value.PhysicalValidity)&& ...
                    all(isfinite(value.TerminalState));
                energyValid=energyValid&&acceptedEnergy(value.Diagnostics);
                crossings=crossings&&acceptedCrossing(value.Crossing,configuration);
                eventOrder=eventOrder&&eventOrderValid(value.Diagnostics);
                context.progress(0.9*index/horizon.segmentCount(), ...
                    sprintf('Evaluated shooting segment %d/%d', ...
                    index,horizon.segmentCount()));
            end
            final=finalResidual(formulation,decoded,configuration);
            if ~isempty(final.Values)
                blocks(end+1,1)=lmz.data.ResidualBlock(final.Name, ...
                    final.Values,final.Scale);
            end
            active=[];
            for index=1:numel(blocks),active=[active;blocks(index).scaled()];end %#ok<AGROW>
            tolerance=fieldOr(configuration,'ResidualTolerance',1e-7);
            residualValid=all(isfinite(active))&&norm(active,inf)<=tolerance;
            physicalConditions=physical&&crossings&&eventOrder&&energyValid;
            valid=physicalConditions&&residualValid;
            feasibility=struct('Valid',valid,'ResidualValid',residualValid, ...
                'PhysicalValidity',physical,'CrossingsAccepted',crossings, ...
                'EventOrderValid',eventOrder, ...
                'EnergyValid',energyValid, ...
                'PhysicalConditionsValid',physicalConditions, ...
                'Tolerance',tolerance, ...
                'MaximumScaledResidual',maxOrZero(abs(active)));
            diagnostics=struct('Formulation',formulation, ...
                'SegmentEvaluationCount',horizon.segmentCount(), ...
                'SingleEvaluationCache',true,'ContactNorms',contactNorms, ...
                'InterfaceDefectNorms',arrayfun(@(item)item.norm(),defects), ...
                'SectionResidualNorms',sectionNorms, ...
                'EnergyWorkResidualNorms',energyNorms, ...
                'EnergyValid',energyValid, ...
                'FinalResidualName',final.Name, ...
                'FinalResidualNorm',norm(final.Values), ...
                'HiddenTimingSolve',false,'DecodedTarget',decoded.Target);
            residual=lmz.shooting.ShootingResidual(blocks,segmentResults, ...
                defects,feasibility,diagnostics);
        end
    end
    methods (Access=private)
        function value=evaluateSegment(obj,request,context,includeSimulation)
            if isa(obj.SegmentEvaluator,'function_handle')
                value=obj.SegmentEvaluator(request,context,includeSimulation);
            else
                value=obj.SegmentEvaluator.simulateSegment( ...
                    request,context,includeSimulation);
            end
        end
    end
end

function value=acceptedCrossing(crossing,configuration)
if ~fieldOr(configuration,'RequireAcceptedCrossing',true)
    value=true;return
end
if isa(crossing,'lmz.poincare.SectionCrossing')
    value=crossing.Accepted&&~crossing.Grazing;
elseif isstruct(crossing)&&isfield(crossing,'Accepted')
    value=logical(crossing.Accepted);
    if isfield(crossing,'Grazing'),value=value&&~logical(crossing.Grazing);end
else
    value=false;
end
end
function value=eventOrderValid(diagnostics)
value=true;
if isstruct(diagnostics)&&isfield(diagnostics,'EventOrderValid')
    value=logical(diagnostics.EventOrderValid);
end
end
function value=acceptedEnergy(diagnostics)
value=true;
if isstruct(diagnostics)&&isfield(diagnostics,'EnergyValid')
    value=logical(diagnostics.EnergyValid);
elseif isstruct(diagnostics)&&isfield(diagnostics,'Energy')&& ...
        isstruct(diagnostics.Energy)&&isfield(diagnostics.Energy,'Accepted')
    value=logical(diagnostics.Energy.Accepted);
end
end
function value=finalResidual(formulation,decoded,configuration)
value=struct('Name','','Values',zeros(0,1),'Scale',zeros(0,1));
switch formulation
    case 'periodic'
        first=decoded.Nodes{1}.SectionCoordinates;
        last=decoded.Nodes{end}.SectionCoordinates;
        if numel(first)~=numel(last)
            error('lmz:Shooting:PeriodicCoordinateDimension', ...
                'Periodic first/final section coordinate dimensions differ.');
        end
        value.Name='final_section_closure';value.Values=last-first;
        value.Scale=decoded.Nodes{1}.StateSchema.scales();
    case 'transition'
        last=decoded.Nodes{end}.SectionCoordinates;
        target=fieldOr(decoded.Target,'SectionCoordinates', ...
            fieldOr(configuration,'TargetSectionCoordinates',[]));
        if isempty(target)||numel(target)~=numel(last)
            error('lmz:Shooting:TransitionTarget', ...
                'Transition formulation requires target section coordinates.');
        end
        value.Name='final_transition_target';value.Values=last-target(:);
        value.Scale=decoded.Nodes{end}.StateSchema.scales();
    case 'feasibility'
        target=fieldOr(configuration,'TargetResidual',[]);
        if ~isempty(target)
            value.Name='final_feasibility_target';value.Values=target(:);
            value.Scale=ones(numel(target),1);
        end
    otherwise
        error('lmz:Shooting:Formulation','Unknown shooting formulation %s.',formulation);
end
end
function value=maxOrZero(source)
if isempty(source),value=0;else,value=max(source);end
end
function value=fieldOr(source,name,fallback)
if isstruct(source)&&isfield(source,name),value=source.(name);else,value=fallback;end
end
