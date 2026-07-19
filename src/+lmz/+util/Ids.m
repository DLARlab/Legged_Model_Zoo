classdef Ids
    methods (Static)
        function value=new(prefix)
            persistent counter
            if isempty(counter), counter=0; end
            counter=counter+1;
            value=sprintf('%s-%s-%06d',prefix,datestr(now,'yyyymmddTHHMMSSFFF'),counter);
        end
    end
end
