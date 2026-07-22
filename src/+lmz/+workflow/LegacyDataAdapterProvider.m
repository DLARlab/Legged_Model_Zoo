classdef (Abstract) LegacyDataAdapterProvider < handle
    %LEGACYDATAADAPTERPROVIDER Model-owned legacy MAT import/export contract.
    methods (Abstract)
        valid = canLoad(obj, path)
        branch = importBranch(obj, path, problem)
        exportBranch(obj, path, branch)
    end
end
