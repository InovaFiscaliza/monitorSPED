function [filePathList, fileNameList] = getFilesFromPathList(inputPathList, tempFolder, expectedExt)
    arguments
        inputPathList cell
        tempFolder (1,:) char
        expectedExt = []
    end

    filePathList = {};
    fileNameList = {};
    
    idx = 1;
    while true
        currentPath = inputPathList{idx};

        if isfolder(currentPath)
            dirEntries = dir(currentPath);
            dirEntries(ismember({dirEntries.name}, {'.', '..'})) = [];

            if ~isempty(dirEntries)
                inputPathList = [inputPathList, fullfile(dirEntries(1).folder, {dirEntries.name})];
            end

        else
            [~, ~, fileExt] = fileparts(currentPath);
            
            if ~isempty(fileExt) && any(contains({'.sped', '.zip'}, fileExt, 'IgnoreCase', true))
                tempExtractFolder = getTempFolder(tempFolder);
        
                try
                    unzip(currentPath, tempExtractFolder);
    
                    switch lower(fileExt)
                        case '.sped'
                            metadataFilePath = fullfile(tempExtractFolder, '.metadados.xml');

                            if isfile(metadataFilePath)
                                metadataStruct = readstruct(metadataFilePath);
                                fileIdxs = find([metadataStruct.recurso.tipoAttribute] == "ESCRITURACAO");            
                                extractedFileNames = fullfile(tempExtractFolder, [metadataStruct.recurso(fileIdxs).idAttribute]); % "string" como saída
                            else
                                tempDirEntries     = dir(tempExtractFolder);
                                extractedFileNames = fullfile(tempExtractFolder, {tempDirEntries.name});
                                extractedFileNames(~endsWith(extractedFileNames, '.txt', 'IgnoreCase', true)) = []; % "cellstr" como saída
                            end
                
                            if ~iscellstr(extractedFileNames)
                                extractedFileNames = cellstr(extractedFileNames);
                            end
                
                            for jj = 1:numel(extractedFileNames)
                                if isfile(extractedFileNames{jj})
                                    filePathList{end+1} = extractedFileNames{jj};
                                end
                            end
    
                        case '.zip'
                            nestedFileList = util.getFilesFromPathList({tempExtractFolder}, tempFolder);
                            filePathList = [filePathList, nestedFileList];
                    end    
                catch
                end

            else
                filePathList{end+1} = inputPathList{idx};
            end
        end
        
        idx = idx+1;
        if idx > numel(inputPathList)
            break
        end
    end

    if ~isempty(filePathList)
        [~, fileBaseNameList, fileExtList] = fileparts(filePathList);        
        fileNameWithExtList = strcat(fileBaseNameList, fileExtList);
        [fileNameList, fileNameIdxs] = unique(fileNameWithExtList, 'stable');
        filePathList = filePathList(fileNameIdxs);
        fileExtList  = fileExtList(fileNameIdxs);
        
        if ~isempty(expectedExt)
            matchesExpectedExt = ismember(lower(fileExtList), lower(expectedExt));    
            filePathList = filePathList(matchesExpectedExt);
            fileNameList = fileNameList(matchesExpectedExt);
        end
    end
end

%-------------------------------------------------------------------------%
function tempFolder = getTempFolder(baseTempFolder)
    if isfolder(baseTempFolder)
        tempFolder = fullfile(baseTempFolder, char(matlab.lang.internal.uuid()));
    else
        tempFolder = tempname;
    end
end