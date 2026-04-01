function [fuzzyUniqueList, totalCount] = deduplicateAccountEntryHistory(historyFormat, entryHistory)
    arguments
        historyFormat {mustBeMember(historyFormat, {'rawI250', 'aggregated'})}
        entryHistory 
    end

    switch historyFormat
        case 'rawI250'
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
            sumCounts = accumarray(ic, 1);
        
            % Ordena pelo mais frequente
            [countsSorted, sortOrder] = sort(sumCounts, 'descend');
            idxsSorted = idxs(sortOrder);
        
            % Concatena contagem com valor original
            entryHistoryCount = cellstr(replace(" (" + string(countsSorted) + "x)", " (1x)", ""));
        
            entryHistoryList  = entryHistory(idxsSorted);
            entryHistoryIdxs  = endsWith(entryHistoryList, ' ↳ ');
            entryHistoryList(entryHistoryIdxs) = replace(entryHistoryList(entryHistoryIdxs), ' ↳ ', '');

        case 'aggregated'
            wordList = {};
            counts = [];
        
            for ii = 1:numel(entryHistory)
                countToken = regexp(entryHistory{ii}, ' \((\d+)x\)$', 'tokens');
        
                if ~isempty(countToken)
                    wordList{end+1, 1} = strtrim(regexprep(entryHistory{ii}, ' \(\d+x\)$', ''));
                    counts(end+1, 1)   = str2double(countToken{1}{1});
                else
                    wordList{end+1, 1} = entryHistory{ii};
                    counts(end+1, 1)   = 1;                                            
                end
            end
    
            % Deduplica lista, mantendo ordem original
            [~, idxs, ic] = unique(lower(wordList), 'stable');
            sumCounts = accumarray(ic, counts);

            % Ordena pelo mais frequente
            [countsSorted, sortOrder] = sort(sumCounts, 'descend');
            idxsSorted = idxs(sortOrder);

            % Concatena contagem com valor original
            entryHistoryCount = cellstr(replace(" (" + string(countsSorted) + "x)", " (1x)", ""));
            entryHistoryList  = wordList(idxsSorted);
    end

    fuzzyUniqueList = strcat(entryHistoryList, entryHistoryCount);
    totalCount = sum(sumCounts);
end