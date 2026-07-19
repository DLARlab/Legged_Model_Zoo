classdef Provenance
    methods (Static),function p=capture(),p=struct('created_utc',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX')),'matlab_version',version,'lmz_version','0.1.0');end,end
end
