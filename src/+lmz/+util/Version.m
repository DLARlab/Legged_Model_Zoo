classdef Version
    %VERSION Framework and persistent-format version contract.
    %   Version values follow Semantic Versioning 2.0.0. Build metadata is
    %   intentionally ignored for precedence comparisons.
    methods (Static)
        function value = current()
            persistent frameworkVersion
            if isempty(frameworkVersion)
                path = fullfile(lmz.util.ProjectPaths.root(), 'VERSION');
                if exist(path, 'file') ~= 2
                    error('lmz:Version:MissingFile', ...
                        'Framework VERSION file is missing: %s', path);
                end
                frameworkVersion = strtrim(fileread(path));
                lmz.util.Version.parse(frameworkVersion);
            end
            value = frameworkVersion;
        end

        function value = parse(text)
            text = lmz.util.Version.toCharacterVector(text);
            build = {};
            plus=find(text=='+');
            if numel(plus)>1,error('lmz:Version:InvalidSemanticVersion','Invalid semantic version: %s',text);end
            precedence=text;
            if ~isempty(plus)
                buildText=text(plus+1:end);precedence=text(1:plus-1);
                build=lmz.util.Version.identifiers(buildText,text,false);
            end
            prerelease={};dash=find(precedence=='-',1);
            core=precedence;
            if ~isempty(dash)
                prereleaseText=precedence(dash+1:end);core=precedence(1:dash-1);
                prerelease=lmz.util.Version.identifiers(prereleaseText,text,true);
            end
            expression='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$';
            parts = regexp(core, expression, 'tokens', 'once');
            if isempty(parts)
                error('lmz:Version:InvalidSemanticVersion', ...
                    'Invalid semantic version: %s', text);
            end
            value = struct('Major', str2double(parts{1}), ...
                'Minor', str2double(parts{2}), ...
                'Patch', str2double(parts{3}), ...
                'Prerelease', {prerelease}, 'Build', {build}, ...
                'Original', text);
        end

        function value = compare(left, right)
            left = lmz.util.Version.parse(left);
            right = lmz.util.Version.parse(right);
            leftNumbers = [left.Major left.Minor left.Patch];
            rightNumbers = [right.Major right.Minor right.Patch];
            difference = find(leftNumbers ~= rightNumbers, 1);
            if ~isempty(difference)
                value = sign(leftNumbers(difference) - rightNumbers(difference));
                return
            end
            value = lmz.util.Version.comparePrerelease( ...
                left.Prerelease, right.Prerelease);
        end

        function value = isCompatible(actualVersion, requiredVersion)
            if nargin < 2
                requiredVersion = actualVersion;
                actualVersion = lmz.util.Version.current();
            end
            actual = lmz.util.Version.parse(actualVersion);
            required = lmz.util.Version.parse(requiredVersion);
            sameCompatibilityLine = actual.Major == required.Major;
            if required.Major == 0
                sameCompatibilityLine = sameCompatibilityLine && ...
                    actual.Minor == required.Minor;
            end
            value = sameCompatibilityLine && ...
                lmz.util.Version.compare(actualVersion, requiredVersion) >= 0;
        end

        function value = artifactSchemaVersion()
            value = '1.0.0';
        end

        function value = catalogSchemaVersion()
            value = '1.0.0';
        end

        function value = minimumMatlabRelease()
            % Compatibility target, not a claim of runtime execution.
            value = 'R2019b';
        end
    end

    methods (Static, Access=private)
        function value = comparePrerelease(left, right)
            if isempty(left) && isempty(right), value = 0; return, end
            if isempty(left), value = 1; return, end
            if isempty(right), value = -1; return, end
            count = min(numel(left), numel(right));
            for index = 1:count
                first = left{index};
                second = right{index};
                firstNumeric = ~isempty(regexp(first, '^[0-9]+$', 'once'));
                secondNumeric = ~isempty(regexp(second, '^[0-9]+$', 'once'));
                if firstNumeric && secondNumeric
                    firstNumber = str2double(first);
                    secondNumber = str2double(second);
                    if firstNumber ~= secondNumber
                        value = sign(firstNumber - secondNumber);
                        return
                    end
                elseif firstNumeric ~= secondNumeric
                    if firstNumeric, value = -1; else, value = 1; end
                    return
                elseif ~strcmp(first, second)
                    pair = sort({first, second});
                    if strcmp(first, pair{1}), value = -1; else, value = 1; end
                    return
                end
            end
            value = sign(numel(left) - numel(right));
        end

        function value = toCharacterVector(value)
            if isstring(value) && isscalar(value), value = char(value); end
            if ~ischar(value) || size(value, 1) ~= 1 || isempty(value)
                error('lmz:Version:InvalidSemanticVersion', ...
                    'Version must be a nonempty character vector or string scalar.');
            end
        end

        function values=identifiers(value,original,rejectLeadingZeros)
            if isempty(value)||isempty(regexp(value, ...
                    '^[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*$','once'))
                error('lmz:Version:InvalidSemanticVersion', ...
                    'Invalid semantic version: %s',original);
            end
            values=strsplit(value,'.');
            if rejectLeadingZeros
                for index=1:numel(values)
                    identifier=values{index};
                    if ~isempty(regexp(identifier,'^[0-9]+$','once'))&& ...
                            numel(identifier)>1&&identifier(1)=='0'
                        error('lmz:Version:InvalidSemanticVersion', ...
                            'Numeric prerelease identifiers cannot have leading zeros: %s',original);
                    end
                end
            end
        end
    end
end
