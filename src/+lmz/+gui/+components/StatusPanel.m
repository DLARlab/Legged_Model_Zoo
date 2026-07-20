classdef StatusPanel < handle
    %STATUSPANEL Timestamped, bounded, copyable status aggregation.
    properties (SetAccess=private)
        Root
        Area
        CopyButton
        Records = struct('Timestamp',{},'Severity',{},'Message',{},'Details',{})
    end
    properties
        MaximumRecords = 100
    end
    methods
        function obj = StatusPanel(parent)
            obj.Root = uigridlayout(parent,[1 2]);
            obj.Root.ColumnWidth = {'1x',90};
            obj.Area = uitextarea(obj.Root,'Editable','off','Value',{'Ready.'}, ...
                'Tag','lmz-status-area','Tooltip','Status history; text can be selected and copied.');
            obj.CopyButton = uibutton(obj.Root,'Text','Copy details', ...
                'Tag','lmz-copy-diagnostics','Tooltip','Copy status and technical details.', ...
                'ButtonPushedFcn',@(~,~)obj.copy());
        end

        function append(obj,message,severity,details,timestamp)
            if nargin<3||isempty(severity), severity = 'info'; end
            if nargin<4, details = ''; end
            if nargin<5||isempty(timestamp)
                timestamp = datestr(now,'yyyy-mm-dd HH:MM:SS');
            end
            record = struct('Timestamp',timestamp,'Severity',severity, ...
                'Message',char(message),'Details',char(details));
            obj.Records(end+1) = record;
            if numel(obj.Records)>obj.MaximumRecords
                obj.Records = obj.Records(end-obj.MaximumRecords+1:end);
            end
            obj.refresh();
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
            for index = 1:numel(obj.Records)
                item = obj.Records(index);
                parts{end+1} = sprintf('[%s] %s: %s',item.Timestamp, ...
                    upper(item.Severity),item.Message); %#ok<AGROW>
                if ~isempty(item.Details), parts{end+1} = item.Details; end %#ok<AGROW>
            end
            value = strjoin(parts,newline);
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
end
