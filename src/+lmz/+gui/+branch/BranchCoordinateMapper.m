classdef BranchCoordinateMapper
    %BRANCHCOORDINATEMAPPER Map plain branch/run data to active plot axes.
    methods (Static)
        function values=solutions(solutions,names)
            if iscell(solutions),solutions=[solutions{:}];end
            count=numel(solutions);values=nan(numel(names),count);
            for pointIndex=1:count
                for nameIndex=1:numel(names)
                    values(nameIndex,pointIndex)= ...
                        lmz.gui.branch.BranchCoordinateMapper.solution( ...
                        solutions(pointIndex),names{nameIndex});
                end
            end
        end

        function values=branch(branch,names)
            values=nan(numel(names),branch.pointCount());
            for index=1:numel(names)
                try
                    values(index,:)=branch.coordinate(names{index});
                catch
                end
            end
        end

        function values=decisions(decisions,reference,names)
            if isvector(decisions),decisions=decisions(:);end
            count=size(decisions,2);values=nan(numel(names),count);
            decisionNames=reference.DecisionSchema.names();
            parameterNames=reference.ParameterSchema.names();
            for nameIndex=1:numel(names)
                name=names{nameIndex};
                if any(strcmp(name,decisionNames))
                    values(nameIndex,:)=decisions( ...
                        reference.DecisionSchema.indexOf(name),:);
                elseif any(strcmp(name,parameterNames))
                    values(nameIndex,:)=reference.parameter(name);
                elseif isfield(reference.Observables,name)
                    values(nameIndex,:)=reference.Observables.(name);
                end
            end
        end

        function value=solution(solution,name)
            if any(strcmp(name,solution.DecisionSchema.names()))
                value=solution.decision(name);
            elseif any(strcmp(name,solution.ParameterSchema.names()))
                value=solution.parameter(name);
            elseif isfield(solution.Observables,name)
                value=solution.Observables.(name);
            else
                value=NaN;
            end
        end
    end
end
