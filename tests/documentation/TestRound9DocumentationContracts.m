classdef TestRound9DocumentationContracts < matlab.unittest.TestCase
    methods (Test)
        function requiredGuidesExistAndLinkLocally(testCase)
            root=lmz.util.ProjectPaths.root();docsRoot=fullfile(root,'docs');
            names={'getting-started-build-a-model.md','poincare-sections.md', ...
                'contact-timing-solve.md','multi-stride-planning.md', ...
                'periodic-orbit-and-continuation-tutorial.md'};
            for index=1:numel(names)
                path=fullfile(docsRoot,names{index});
                testCase.verifyEqual(exist(path,'file'),2,names{index});
                text=fileread(path);
                links=regexp(text,'\]\(([^\)#]+\.md)(?:#[^\)]*)?\)', ...
                    'tokens');
                for linkIndex=1:numel(links)
                    target=fullfile(docsRoot,links{linkIndex}{1});
                    testCase.verifyEqual(exist(target,'file'),2, ...
                        sprintf('%s links missing %s.', ...
                        names{index},links{linkIndex}{1}));
                end
            end
        end

        function rankAndTimingContractsAreUnambiguous(testCase)
            root=lmz.util.ProjectPaths.root();
            author=fileread(fullfile(root,'docs','model-author-guide.md'));
            testCase.verifyNotEmpty(strfind(author, ... %#ok<STREMP>
                'n-\operatorname{rank}(J_F)=1'));
            testCase.verifyEmpty(strfind(author, ... %#ok<STREMP>
                '`n`-decision,`n-1`-residual full-rank formulation'));

            timing=fileread(fullfile(root,'docs','contact-timing-solve.md'));
            required={'fixed initial state','fixed physical parameters', ...
                'It is not a periodic-orbit solve', ...
                'NoPeriodicityResidual=true','ContactTimingService', ...
                'SectionReturnTimingProblem'};
            for index=1:numel(required)
                testCase.verifyNotEmpty(strfind(timing,required{index}), ... %#ok<STREMP>
                    required{index});
            end
        end

        function multiStridePoliciesAndEnergyAreExplicit(testCase)
            root=lmz.util.ProjectPaths.root();
            text=fileread(fullfile(root,'docs','multi-stride-planning.md'));
            required={'error_if_missing','carry_forward', ...
                'carry_forward_and_solve_timings','predictor_corrector', ...
                'request_user','provider_callback','return_partial', ...
                'energy_neutral_only','declared_work','allow_non_neutral', ...
                'energy effect is rejected', ...
                'core code never','44 + 13*(N-1)'};
            for index=1:numel(required)
                testCase.verifyNotEmpty(strfind(text,required{index}), ... %#ok<STREMP>
                    required{index});
            end
        end

        function referencesExposeRoundNineContracts(testCase)
            root=lmz.util.ProjectPaths.root();docsRoot=fullfile(root,'docs');
            contracts={ ...
                'configuration-reference.md',{'EnergyEffect','poincare_sections.json', ...
                    'MultistartCount','MaximumStrides'}; ...
                'service-api.md',{'ContactTimingService', ...
                    'PoincareReturnMap','PoincareReturnService', ...
                    'SectionTransferService','MultiStrideSimulationService', ...
                    'StridePlanCompletionService','reproduceRun'}; ...
                'gui-design.md',{'Contact timing only','Periodic orbit', ...
                    'missing_stride_specification'}; ...
                'data-format.md',{'SectionCrossing','ContactTimingResult', ...
                    'MultiStrideResult'}; ...
                'testing-a-model.md',{'n-rank(J)=1', ...
                    'unknown-energy rejection','no interactive prompt'}};
            for row=1:size(contracts,1)
                text=fileread(fullfile(docsRoot,contracts{row,1}));
                tokens=contracts{row,2};
                for index=1:numel(tokens)
                    testCase.verifyNotEmpty(strfind(text,tokens{index}), ... %#ok<STREMP>
                        sprintf('%s misses %s.',contracts{row,1},tokens{index}));
                end
            end
        end

        function requiredExamplesExposeStablePublicContracts(testCase)
            root=lmz.util.ProjectPaths.root();examplesRoot=fullfile(root,'examples');
            required={ ...
                'demo_custom_poincare_section.m','LMZ_CUSTOM_POINCARE_SECTION_OK'; ...
                'demo_section_transfer.m','LMZ_SECTION_TRANSFER_OK'; ...
                'demo_contact_timing_only.m','LMZ_CONTACT_TIMING_ONLY_OK'; ...
                'demo_tutorial_hopper_periodic_continuation.m', ...
                    'LMZ_TUTORIAL_PERIODIC_CONTINUATION_OK'; ...
                'demo_tutorial_hopper_five_strides.m', ...
                    'LMZ_TUTORIAL_FIVE_STRIDES_OK'; ...
                'demo_quadruped_contact_timing.m', ...
                    'LMZ_QUADRUPED_CONTACT_TIMING_OK'; ...
                'demo_biped_contact_timing.m','LMZ_BIPED_CONTACT_TIMING_OK'; ...
                'demo_quad_load_extend_to_five_strides.m', ...
                    'LMZ_QUAD_LOAD_FIVE_STRIDES_OK'; ...
                'demo_quad_load_n_stride_fit.m', ...
                    'LMZ_QUAD_LOAD_N_STRIDE_FIT_OK'; ...
                'demo_n_stride_periodic_orbit.m', ...
                    'LMZ_N_STRIDE_PERIODIC_ORBIT_OK'; ...
                'demo_build_model_end_to_end.m', ...
                    'LMZ_BUILD_MODEL_END_TO_END_OK'};
            banned={'/Users/','SLIP_Quadruped','SLIP_Biped','SLIP_Quad_Load'};
            for row=1:size(required,1)
                path=fullfile(examplesRoot,required{row,1});
                testCase.verifyEqual(exist(path,'file'),2,required{row,1});
                fileText=fileread(path);
                tokens={'lmz.','output=struct','OutputDirectory',required{row,2}};
                for index=1:numel(tokens)
                    testCase.verifyNotEmpty(strfind(fileText,tokens{index}), ... %#ok<STREMP>
                        sprintf('%s misses %s.',required{row,1},tokens{index}));
                end
                for index=1:numel(banned)
                    testCase.verifyEmpty(strfind(fileText,banned{index}), ... %#ok<STREMP>
                        sprintf('%s contains external path/repository %s.', ...
                        required{row,1},banned{index}));
                end
            end
            runner=fileread(fullfile(root,'tools','run_public_examples.m'));
            testCase.verifyNotEmpty(strfind(runner, ... %#ok<STREMP>
                'round9OutputDirectory=fullfile'));
        end

        function publicServicesReplaceStaleDenials(testCase)
            root=lmz.util.ProjectPaths.root();docsRoot=fullfile(root,'docs');
            names={'service-api.md','poincare-sections.md', ...
                'periodic-orbit-and-continuation-tutorial.md'};
            combined='';
            for index=1:numel(names)
                combined=[combined newline fileread(fullfile( ...
                    docsRoot,names{index}))]; %#ok<AGROW>
            end
            required={'PoincareReturnService','SectionTransferService', ...
                'SectionTransferResult'};
            for index=1:numel(required)
                testCase.verifyNotEmpty(strfind(combined,required{index}), ... %#ok<STREMP>
                    required{index});
            end
            stale={'does not provide a generic `PoincareReturnService`', ...
                'does not provide a generic `SectionTransferService`', ...
                'does not expose a generic `PoincareReturnService`', ...
                'does not expose a generic `SectionTransferService`'};
            for index=1:numel(stale)
                testCase.verifyEmpty(strfind(combined,stale{index}), ... %#ok<STREMP>
                    stale{index});
            end
        end

        function scientificCoreContainsNoInteractivePrompt(testCase)
            root=lmz.util.ProjectPaths.root();
            folders={fullfile(root,'src','+lmz','+multistride'), ...
                fullfile(root,'src','+lmz','+schedule')};
            found=lmz.compat.Files.recursive(folders{1},'*.m',true);
            for index=1:numel(folders)
                if index>1
                    found=[found;lmz.compat.Files.recursive( ...
                        folders{index},'*.m',true)]; %#ok<AGROW>
                end
            end
            paths=cell(numel(found),1);
            for fileIndex=1:numel(found)
                paths{fileIndex}=fullfile( ...
                    found(fileIndex).folder,found(fileIndex).name);
            end
            servicePath=fullfile(root,'src','+lmz','+services', ...
                'ContactTimingService.m');
            for index=1:numel(paths)
                assertNoPrompt(testCase,paths{index});
            end
            assertNoPrompt(testCase,servicePath);
        end
    end
end

function assertNoPrompt(testCase,path)
text=fileread(path);
lines=regexp(text,'\r\n|\n|\r','split');
for index=1:numel(lines)
    marker=find(lines{index}=='%',1);
    if ~isempty(marker),lines{index}=lines{index}(1:marker-1);end
end
code=strjoin(lines,newline);
match=regexp(code,'\<(input|questdlg|uigetfile|uiputfile|listdlg)\s*\(', ...
    'once');
testCase.verifyEmpty(match,sprintf('Interactive prompt in %s.',path));
end
