function [fList, fNames] = getFilesFromFolder(folder, extension, tempFolder)
    arguments
        folder
        extension (1,:) char = '.txt'
        tempFolder  (1,:) char = ''
    end

    % INITIAL DIR
    d = dir(folder);
    d(ismember({d.name}, {'.', '..'})) = [];

    % OUTPUT FILE LIST
    fList = {};

    for ii = 1:numel(d)
        current = fullfile(d(ii).folder, d(ii).name);

        % try/catch to prevent errors from unzip function (or other unmapped 
        % functions)
        try
            if d(ii).isdir
                fList = [fList, util.getFilesFromFolder(current, extension, tempFolder)];    
            elseif endsWith(current, '.zip', 'IgnoreCase', true)
                tempZipFolder = getTempFolder(tempFolder);
                unzip(current, tempZipFolder);
                fList = [fList, util.getFilesFromFolder(tempZipFolder, extension, tempFolder)];    
            elseif endsWith(current, extension, 'IgnoreCase', true)
                fList{end+1} = current;
            end
        catch
        end
    end

    % KEEP ONLY UNIQUE VALUES
    [~, fNames, fExt] = fileparts(fList);
    [~, fIndexes] = unique(fNames, 'stable');
    fList = fList(fIndexes);

    fNames = strcat(fNames, fExt);
end

%-------------------------------------------------------------------------%
function tempFolder = getTempFolder(tempFolder)
    if isfolder(tempFolder)
        tempFolder = fullfile(tempFolder, char(matlab.lang.internal.uuid()));
    else
        tempFolder = tempname;
    end
end