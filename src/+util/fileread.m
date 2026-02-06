function [content, fileSize, encoding, encodingJson, hashHex, largeFileWarning] = fileread(fileFullName, generalSettings)
    arguments
        fileFullName (1,:) char
        generalSettings
    end

    fileID = fopen(fileFullName, 'r');
    if fileID == -1
        error('util:fileread:FileNotFound', 'File not found')
    end    
    byteArray = fread(fileID, [1, inf], 'uint8=>uint8');
    fclose(fileID);

    % Hash
    hashEndMarker = regexp(char(byteArray), '\|9999\|[^\r\n]*(?:\r?\n)?', 'match');
    if ~isempty(hashEndMarker)
        hashEndMarkerPosition = strfind(byteArray, hashEndMarker{end}) + numel(hashEndMarker{end}) - 1;
        byteArray = byteArray(1:hashEndMarkerPosition);
    end
    hashHex = Hash.sha1(byteArray);

    % A função native2unicode é limitada em 2^30-1 elementos...
    fileSize = numel(byteArray);
    native2unicodeLimit = 2^30-1; % bytes

    largeFileWarning = '';
    if fileSize > native2unicodeLimit
        largeFileWarning = sprintf([ ...
            'O arquivo excede %.0f bytes e, por isso, é tratado como grande, ' ...
            'com leitura e processamento realizados de forma diferenciada.' ...
        ], native2unicodeLimit);
    end

    % Infere codificação de texto por meio da identificação dos principais dos
    % caracteres especiais do Português: "ç", "ã", "á", "é", "í", "ó" e "ú'".
    encodingInfo = table( ...
        'Size', [0, 3], ...
        'VariableTypes', {'cell', 'double', 'double'}, ...
        'VariableNames', {'encoding', 'numSpecialCharsType', 'numSpecialChars'} ...
    );

    encodingList = generalSettings.context.FILE.encodingList;
    encodingDetectionBytes = min([fileSize, generalSettings.context.FILE.encodingDetectionBytes, native2unicodeLimit]);

    for ii = 1:numel(encodingList)
        rawDecoded = lower(native2unicode(byteArray(1:encodingDetectionBytes), encodingList{ii}));
        numSpecialChars = cellfun(@(x) numel(strfind(rawDecoded, x)), textAnalysis.specialMain);
        encodingInfo(end+1, :) = {encodingList{ii}, sum(numSpecialChars > 0), sum(numSpecialChars)};
    end
    encodingInfo = sortrows(encodingInfo, {'numSpecialCharsType', 'numSpecialChars'}, 'descend');
    
    encoding = encodingInfo.encoding{1};
    encodingJson = jsonencode(encodingInfo);

    if isempty(largeFileWarning)
        content = native2unicode(byteArray, encoding);
    else
        content = fileread(fileFullName, 'Encoding', encoding);
        hashEndMarker = regexp(content, '\|9999\|[^\r\n]*(?:\r?\n)?', 'match');
        if ~isempty(hashEndMarker)
            hashEndMarkerPosition = strfind(content, hashEndMarker{end}) + numel(hashEndMarker{end}) - 1;
            content = content(1:hashEndMarkerPosition);
        end
    end
end