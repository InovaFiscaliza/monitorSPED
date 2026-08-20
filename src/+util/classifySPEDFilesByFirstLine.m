function [fileType, has0000, reason] = classifySPEDFilesByFirstLine(filePath)
% classifySPEDFilesByFirstLine
% Classifica arquivos SPED (ECD, ECF, EFD contribuições, EFD ICMS/IPI)
% pela primeira linha (registro 0000).

    firstLine = readFirstLine(filePath);
    [fileType, has0000, reason] = classifyFirstLine(firstLine);
end

%-------------------------------------------------------------------------%
function firstLine = readFirstLine(filePath)
    firstLine = '';

    fid = fopen(filePath, 'r');
    if fid == -1
        return
    end

    cleaner = onCleanup(@() fclose(fid));
    firstLine = fgetl(fid);

    if ~ischar(firstLine)
        firstLine = '';
    end

    if ~isempty(firstLine) && firstLine(1) == char(65279)
        firstLine = firstLine(2:end);
    end

    clear cleaner
end

%-------------------------------------------------------------------------%
function [fileType, has0000, reason] = classifyFirstLine(firstLine)
    fileType = 'DESCONHECIDO';
    has0000 = false;
    %reason = '';

    if isempty(firstLine)
        reason = 'Primeira linha vazia ou nao legivel';
        return
    end

    % Preserva campos vazios internos para nao deslocar a posicao do CNPJ;
    % remove apenas os vazios de borda gerados pelos '|' inicial/final da linha.
    tokens = strsplit(strtrim(firstLine), '|', 'CollapseDelimiters', false);
    if ~isempty(tokens) && isempty(tokens{1})
        tokens(1) = [];
    end
    if ~isempty(tokens) && isempty(tokens{end})
        tokens(end) = [];
    end

    if isempty(tokens)
        reason = 'Sem campos para classificar';
        return
    end

    has0000 = strcmp(tokens{1}, '0000');
    if ~has0000
        reason = 'Primeiro registro diferente de 0000';
        return
    end

    if any(strcmpi(tokens, 'LECD'))
        fileType = 'ECD';
        reason = 'Campo LECD encontrado no registro 0000';
        return
    end

    if any(strcmpi(tokens, 'LECF'))
        fileType = 'ECF';
        reason = 'Campo LECF encontrado no registro 0000';
        return
    end

    cnpjIndex = 0;
    for ii = 1:numel(tokens)
        if isValidCNPJ(tokens{ii})
            cnpjIndex = ii;
            break
        end
    end

    switch cnpjIndex
        case 7
            fileType = 'EFD ICMS/IPI';
            reason = 'CNPJ valido no campo 7 do registro 0000';
        case 9
            fileType = 'EFD CONTRIBUIÇÕES';
            reason = 'CNPJ valido no campo 9 do registro 0000';
        case 0
            reason = 'Sem CNPJ valido no registro 0000';
        otherwise
            reason = sprintf('CNPJ valido em posicao nao mapeada (%d)', cnpjIndex);
    end
end

%-------------------------------------------------------------------------%
function tf = isValidCNPJ(rawValue)
    tf = false;

    if ~(ischar(rawValue) || isstring(rawValue))
        return
    end

    cnpj = regexprep(char(rawValue), '[^0-9]', '');
    if numel(cnpj) ~= 14
        return
    end

    if isscalar(unique(cnpj))
        return
    end

    nums = double(cnpj) - 48;

    d1 = cnpjCheckDigit(nums(1:12), [5 4 3 2 9 8 7 6 5 4 3 2]);
    d2 = cnpjCheckDigit([nums(1:12) d1], [6 5 4 3 2 9 8 7 6 5 4 3 2]);

    tf = (nums(13) == d1) && (nums(14) == d2);
end

%-------------------------------------------------------------------------%
function digit = cnpjCheckDigit(values, weights)
    sumValue = sum(values .* weights);
    remainder = mod(sumValue, 11);

    if remainder < 2
        digit = 0;
    else
        digit = 11 - remainder;
    end
end
