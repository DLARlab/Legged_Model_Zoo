classdef FileHash
    %FILEHASH Binary file digests used by immutable data manifests.
    methods (Static)
        function value = sha256(path)
            fid = fopen(path,'rb');
            if fid < 0, error('lmz:FileHash:OpenFailed','Cannot open %s.',path); end
            cleanup = onCleanup(@()fclose(fid));
            digest = java.security.MessageDigest.getInstance('SHA-256');
            while true
                bytes = fread(fid,65536,'*uint8');
                if isempty(bytes), break, end
                digest.update(bytes);
            end
            raw = typecast(digest.digest(),'uint8');
            value = lower(reshape(dec2hex(raw,2).',1,[]));
            clear cleanup
        end
    end
end
