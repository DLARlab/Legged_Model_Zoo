classdef StatusPanel < handle
    %STATUSPANEL Timestamped, bounded, copyable status aggregation.
    properties (SetAccess=private)
        Root
        Area
        CopyButton
        StageLabel
        ProgressGauge
        Records = struct('Timestamp',{},'Severity',{},'Message',{},'Details',{})
        CurrentStage = 'Ready'
        ProgressValue = NaN
        ProgressDetails = ''
    end
    properties
        MaximumRecords = 100
    end
    properties (Access=private)
        HasProgress = false
    end
    methods
        function obj = StatusPanel(parent)
            obj.Root = uigridlayout(parent,[2 3]);
            obj.Root.RowHeight = {24,'1x'};
            obj.Root.ColumnWidth = {'1x',170,90};
            obj.Root.RowSpacing = 4;
            obj.Root.ColumnSpacing = 8;
            obj.Root.Padding = [0 0 0 0];
            obj.StageLabel = uilabel(obj.Root,'Text','Stage: Ready', ...
                'Tag','lmz-status-stage', ...
                'Tooltip','Current solver or workflow stage.');
            obj.StageLabel.Layout.Row = 1;
            obj.StageLabel.Layout.Column = 1;
            obj.ProgressGauge = uigauge(obj.Root,'linear','Limits',[0 1], ...
                'Value',0,'Tag','lmz-status-progress');
            obj.ProgressGauge.Layout.Row = 1;
            obj.ProgressGauge.Layout.Column = 2;
            obj.Area = uitextarea(obj.Root,'Editable','off','Value',{'Ready.'}, ...
                'Tag','lmz-status-area','Tooltip','Status history; text can be selected and copied.');
            obj.Area.Layout.Row = 2;
            obj.Area.Layout.Column = [1 3];
            obj.CopyButton = uibutton(obj.Root,'Text','Copy details', ...
                'Tag','lmz-copy-diagnostics','Tooltip','Copy status and technical details.', ...
                'ButtonPushedFcn',@(~,~)obj.copy());
            obj.CopyButton.Layout.Row = 1;
            obj.CopyButton.Layout.Column = 3;
        end

        function append(obj,message,severity,details,timestamp)
            if nargin<3||isempty(severity), severity = 'info'; end
            if nargin<4, details = ''; end
            if nargin<5||isempty(timestamp)
                timestamp = char(datetime('now', ...
                    'Format','yyyy-MM-dd HH:mm:ss'));
            end
            record = struct('Timestamp',timestamp,'Severity',severity, ...
                'Message',char(message),'Details',diagnosticString(details));
            obj.Records(end+1) = record;
            if numel(obj.Records)>obj.MaximumRecords
                obj.Records = obj.Records(end-obj.MaximumRecords+1:end);
            end
            obj.refresh();
        end

        function setProgress(obj,stage,value,details)
            %SETPROGRESS Persist stage, fractional completion, and diagnostics.
            if nargin<2||isempty(stage),stage='Ready';end
            if nargin<3,value=NaN;end
            if nargin<4,details='';end
            if ~((ischar(stage)&&isrow(stage))|| ...
                    (isstring(stage)&&isscalar(stage)))
                error('lmz:GUI:StatusStage','Progress stage must be scalar text.');
            end
            if isempty(value),value=NaN;end
            if ~isnumeric(value)||~isreal(value)||~isscalar(value)|| ...
                    ~(isnan(value)||(isfinite(value)&&value>=0&&value<=1))
                error('lmz:GUI:StatusProgress', ...
                    'Progress must be NaN or a finite fraction from zero to one.');
            end
            obj.CurrentStage=char(stage);
            obj.ProgressValue=double(value);
            obj.ProgressDetails=diagnosticString(details);
            obj.HasProgress=true;
            obj.refreshProgress();
        end

        function updateProgress(obj,varargin)
            %UPDATEPROGRESS Compatibility alias for incremental presenters.
            obj.setProgress(varargin{:});
        end

        function setStage(obj,stage)
            obj.setProgress(stage,obj.ProgressValue,obj.ProgressDetails);
        end

        function setDiagnostics(obj,details)
            obj.ProgressDetails=diagnosticString(details);
            obj.HasProgress=true;
        end

        function clearProgress(obj)
            obj.CurrentStage='Ready';
            obj.ProgressValue=NaN;
            obj.ProgressDetails='';
            obj.HasProgress=false;
            obj.refreshProgress();
        end

        function refresh(obj)
            if isempty(obj.Area)||~isvalid(obj.Area), return, end
            if isempty(obj.Records), obj.Area.Value = {'Ready.'}; return, end
            values = cell(1,numel(obj.Records));
            for index = 1:numel(obj.Records)
                item = obj.Records(index);
                values{index} = sprintf('[%s] %s: %s',item.Timestamp, ...
                    upper(item.Severity),item.Message);
            end
            obj.Area.Value = values;
        end

        function value = diagnosticText(obj)
            parts = {};
            if obj.HasProgress
                parts{end+1}=sprintf('Stage: %s',obj.CurrentStage);
                if ~isnan(obj.ProgressValue)
                    parts{end+1}=sprintf('Progress: %.1f%%', ...
                        100*obj.ProgressValue);
                end
                if ~isempty(obj.ProgressDetails)
                    parts{end+1}=obj.ProgressDetails;
                end
            end
            for index = 1:numel(obj.Records)
                item = obj.Records(index);
                parts{end+1} = sprintf('[%s] %s: %s',item.Timestamp, ...
                    upper(item.Severity),item.Message); %#ok<AGROW>
                if ~isempty(item.Details), parts{end+1} = item.Details; end %#ok<AGROW>
            end
            value = strjoin(parts,newline);
        end

        function value=testHooks(obj)
            value=struct('StageLabel',obj.StageLabel, ...
                'ProgressGauge',obj.ProgressGauge,'Area',obj.Area, ...
                'CopyButton',obj.CopyButton,'CurrentStage',obj.CurrentStage, ...
                'ProgressValue',obj.ProgressValue, ...
                'ProgressDetails',obj.ProgressDetails);
        end

        function copy(obj)
            if usejava('desktop')
                clipboard('copy',obj.diagnosticText());
            end
        end

        function delete(obj)
            if ~isempty(obj.Root)&&isvalid(obj.Root), delete(obj.Root); end
        end
    end


    methods (Access=private)
        function refreshProgress(obj)
            if ~isempty(obj.StageLabel)&&isvalid(obj.StageLabel)
                if isnan(obj.ProgressValue)
                    obj.StageLabel.Text=sprintf('Stage: %s',obj.CurrentStage);
                else
                    obj.StageLabel.Text=sprintf('Stage: %s (%.0f%%)', ...
                        obj.CurrentStage,100*obj.ProgressValue);
                end
            end
            if ~isempty(obj.ProgressGauge)&&isvalid(obj.ProgressGauge)
                if isnan(obj.ProgressValue)
                    obj.ProgressGauge.Value=0;
                else
                    obj.ProgressGauge.Value=obj.ProgressValue;
                end
            end
        end
    end
end

function value=diagnosticString(source)
if isempty(source),value='';return,end
if ischar(source),value=source;return,end
if isstring(source)&&isscalar(source),value=char(source);return,end
if isa(source,'MException'),value=getReport(source,'extended','hyperlinks','off');return,end
if isnumeric(source)||islogical(source)
    value=mat2str(source);return
end
try
    value=strtrim(evalc('disp(source)'));
catch
    value=char(string(source));
end
end
