classdef ResearchGraphics
    %RESEARCHGRAPHICS Public helper for reproducible profile examples.
    methods (Static)
        function session=open(modelId,profileId,visible)
            if nargin<2||isempty(profileId),profileId='research_legacy';end
            if nargin<3,visible='off';end
            registry=lmz.registry.ModelRegistry.discover();
            figureHandle=[];renderer=[];outputDirectory='';
            try
                [problemId,simulation]=scientificSimulation(registry,modelId);
                figureHandle=figure('Visible',visible,'Color','white', ...
                    'Position',[100 100 640 420]);
                outputDirectory=tempname;mkdir(outputDirectory);
                axesHandle=axes('Parent',figureHandle,'Position',[0.05 0.08 0.9 0.86]);
                factory=lmz.viz.RendererFactory(registry);
                [renderer,profile]=factory.createRenderer(axesHandle,simulation, ...
                    modelId,problemId,profileId,struct('ShowForces',false, ...
                    'DetailedOverlay',true,'GroundVisible',true, ...
                    'CameraFollow',true,'GroundStyle','hatched', ...
                    'Palette',profileId));
                session=struct('Registry',registry,'ModelId',modelId, ...
                    'ProblemId',problemId,'Simulation',simulation, ...
                    'Figure',figureHandle,'Axes',axesHandle,'Factory',factory, ...
                    'Renderer',renderer,'Profile',profile, ...
                    'OutputDirectory',outputDirectory);
            catch exception
                try
                    if ~isempty(renderer)&&isvalid(renderer),delete(renderer);end
                catch
                end
                try
                    if ~isempty(figureHandle)&&isgraphics(figureHandle)
                        delete(figureHandle);
                    end
                catch
                end
                try
                    if ~isempty(outputDirectory)&&exist(outputDirectory,'dir')==7
                        rmdir(outputDirectory,'s');
                    end
                catch
                end
                delete(registry);rethrow(exception)
            end
        end

        function summary=renderFrames(session,normalizedTimes)
            if nargin<2,normalizedTimes=[0 0.5 1];end
            if ~isnumeric(normalizedTimes)||numel(normalizedTimes)<3|| ...
                    any(~isfinite(normalizedTimes))||any(normalizedTimes<0)|| ...
                    any(normalizedTimes>1)
                error('lmz:Examples:FrameTimes', ...
                    'At least three finite normalized frame times in [0,1] are required.');
            end
            count=session.Renderer.frameCount();
            indices=1+round(normalizedTimes(:).*(count-1));
            sizes=zeros(numel(indices),3);checksums=zeros(numel(indices),1);
            bounds=zeros(numel(indices),4);
            for index=1:numel(indices)
                session.Renderer.updateFrame(indices(index));
                frame=session.Renderer.captureFrame();
                dimensions=size(frame);dimensions(end+1:3)=1;
                sizes(index,:)=dimensions(1:3);
                checksums(index)=sum(double(frame(:)));
                bounds(index,:)=foregroundBounds(frame);
            end
            summary=struct('ModelId',session.ModelId, ...
                'ProblemId',session.ProblemId,'ProfileId',session.Profile.Id, ...
                'RendererClass',class(session.Renderer), ...
                'NormalizedTimes',reshape(normalizedTimes,1,[]), ...
                'FrameIndices',reshape(indices,1,[]), ...
                'FrameImageSizes',sizes,'FrameChecksums',checksums, ...
                'ForegroundBounds',bounds, ...
                'HandleCount',numel(findall(session.Axes)));
        end

        function session=switchProfile(session,profileId,options)
            %SWITCHPROFILE Rebuild one live session while preserving its frame.
            if nargin<3,options=struct();end
            if ~isstruct(session)||~isfield(session,'Renderer')|| ...
                    isempty(session.Renderer)||~isvalid(session.Renderer)
                error('lmz:Examples:Session', ...
                    'An open research-graphics session is required.');
            end
            if ~(ischar(profileId)&&~isempty(profileId))
                error('lmz:Examples:Profile','Profile ID must be nonempty text.');
            end
            oldRenderer=session.Renderer;
            oldIndex=oldRenderer.CurrentIndex;
            count=max(1,oldRenderer.frameCount());
            normalized=(oldIndex-1)/max(1,count-1);
            newRenderer=[];
            try
                [newRenderer,newProfile]=session.Factory.createRenderer( ...
                    session.Axes,session.Simulation,session.ModelId, ...
                    session.ProblemId,profileId,options);
                newIndex=1+round(normalized*max(0,newRenderer.frameCount()-1));
                newRenderer.updateFrame(newIndex);
                delete(oldRenderer);
                session.Renderer=newRenderer;session.Profile=newProfile;
            catch exception
                deleteRenderer(newRenderer);rethrow(exception)
            end
        end

        function close(session)
            try
                if isstruct(session)&&isfield(session,'Renderer')&& ...
                        ~isempty(session.Renderer)&&isvalid(session.Renderer)
                    delete(session.Renderer);
                end
            catch
            end
            try
                if isstruct(session)&&isfield(session,'Figure')&& ...
                        isgraphics(session.Figure),delete(session.Figure);end
            catch
            end
            try
                if isstruct(session)&&isfield(session,'Registry')&& ...
                        ~isempty(session.Registry)&&isvalid(session.Registry)
                    delete(session.Registry);
                end
            catch
            end
            try
                if isstruct(session)&&isfield(session,'OutputDirectory')&& ...
                        exist(session.OutputDirectory,'dir')==7
                    rmdir(session.OutputDirectory,'s');
                end
            catch
            end
        end
    end
end

function [problemId,simulation]=scientificSimulation(registry,modelId)
context=lmz.api.RunContext.synchronous(81);service=lmz.services.BranchService();
model=registry.createModel(modelId);branch=service.loadBuiltInBranch(registry,modelId);
switch modelId
    case 'slip_quadruped'
        problemId='periodic_apex';catalog=lmzmodels.slip_quadruped.RoadMapCatalog.default();
        point=catalog.recommendedSeedIndex(catalog.defaultBranchPath());
    case 'slip_biped'
        problemId='periodic_apex';catalog=lmzmodels.slip_biped.GaitMapCatalog.default();
        point=catalog.recommendedSeedIndex(catalog.defaultBranchPath());
    case 'slip_quad_load'
        problemId='multi_stride_fit';point=1;
    otherwise
        error('lmz:Examples:ScientificModel', ...
            'Research graphics example does not support model %s.',modelId);
end
problem=model.createProblem(problemId,struct());solution=branch.point(point);
simulation=lmz.services.SolutionService().simulate(problem,solution,context);
end

function bounds=foregroundBounds(imageData)
data=double(imageData);
if size(data,3)>1,gray=mean(data(:,:,1:min(3,size(data,3))),3);else,gray=data;end
mask=gray<250;[rows,columns]=find(mask);
if isempty(rows),bounds=[0 0 0 0];else
    bounds=[min(columns) min(rows) max(columns) max(rows)];
end
end

function deleteRenderer(renderer)
try
    if ~isempty(renderer)&&isvalid(renderer),delete(renderer);end
catch
end
end
