function write_deterministic_zip(sourceRoot,relativeFiles,archivePath,archiveRoot)
%WRITE_DETERMINISTIC_ZIP ZIP sorted files with a fixed 2000-01-01 timestamp.
relativeFiles=sort(release_cellstr(relativeFiles));
folder=fileparts(archivePath);
if exist(folder,'dir')~=7,mkdir(folder);end
stream=java.util.zip.ZipOutputStream(java.io.BufferedOutputStream( ...
    java.io.FileOutputStream(archivePath)));
cleanup=onCleanup(@()closeStream(stream));
stream.setLevel(9);
fixedTime=946684800000;
for index=1:numel(relativeFiles)
    relative=relativeFiles{index};
    entryName=strrep(fullfile(archiveRoot,relative),'\','/');
    entry=java.util.zip.ZipEntry(entryName);
    entry.setTime(fixedTime);
    stream.putNextEntry(entry);
    fid=fopen(fullfile(sourceRoot,strrep(relative,'/',filesep)),'rb');
    if fid<0,error('lmz:Release:ZipReadFailed','Cannot read %s.',relative);end
    fileCleanup=onCleanup(@()fclose(fid));
    while true
        bytes=fread(fid,65536,'*uint8');
        if isempty(bytes),break,end
        stream.write(typecast(bytes(:),'int8'),0,numel(bytes));
    end
    clear fileCleanup
    stream.closeEntry();
end
stream.finish();stream.close();clear cleanup
end

function closeStream(stream)
try,stream.close();catch,end
end
