classdef TestReadmeContract < matlab.unittest.TestCase
    methods (Test)
        function contractIsCurrent(~)
            check_readme_contract();
        end
    end
end
