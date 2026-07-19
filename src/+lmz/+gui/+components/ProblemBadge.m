classdef ProblemBadge
    %PROBLEMBADGE Consistent user-facing maturity/validation labels.
    methods (Static)
        function value = label(descriptor)
            maturity = lmz.gui.components.ProblemBadge.field( ...
                descriptor,'maturity','experimental');
            validation = lmz.gui.components.ProblemBadge.field( ...
                descriptor,'validationStatus','untested');
            value = sprintf('%s • %s', ...
                lmz.gui.components.ProblemBadge.title(maturity), ...
                lmz.gui.components.ProblemBadge.validationLabel(validation));
        end

        function value = selectorLabel(descriptor)
            id = lmz.gui.components.ProblemBadge.field(descriptor,'id','problem');
            value = sprintf('%s — %s',id, ...
                lmz.gui.components.ProblemBadge.label(descriptor));
        end
    end

    methods (Static, Access=private)
        function value = field(source,name,fallback)
            if isstruct(source) && isfield(source,name)
                value = source.(name);
            else
                value = fallback;
            end
            if isstring(value), value = char(value); end
        end

        function value = title(text)
            if isempty(text), value = ''; return, end
            value = [upper(text(1)) strrep(text(2:end),'_',' ')];
        end

        function value = validationLabel(status)
            switch status
                case 'source-equivalent'
                    value = 'Source-equivalent';
                case 'tested'
                    value = 'Tested';
                otherwise
                    value = 'Untested';
            end
        end
    end
end
