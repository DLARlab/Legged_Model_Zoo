%DEMO_CUSTOM_POINCARE_SECTION Evaluate a trusted descending-height section.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(projectRoot);startup;cd(originalDirectory);
if ~exist('round9OutputDirectory','var')||isempty(round9OutputDirectory)
    round9OutputDirectory=tempname(tempdir);
end
if exist(round9OutputDirectory,'dir')~=7
    [created,message]=mkdir(round9OutputDirectory);
    if ~created
        error('lmz:Example:OutputDirectory','%s',message);
    end
end

registry=lmz.registry.ModelRegistry.discover();
model=registry.createModel('tutorial_hopper');
problem=model.createProblem('periodic_hop',struct());
decision=problem.getDecisionSchema().defaults();
parameters=problem.getParameterSchema().defaults();
context=lmz.api.RunContext.synchronous(901);
evaluation=problem.evaluate(decision,parameters,context,true);

sectionCatalog=registry.getPoincareSectionRegistry('tutorial_hopper');
apex=sectionCatalog.section('apex');
descriptor=sectionCatalog.section('height_descending').toStruct();
descriptor.id='custom_height_descending';
descriptor.label='Custom descending height at 0.2 m';
descriptor.threshold=0.2;
descriptor.validationStatus='tested';
customSection=lmz.poincare.StateFunctionSection( ...
    lmz.poincare.PoincareSectionDescriptor(descriptor), ...
    model.getPhysicalStateSchema());
symmetry=sectionCatalog.symmetryFor('height_descending');
stride=lmz.poincare.StrideDefinition.fromSections( ...
    apex,customSection,symmetry.Id);
returnMap=lmz.poincare.PoincareReturnMap(apex,customSection,symmetry, ...
    model.getPhysicalStateSchema(),stride);
returned=returnMap.evaluate(evaluation.Simulation.States(1,:).',parameters, ...
    @(~,~,~,~)evaluation.Simulation,context);

if ~strcmp(returned.StopCrossing.SectionId,'custom_height_descending')|| ...
        returned.StopCrossing.Grazing||~returned.StopCrossing.Accepted
    error('lmz:Example:CustomPoincare', ...
        'The custom section did not produce an accepted transverse crossing.');
end
output=struct('SectionDescriptor',customSection.toStruct(), ...
    'ReturnResult',returned,'CrossingTime',returned.StopCrossing.Time, ...
    'DirectionalDerivative',returned.StopCrossing.DirectionalDerivative, ...
    'OutputDirectory',round9OutputDirectory, ...
    'SuccessMarker','LMZ_CUSTOM_POINCARE_SECTION_OK');
fprintf('%s time=%.12g derivative=%.12g\n',output.SuccessMarker, ...
    output.CrossingTime,output.DirectionalDerivative);
clear directoryCleanup
