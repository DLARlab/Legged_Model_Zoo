classdef TestSafeInputBoundaries < matlab.unittest.TestCase
    methods (Test)
        function safeJsonRejectsMalformedOversizedAndEscapingPaths(testCase)
            folder = tempname; mkdir(folder);
            cleanup = onCleanup(@() removeTree(folder));
            malformed = fullfile(folder, 'malformed.json');
            writeText(malformed, '{not-json');
            testCase.verifyError(@() lmz.io.SafeJson.read(malformed), ...
                'lmz:Compatibility:InvalidJson');
            oversized = fullfile(folder, 'large.json');
            writeText(oversized, ['{"value":"' repmat('x', 1, 200) '"}']);
            testCase.verifyError(@() lmz.io.SafeJson.read(oversized, ...
                'MaximumBytes', 64), 'lmz:Json:TooLarge');
            outside = [tempname '.json'];
            outsideCleanup = onCleanup(@() deleteFile(outside));
            writeText(outside, '{"safe":true}');
            testCase.verifyError(@() lmz.io.SafeJson.read(outside, ...
                'Root', folder), 'lmz:Path:Traversal');
            clear outsideCleanup cleanup
        end

        function safeMatRejectsUnexpectedHandlesObjectsAndDimensionBombs(testCase)
            folder = tempname; mkdir(folder);
            cleanup = onCleanup(@() removeTree(folder));
            extraPath = fullfile(folder, 'extra.mat');
            expected = 1; unexpected = 2; %#ok<NASGU>
            save(extraPath, 'expected', 'unexpected');
            testCase.verifyError(@() lmz.io.SafeMat.loadVariables( ...
                extraPath, {'expected'}, 'ExactVariables', true), ...
                'lmz:Mat:UnexpectedVariable');

            handlePath = fullfile(folder, 'handle.mat');
            payload = struct('callback', @sin); %#ok<NASGU>
            save(handlePath, 'payload');
            testCase.verifyError(@() lmz.io.SafeMat.loadVariables( ...
                handlePath, {'payload'}), 'lmz:Mat:UnsafeType');

            objectPath = fullfile(folder, 'object.mat');
            payload = struct('object', containers.Map({'a'}, {1})); %#ok<NASGU>
            save(objectPath, 'payload');
            testCase.verifyError(@() lmz.io.SafeMat.loadVariables( ...
                objectPath, {'payload'}), 'lmz:Mat:UnsafeType');

            bombPath = fullfile(folder, 'bomb.mat');
            payload = sparse(1, 20000001); %#ok<NASGU>
            save(bombPath, 'payload');
            testCase.verifyError(@() lmz.io.SafeMat.loadVariables( ...
                bombPath, {'payload'}), 'lmz:Mat:Elements');
            clear cleanup
        end

        function boundedStringsAreAcceptedButFunctionHandlesInDataAreNot(testCase)
            folder = tempname; mkdir(folder);
            cleanup = onCleanup(@() removeTree(folder));
            safePath = fullfile(folder, 'string.mat');
            payload = struct('transition_type', "trot-to-run"); %#ok<NASGU>
            save(safePath, 'payload');
            loaded = lmz.io.SafeMat.loadVariables(safePath, {'payload'});
            testCase.verifyEqual(loaded.payload.transition_type, "trot-to-run");
            clear cleanup
        end
    end
end

function writeText(path, value)
file = fopen(path, 'w'); cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s', value); clear cleanup
end
function deleteFile(path), if exist(path, 'file') == 2, delete(path); end, end
function removeTree(path), if exist(path, 'dir') == 7, rmdir(path, 's'); end, end
