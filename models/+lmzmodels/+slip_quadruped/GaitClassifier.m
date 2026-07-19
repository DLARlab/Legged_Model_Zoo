classdef GaitClassifier
    %GAITCLASSIFIER Compatibility classification with stable display style.
    methods (Static)
        function value = classify(decision)
            if numel(decision) ~= 22 || any(~isfinite(decision(:)))
                error('lmz:slip_quadruped:GaitInput', ...
                    'Gait classification requires one finite 22-entry decision.');
            end
            [name, abbreviation, color, lineStyle] = ...
                lmzmodels.slip_quadruped.legacy.GaitIdentification(decision(:));
            value = struct('Name',char(name),'Abbreviation',char(abbreviation), ...
                'Color',color(:).','LineStyle',char(lineStyle), ...
                'Method','DLARlab Gait_Identification compatibility', ...
                'SourceCommit','2c106101383ecee1b2a9d695efe09fbd72d5718a');
        end
    end
end
