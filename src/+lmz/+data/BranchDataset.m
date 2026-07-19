classdef BranchDataset < handle
    properties
        Id; Name; Visible=true; DisplayStyle; SourcePath=''; ReadOnly=false; Branch; Metadata
    end
    methods
        function obj=BranchDataset(name,branch,varargin)
            parser=inputParser; addParameter(parser,'SourcePath',''); addParameter(parser,'ReadOnly',false); ...
            addParameter(parser,'DisplayStyle',struct()); addParameter(parser,'Metadata',struct()); parse(parser,varargin{:});
            obj.Id=lmz.util.Ids.new('dataset'); obj.Name=name; obj.Branch=branch; obj.SourcePath=parser.Results.SourcePath; obj.ReadOnly=parser.Results.ReadOnly;
            obj.DisplayStyle=struct('Color',[0 0.447 0.741],'LineStyle','-','Marker','.');
            fields=fieldnames(parser.Results.DisplayStyle);for index=1:numel(fields),obj.DisplayStyle.(fields{index})=parser.Results.DisplayStyle.(fields{index});end
            obj.Metadata=parser.Results.Metadata;
        end
    end
end
