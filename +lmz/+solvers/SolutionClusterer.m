classdef SolutionClusterer
    methods
        function [uniqueSolutions,labels]=cluster(~,solutions,scales,tolerance),if nargin<4,tolerance=1e-5;end;uniqueSolutions={};labels=zeros(1,numel(solutions));for i=1:numel(solutions),z=solutions{i}.Decision(:);assigned=false;for j=1:numel(uniqueSolutions),if norm((z-uniqueSolutions{j}.Decision(:))./scales(:))<=tolerance,labels(i)=j;assigned=true;break;end,end;if ~assigned,uniqueSolutions{end+1}=solutions{i};labels(i)=numel(uniqueSolutions);end,end,end
end
