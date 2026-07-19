function fixturePath=capture_slip_quad_load_source_baselines(sourceRoot)
%CAPTURE_SLIP_QUAD_LOAD_SOURCE_BASELINES Run once against immutable source.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1,sourceRoot=fullfile(fileparts(root),'2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights');end
expectedOrigin='https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git';
expectedCommit='19f3133073c988cc0c3424a647b4adbb60a90b99';
verifyCheckout(sourceRoot,expectedOrigin,expectedCommit);
functionsPath=fullfile(sourceRoot,'Stored_Functions');dynamicsPath=fullfile(functionsPath,'Dynamics');
addpath(functionsPath,'-begin');addpath(dynamicsPath,'-begin');cleanup=onCleanup(@()removePaths(functionsPath,dynamicsPath));
definitions={ ...
    'single_stride','Section2_Single_Stride_Replication/P3_Individual_1_TR.mat', ...
        '56736cc33ab31a0ab40b3de6783b625a07ebd54f1ae6a561b47aea5e04cd6abe'; ...
    'gait_transition','Section3_Gait_Transition_Replication/P4_TR_RL_Individual_1.mat', ...
        'd23bd725a353d7cf1b6339699ed813755867b5dd1a0da213193eb24cb3bdad4b'};
entries=cell(size(definitions,1),1);
for index=1:size(definitions,1)
    id=definitions{index,1};relativePath=definitions{index,2};path=fullfile(sourceRoot,strrep(relativePath,'/',filesep));loaded=load(path);
    [R,R9,T,Y,GRF,FLoad,P,XTrue,N]=SimulateQuadLoadStrides(loaded.X_accum);
    [eventStates,perStrideResidual]=captureEvents(loaded.X_accum);
    if isfield(loaded,'gait_data')
        experimental=loaded.gait_data;tExp=experimental.t_exp;ftExp=experimental.ft_exp;forceExp=experimental.loading_force_mean;
        sensitivity=struct();storedR2=struct();gaitType=loaded.gait_type;
    else
        experimental=loaded.TransitionTemplate_Normalized;tExp=experimental.t_exp;ftExp=experimental.ft_exp;forceExp=experimental.loading_force_exp;
        sensitivity=loaded.SensitivityStudyData;storedR2=loaded.R2;gaitType='transition';
    end
    [objective,costTerms,r2]=fms_NStridesObjectiveFcn_Quad_Load_v2(loaded.X_accum,tExp,ftExp,forceExp,loaded.term_weights);
    entries{index}=struct('Id',id,'SourcePath',relativePath,'SHA256',definitions{index,3}, ...
        'XAccum',loaded.X_accum(:),'StrideCount',N,'Decoded',decodeSource(loaded.X_accum), ...
        'Experimental',experimental,'TermWeights',loaded.term_weights,'SensitivityStudyData',sensitivity, ...
        'StoredR2',storedR2,'GaitType',gaitType,'Residual',R,'FirstNineResiduals',R9, ...
        'Time',T,'States',Y,'GroundReactionForces',GRF,'TuglineForce',FLoad, ...
        'Parameters',P,'XAccumTrue',XTrue,'EventStates',eventStates, ...
        'PerStrideResidual',{perStrideResidual},'Objective',objective, ...
        'ObjectiveTerms',costTerms,'R2',r2);
end
entries=vertcat(entries{:});
baseline=struct('SchemaVersion','1.0.0','SourceRepository',expectedOrigin, ...
    'SourceCommit',expectedCommit,'CapturedWith',version,'CapturedAt',datestr(now,30), ...
    'Entries',entries,'Tolerances',struct('ResidualAbsolute',1e-11, ...
    'TimeAbsolute',1e-12,'StateAbsolute',1e-10,'StateRelative',1e-9, ...
    'GRFAbsolute',1e-9,'GRFRelative',1e-8,'TuglineAbsolute',1e-10, ...
    'ParameterAbsolute',1e-12,'ObjectiveAbsolute',1e-10,'R2Absolute',1e-12));
fixtureDirectory=fullfile(root,'tests','fixtures','baselines','slip_quad_load');
if exist(fixtureDirectory,'dir')~=7,mkdir(fixtureDirectory);end
fixturePath=fullfile(fixtureDirectory,'source_baselines.mat');save(fixturePath,'baseline');clear cleanup
end

function verifyCheckout(root,expectedOrigin,expectedCommit)
[status,origin]=system(sprintf('git -C "%s" remote get-url origin',root));
if status~=0||~strcmp(strtrim(origin),expectedOrigin),error('lmz:QuadLoad:BaselineOrigin','Unexpected source origin.');end
[status,commit]=system(sprintf('git -C "%s" rev-parse HEAD',root));
if status~=0||~strcmp(strtrim(commit),expectedCommit),error('lmz:QuadLoad:BaselineCommit','Unexpected source commit.');end
[status,changes]=system(sprintf('git -C "%s" status --porcelain',root));
if status~=0||~isempty(strtrim(changes)),error('lmz:QuadLoad:BaselineDirty','Source checkout must be clean.');end
end

function value=decodeSource(x)
x=x(:);count=(numel(x)-44)/13+1;later=repmat(struct('EventTiming',[],'PostSwingStiffness',[]),max(0,count-1),1);
for stride=2:count,startIndex=45+13*(stride-2);later(stride-1)=struct( ...
        'EventTiming',x(startIndex:startIndex+8),'PostSwingStiffness',x(startIndex+9:startIndex+12));end
value=struct('QuadrupedState',x(1:13),'EventTiming',x(14:22), ...
    'QuadrupedParameters',x(23:36),'LoadState',x(37:38), ...
    'LoadParameters',x(39:44),'LaterStrides',later);
end

function [states,residuals]=captureEvents(x)
x=x(:);count=(numel(x)-44)/13+1;current=x(1:44);states=zeros(9*count,18);residuals=cell(count,1);
for stride=1:count
    [residual,~,Y,~,~,~,events]=Quad_Load_ZeroFun_Transition_v2(current,'skipSolve');
    states(9*(stride-1)+(1:9),:)=events;residuals{stride}=residual;
    if stride<count
        startIndex=45+13*(stride-1);next=zeros(44,1);next(1:13)=Y(end,2:14).';
        next(37)=Y(end,15)-Y(end,1);next(38)=Y(end,16);next(14:22)=x(startIndex:startIndex+8);
        next(24:27)=current(28:31);next(28:31)=x(startIndex+9:startIndex+12);
        next([23 32:36 39:44])=x([23 32:36 39:44]);current=next;
    end
end
end

function removePaths(functionsPath,dynamicsPath)
if contains([path pathsep],[functionsPath pathsep]),rmpath(functionsPath);end
if contains([path pathsep],[dynamicsPath pathsep]),rmpath(dynamicsPath);end
end
