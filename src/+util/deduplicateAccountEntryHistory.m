function fuzzyUniqueList = deduplicateAccountEntryHistory(entryHistory)
    % Converte para minúsculas
    wordList = lower(entryHistory);

    % Remove números e pontuação
    wordList = regexprep(wordList, '\d+', '');
    wordList = regexprep(wordList, '[^\w\s]', '');

    % Remove espaços no início/fim e múltiplos espaços internos
    wordList = strtrim(wordList);
    wordList = regexprep(wordList, '\s+', ' ');

    % Deduplica lista, mantendo ordem original
    [~, idxs, ic] = unique(wordList, 'stable');
    counts = accumarray(ic, 1);

    % Ordena pelo mais frequente
    [countsSorted, sortOrder] = sort(counts, 'descend');
    idxsSorted = idxs(sortOrder);

    % Concatena contagem com valor original
    entryHistoryCount = cellstr(replace(" (" + string(countsSorted) + "x)", " (1x)", ""));
    fuzzyUniqueList = strcat(entryHistory(idxsSorted), entryHistoryCount);
end