function recreateRTF(rawContent, fileName)
    arguments
        rawContent (1,:) char
        fileName   (1,:) char
    end

    content = strtrim(rawContent);

    isBase64 = 'unknown';
    if isRTF(content)
        isBase64 = 'false';
        encoding = Encoding(content);
    else
        base64Pattern = '^[A-Za-z0-9+/=\s\r\n]+$';
        if ~isempty(regexp(content, base64Pattern, 'once'))
            try
                base64Content = matlab.net.base64decode(content);
                encoding = Encoding(char(base64Content));
                content  = native2unicode(base64Content, encoding);

                if isRTF(content)
                    isBase64 = 'true';
                end
            catch
            end
        end
    end

    if strcmp(isBase64, 'unknown')
        error('InvalidFileContent:InputError', 'Invalid file content: not RTF or Base64 RTF');
    end

    writematrix(content, fileName, "FileType", "text", "QuoteStrings", "none", "Encoding", encoding);
end

%-------------------------------------------------------------------------%
function encoding = Encoding(content)
    encoding   = 'latin1';
    validation = regexp(content, '\\ansicpg(\d+)', 'tokens', 'once');
    if ~isempty(validation)
        codepage = str2double(validation{1});
        switch codepage
            case 65001, encoding = 'utf-8';
            otherwise,  encoding = sprintf('windows-%d', codepage);
        end
    end
end

%-------------------------------------------------------------------------%
function status = isRTF(content)
    status = startsWith(strtrim(content), '{\rtf', 'IgnoreCase', true);
end