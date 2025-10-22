function [content, encoding, encodingJson, hashHex] = fileread(fileFullName, encodingList)
    arguments
        fileFullName (1,:) char
        encodingList (1,:) cell = {'ISO-8859-1', 'UTF-8', 'windows-1251', 'windows-1252'}
    end

    varargout = {};

    fileID = fopen(fileFullName, 'r');
    if fileID == -1
        error('File not found.');
    end    
    byteArray = fread(fileID, [1, inf], 'uint8=>uint8');
    fclose(fileID);

    % HASH
    hashEndMarker = regexp(char(byteArray), '\|9999\|[^\r\n]*(?:\r?\n)?', 'match');    
    if ~isempty(hashEndMarker)
        hashEndMarkerPosition = strfind(byteArray, hashEndMarker{end}) + numel(hashEndMarker{end}) - 1;
        byteArray = byteArray(1:hashEndMarkerPosition);
    end    
    hashHex = calculateSHA1Hash(byteArray);

    % Encoding detection
    encodingInfo = table( ...
        'Size', [0, 3], ...
        'VariableTypes', {'cell', 'double', 'double'}, ...
        'VariableNames', {'encoding', 'numSpecialCharsType', 'numSpecialChars'} ...
    );

    for ii = 1:numel(encodingList)
        rawDecoded = native2unicode(byteArray, encodingList{ii});
        numSpecialChars = cellfun(@(x) numel(strfind(rawDecoded, x)), textAnalysis.specialChars);
        encodingInfo(end+1, :) = {encodingList{ii}, sum(numSpecialChars > 0), sum(numSpecialChars)};
    end
    encodingInfo = sortrows(encodingInfo, {'numSpecialCharsType', 'numSpecialChars'}, 'descend');
    
    encoding = encodingInfo.encoding{1};
    content  = native2unicode(byteArray, encoding);
    encodingJson = jsonencode(encodingInfo);
end

%-------------------------------------------------------------------------%
function hashHex = calculateSHA1Hash(byteArray)
    import System.Security.Cryptography.*
    sha1Provider  = SHA1Managed();
    
    bytes = numel(byteArray);
    index = 0;
    
    while index < bytes
        idx1 = index + 1;
        idx2 = min(index + 65536, bytes);
        
        tempData = byteArray(idx1:idx2);
        sha1Provider.TransformBlock(tempData, 0, numel(tempData), tempData, 0);
        
        index = idx2;
    end
    
    sha1Provider.TransformFinalBlock(uint8([]), 0, 0);    
    
    hashBytes = uint8(sha1Provider.Hash);
    hashHex   = lower(sprintf('%02x', hashBytes));
end