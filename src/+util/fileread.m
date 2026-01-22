function [content, filesize, encoding, encodingJson, hashHex, bigFileWarning] = fileread(fileFullName, encodingList)
    arguments
        fileFullName (1,:) char
        encodingList (1,:) cell = {'ISO-8859-1', 'UTF-8'}
    end

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
    hashHex = Hash.sha1(byteArray);

    % Encoding detection
    encodingInfo = table( ...
        'Size', [0, 3], ...
        'VariableTypes', {'cell', 'double', 'double'}, ...
        'VariableNames', {'encoding', 'numSpecialCharsType', 'numSpecialChars'} ...
    );

    % A função native2unicode é limitada em 2^30-1 elementos.
    filesize = numel(byteArray);
    bigFileWarning = '';
    if filesize > 2^30-1
        bigFileWarning = sprintf('[native2unicode] Error using native2unicode. Input must contain fewer than 2^30 elements. %.0f elements ⇒ %.0f', numel(byteArray), 2^30-1);
    end

    for ii = 1:numel(encodingList)
        rawDecoded = lower(native2unicode(byteArray(1:min(filesize, 2^30-1)), encodingList{ii}));
        numSpecialChars = cellfun(@(x) numel(strfind(rawDecoded, x)), textAnalysis.specialMain);
        encodingInfo(end+1, :) = {encodingList{ii}, sum(numSpecialChars > 0), sum(numSpecialChars)};
    end
    encodingInfo = sortrows(encodingInfo, {'numSpecialCharsType', 'numSpecialChars'}, 'descend');
    
    encoding = encodingInfo.encoding{1};
    encodingJson = jsonencode(encodingInfo);

    if isempty(bigFileWarning)
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