function fileList = getFilesFromCompressedFile(initialFileList, tempFolder)
    arguments
        initialFileList
        tempFolder (1,:) char = ''
    end

    fileList = {};
    for ii = 1:numel(initialFileList)
        fileName = initialFileList{ii};

        if ~endsWith(fileName, '.sped', 'IgnoreCase', true)
            fileList{end+1} = initialFileList{ii};
            continue
        end

        tempZipFolder = getTempFolder(tempFolder);
        unzip(fileName, tempZipFolder);
        
        try
            if isfile(fullfile(tempZipFolder, '.metadados.xml'))
                tempFileMeta  = readstruct(fullfile(tempZipFolder, '.metadados.xml'));
                tempFileIndex = find([tempFileMeta.recurso.tipoAttribute] == "ESCRITURACAO");            
                tempFileName  = fullfile(tempZipFolder, tempFileMeta.recurso(tempFileIndex).idAttribute); % "string" como saída
            else
                tempFileDir   = dir(tempZipFolder);
                tempFileName  = fullfile(tempZipFolder, {tempFileDir.name});
                tempFileName(~endsWith(tempFileName, '.txt', 'IgnoreCase', true)) = []; % "cellstr" como saída
            end

            if ~iscellstr(tempFileName)
                tempFileName = cellstr(tempFileName);
            end

            for jj = 1:numel(tempFileName)
                if isfile(tempFileName{jj})
                    fileList{end+1} = tempFileName{jj};
                end
            end
        catch
        end
    end
end

%-------------------------------------------------------------------------%
function tempFolder = getTempFolder(tempFolder)
    if isfolder(tempFolder)
        tempFolder = fullfile(tempFolder, char(matlab.lang.internal.uuid()));
    else
        tempFolder = tempname;
    end
end