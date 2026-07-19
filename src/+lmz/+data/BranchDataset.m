classdef BranchDataset < handle
    properties
        Id; Name; Visible=true; DisplayStyle; SourcePath=''; ReadOnly=false; Branch
    end
    methods
        function obj=BranchDataset(name,branch,varargin)
            parser=inputParser; addParameter(parser,'SourcePath',''); addParameter(parser,'ReadOnly',false); parse(parser,varargin{:});
            obj.Id=lmz.util.Ids.new('dataset'); obj.Name=name; obj.Branch=branch; obj.SourcePath=parser.Results.SourcePath; obj.ReadOnly=parser.Results.ReadOnly;
            obj.DisplayStyle=struct('Color',[0 0.447 0.741],'LineStyle','-','Marker','.');
        end
    end
end
