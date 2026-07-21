classdef StrideSpec
    %STRIDESPEC Named, validated specification for one planned stride.
    properties (SetAccess=private)
        Index
        StartSectionId
        StopSectionId
        StartStateSide
        StopStateSide
        EventSchedule
        PhysicalParameters
        ControlParameters
        ParameterOverrides
        InitialStateSource
        InitialSectionState
        DeclaredWork
        CompletionStatus
        Diagnostics
        Lineage
    end

    methods
        function obj=StrideSpec(varargin)
            parser=inputParser;
            addParameter(parser,'Index',1,@isPositiveInteger);
            addParameter(parser,'StartSectionId','apex',@isIdentifier);
            addParameter(parser,'StopSectionId','apex',@isIdentifier);
            addParameter(parser,'StartStateSide','post',@isStateSide);
            addParameter(parser,'StopStateSide','pre',@isStateSide);
            addParameter(parser,'EventSchedule',struct(),@isSchedule);
            addParameter(parser,'PhysicalParameters',struct(),@isDataValue);
            addParameter(parser,'ControlParameters',struct(),@isDataValue);
            addParameter(parser,'ParameterOverrides',struct(),@isstruct);
            addParameter(parser,'InitialStateSource','specified',@isTextScalar);
            addParameter(parser,'InitialSectionState',zeros(0,1),@isFiniteVector);
            addParameter(parser,'DeclaredWork',0,@isFiniteScalar);
            addParameter(parser,'CompletionStatus','supplied',@isCompletionStatus);
            addParameter(parser,'Diagnostics',struct(),@isstruct);
            addParameter(parser,'Lineage',struct(),@isstruct);
            parse(parser,varargin{:});values=parser.Results;
            obj.Index=values.Index;
            obj.StartSectionId=char(values.StartSectionId);
            obj.StopSectionId=char(values.StopSectionId);
            obj.StartStateSide=char(values.StartStateSide);
            obj.StopStateSide=char(values.StopStateSide);
            obj.EventSchedule=values.EventSchedule;
            obj.PhysicalParameters=values.PhysicalParameters;
            obj.ControlParameters=values.ControlParameters;
            obj.ParameterOverrides=values.ParameterOverrides;
            obj.InitialStateSource=char(values.InitialStateSource);
            obj.InitialSectionState=values.InitialSectionState(:);
            obj.DeclaredWork=values.DeclaredWork;
            obj.CompletionStatus=char(values.CompletionStatus);
            obj.Diagnostics=values.Diagnostics;
            obj.Lineage=values.Lineage;
            obj.validate();
        end

        function report=validate(obj)
            validateFiniteData(obj.PhysicalParameters,'physical parameters');
            validateFiniteData(obj.ControlParameters,'control parameters');
            validateSchedule(obj.EventSchedule);
            report=struct('Valid',true,'Index',obj.Index, ...
                'CompletionStatus',obj.CompletionStatus);
        end

        function value=withCompletion(obj,status,diagnostics)
            if nargin<3,diagnostics=obj.Diagnostics;end
            if ~isCompletionStatus(status)||~isstruct(diagnostics)
                error('lmz:MultiStride:CompletionStatus', ...
                    'Completion status or diagnostics are invalid.');
            end
            value=obj;value.CompletionStatus=char(status);
            value.Diagnostics=diagnostics;value.validate();
        end

        function value=withControlParameters(obj,controls,overrides)
            if nargin<3,overrides=obj.ParameterOverrides;end
            if ~isDataValue(controls)||~isstruct(overrides)
                error('lmz:MultiStride:ControlParameters', ...
                    'Control parameters or overrides are invalid.');
            end
            value=obj;value.ControlParameters=controls;
            value.ParameterOverrides=overrides;value.validate();
        end

        function value=toStruct(obj)
            value=struct('Index',obj.Index, ...
                'StartSectionId',obj.StartSectionId, ...
                'StopSectionId',obj.StopSectionId, ...
                'StartStateSide',obj.StartStateSide, ...
                'StopStateSide',obj.StopStateSide, ...
                'EventSchedule',plainValue(obj.EventSchedule), ...
                'PhysicalParameters',plainValue(obj.PhysicalParameters), ...
                'ControlParameters',plainValue(obj.ControlParameters), ...
                'ParameterOverrides',obj.ParameterOverrides, ...
                'InitialStateSource',obj.InitialStateSource, ...
                'InitialSectionState',obj.InitialSectionState, ...
                'DeclaredWork',obj.DeclaredWork, ...
                'CompletionStatus',obj.CompletionStatus, ...
                'Diagnostics',obj.Diagnostics,'Lineage',obj.Lineage);
        end
    end

    methods (Static)
        function obj=fromStruct(value)
            required={'Index','StartSectionId','StopSectionId', ...
                'StartStateSide','StopStateSide','EventSchedule', ...
                'PhysicalParameters','ControlParameters','ParameterOverrides', ...
                'InitialStateSource','CompletionStatus','Diagnostics','Lineage'};
            if ~isstruct(value)||~all(isfield(value,required))
                error('lmz:MultiStride:StrideSpecStruct', ...
                    'Stored stride specification is incomplete.');
            end
            initialSectionState=zeros(0,1);
            if isfield(value,'InitialSectionState')
                initialSectionState=value.InitialSectionState;
            end
            declaredWork=0;
            if isfield(value,'DeclaredWork'),declaredWork=value.DeclaredWork;end
            obj=lmz.multistride.StrideSpec('Index',value.Index, ...
                'StartSectionId',value.StartSectionId, ...
                'StopSectionId',value.StopSectionId, ...
                'StartStateSide',value.StartStateSide, ...
                'StopStateSide',value.StopStateSide, ...
                'EventSchedule',value.EventSchedule, ...
                'PhysicalParameters',value.PhysicalParameters, ...
                'ControlParameters',value.ControlParameters, ...
                'ParameterOverrides',value.ParameterOverrides, ...
                'InitialStateSource',value.InitialStateSource, ...
                'InitialSectionState',initialSectionState, ...
                'DeclaredWork',declaredWork, ...
                'CompletionStatus',value.CompletionStatus, ...
                'Diagnostics',value.Diagnostics,'Lineage',value.Lineage);
        end
    end
end

function value=isPositiveInteger(source)
value=isnumeric(source)&&isreal(source)&&isscalar(source)&&isfinite(source)&& ...
    source>=1&&source==fix(source);
end
function value=isIdentifier(source)
value=isTextScalar(source)&&~isempty(regexp(char(source), ...
    '^[A-Za-z][A-Za-z0-9_]*$','once'));
end
function value=isStateSide(source)
value=isTextScalar(source)&&any(strcmp(char(source),{'pre','post'}));
end
function value=isCompletionStatus(source)
value=isTextScalar(source)&&any(strcmp(char(source), ...
    {'missing','supplied','completed','failed','partial'}));
end
function value=isTextScalar(source)
value=ischar(source)||(isstring(source)&&isscalar(source));
end
function value=isSchedule(source)
value=isstruct(source)||(~isempty(source)&&isobject(source)&& ...
    strncmp(class(source),'lmz.schedule.',13));
end
function value=isDataValue(source)
value=isnumeric(source)||islogical(source)||isstruct(source)||isempty(source);
end
function value=isFiniteVector(source)
value=isnumeric(source)&&isreal(source)&&(isempty(source)||isvector(source))&& ...
    all(isfinite(source(:)));
end
function value=isFiniteScalar(source)
value=isnumeric(source)&&isreal(source)&&isscalar(source)&&isfinite(source);
end
function validateSchedule(value)
if isstruct(value)&&isfield(value,'Times')
    times=value.Times;
    if ~isnumeric(times)||~isreal(times)||any(~isfinite(times(:)))
        error('lmz:MultiStride:EventSchedule', ...
            'Event schedule times must be finite real values.');
    end
end
end
function validateFiniteData(value,label)
if isnumeric(value)&&(~isreal(value)||any(~isfinite(value(:))))
    error('lmz:MultiStride:StrideData','The %s must be finite and real.',label);
elseif isstruct(value)
    names=fieldnames(value);
    for item=1:numel(value)
        for index=1:numel(names)
            field=value(item).(names{index});
            if isa(field,'function_handle')
                error('lmz:MultiStride:ExecutableData', ...
                    'Stride specifications cannot contain executable values.');
            end
            if isnumeric(field)&&(~isreal(field)||any(~isfinite(field(:))))
                error('lmz:MultiStride:StrideData', ...
                    'The %s must be finite and real.',label);
            end
        end
    end
end
end
function value=plainValue(source)
if isobject(source)&&ismethod(source,'toStruct'),value=source.toStruct();else,value=source;end
end
