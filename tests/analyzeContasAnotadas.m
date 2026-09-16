function analyzeContasAnotadas()
    filePath = 'C:\Users\anatel_master\Downloads\Contas anotadas.xlsx';
    T = readtable(filePath, 'VariableNamingRule', 'preserve');
    fprintf('COLUMNS: %s\n', strjoin(string(T.Properties.VariableNames), ' | '));
    fprintf('ROWS: %d\n\n', height(T));

    labels = strtrim(string(T.('auditorAccountType')));
    labelsCollapsed = labels;
    labelsCollapsed(labelsCollapsed == "-" | labelsCollapsed == "") = "Não";

    uCats = unique(labelsCollapsed);
    fprintf('LABEL COUNTS (collapsed "-"+"Não"):\n');
    for i = 1:numel(uCats)
        fprintf('  %-16s -> %d\n', uCats(i), sum(labelsCollapsed == uCats(i)));
    end
    fprintf('\n');

    desc = normalizeText(string(T.('description')));
    comment = strtrim(string(T.('auditorComment')));
    comment(ismissing(comment)) = "";
    isAutoComment = startsWith(comment, "[auto]");
    fprintf('COMMENTS starting with "[auto]": %d of %d (%.1f%%)\n\n', sum(isAutoComment), height(T), 100*sum(isAutoComment)/height(T));

    months = {'jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'};
    monthlyBalances = zeros(height(T), 12);
    for m = 1:12
        monthlyBalances(:, m) = toNumeric(T.(months{m}));
    end
    total = toNumeric(T.('total'));

    % ---- Baseline: simulate current deterministic algorithm ----
    predicted = simulateCurrentAlgorithm(desc, monthlyBalances, total);
    fprintf('=== BASELINE (current algorithm logic) CONFUSION MATRIX ===\n');
    printConfusion(labelsCollapsed, predicted, uCats);

    % ---- Distinctive terms per class (description) ----
    fprintf('\n=== TOP DISTINCTIVE WORDS IN DESCRIPTION PER CLASS (score = P(word|class) - P(word|~class)) ===\n');
    for i = 1:numel(uCats)
        mask = labelsCollapsed == uCats(i);
        topW = topDistinctiveWords(desc(mask), desc(~mask), 15);
        fprintf('\n-- %s (n=%d) --\n', uCats(i), sum(mask));
        for r = 1:height(topW)
            fprintf('  %-20s score=%.4f  inClass=%d  outClass=%d\n', topW.word(r), topW.score(r), topW.inCount(r), topW.outCount(r));
        end
    end

    % ---- Distinctive terms in deduplicated entry history (non-auto comments excluded from bias, history is independent) ----
    if any(strcmp(T.Properties.VariableNames, 'deduplicatedEntryHistory'))
        histText = extractHistoryText(T.('deduplicatedEntryHistory'));
        histNorm = normalizeText(histText);
        fprintf('\n=== TOP DISTINCTIVE WORDS IN DEDUPLICATED ENTRY HISTORY PER CLASS ===\n');
        for i = 1:numel(uCats)
            mask = labelsCollapsed == uCats(i);
            topW = topDistinctiveWords(histNorm(mask), histNorm(~mask), 15);
            fprintf('\n-- %s (n=%d) --\n', uCats(i), sum(mask));
            for r = 1:height(topW)
                fprintf('  %-20s score=%.4f  inClass=%d  outClass=%d\n', topW.word(r), topW.score(r), topW.inCount(r), topW.outCount(r));
            end
        end
    end

    % ---- Balance sign pattern stats per class ----
    fprintf('\n=== MONTHLY BALANCE PATTERNS PER CLASS ===\n');
    for i = 1:numel(uCats)
        mask = labelsCollapsed == uCats(i);
        totalPositivePct = 100 * sum(total(mask) > 0) / sum(mask);
        allMonthsNonNegPct = 100 * sum(all(monthlyBalances(mask,:) >= 0, 2)) / sum(mask);
        totalZeroPct = 100 * sum(total(mask) == 0) / sum(mask);
        fprintf('  %-16s total>0: %.1f%%  allMonths>=0: %.1f%%  total==0: %.1f%%\n', uCats(i), totalPositivePct, allMonthsNonNegPct, totalZeroPct);
    end
end

function out = toNumeric(col)
    if isnumeric(col)
        out = double(col);
        return
    end
    if iscell(col)
        out = zeros(numel(col), 1);
        for i = 1:numel(col)
            v = col{i};
            if isnumeric(v)
                out(i) = double(v);
            elseif isempty(v)
                out(i) = 0;
            else
                s = strtrim(string(v));
                s = replace(s, '.', '');
                s = replace(s, ',', '.');
                out(i) = str2double(s);
            end
        end
        out(isnan(out)) = 0;
        return
    end
    out = str2double(string(col));
    out(isnan(out)) = 0;
end

function out = normalizeText(strArr)
    out = lower(strArr);
    out(ismissing(out)) = "";
    accentPairs = {'á','a';'à','a';'â','a';'ã','a';'é','e';'ê','e';'í','i';'î','i';'ó','o';'ô','o';'õ','o';'ú','u';'û','u';'ç','c'};
    for k = 1:size(accentPairs,1)
        out = replace(out, accentPairs{k,1}, accentPairs{k,2});
    end
    out = regexprep(out, '[^a-z0-9 ]', ' ');
    out = regexprep(out, '\s+', ' ');
    out = strtrim(out);
end

function txt = extractHistoryText(rawCell)
    n = numel(rawCell);
    txt = strings(n,1);
    for i = 1:n
        v = rawCell{i};
        if isempty(v)
            continue
        end
        try
            if ischar(v) || isstring(v)
                parsed = jsondecode(char(v));
            else
                parsed = v;
            end
            if iscell(parsed)
                txt(i) = strjoin(string(parsed), ' ');
            elseif isstring(parsed) || ischar(parsed)
                txt(i) = string(parsed);
            end
        catch
            txt(i) = string(v);
        end
    end
end

function topW = topDistinctiveWords(inClassText, outClassText, topN)
    stop = ["de","da","do","das","dos","e","a","o","as","os","em","para","com","no","na","por","sobre","ao","aos","um","uma","que","referente","ref","valor","valores","conta","contas","mes","meses"];

    [inWords, inCounts] = wordCounts(inClassText, stop);
    [outWords, outCounts] = wordCounts(outClassText, stop);

    allWords = unique([inWords; outWords]);
    inTotal = sum(inCounts); if inTotal == 0, inTotal = 1; end
    outTotal = sum(outCounts); if outTotal == 0, outTotal = 1; end

    inMap = containers.Map(cellstr(inWords), num2cell(inCounts));
    outMap = containers.Map(cellstr(outWords), num2cell(outCounts));

    score = zeros(numel(allWords),1);
    inC = zeros(numel(allWords),1);
    outC = zeros(numel(allWords),1);
    for i = 1:numel(allWords)
        w = cellstr(allWords(i));
        ci = 0; co = 0;
        if isKey(inMap, w{1}), ci = inMap(w{1}); end
        if isKey(outMap, w{1}), co = outMap(w{1}); end
        inC(i) = ci; outC(i) = co;
        if ci + co < 5
            score(i) = -Inf;
            continue
        end
        score(i) = (ci/inTotal) - (co/outTotal);
    end

    [sortedScore, idx] = sort(score, 'descend');
    n = min(topN, numel(idx));
    topW = table(allWords(idx(1:n)), sortedScore(1:n), inC(idx(1:n)), outC(idx(1:n)), 'VariableNames', {'word','score','inCount','outCount'});
end

function [words, counts] = wordCounts(textArr, stopwords)
    allWords = strings(0,1);
    for i = 1:numel(textArr)
        w = split(textArr(i));
        w = w(strlength(w) >= 3);
        allWords = [allWords; w(:)]; %#ok<AGROW>
    end
    allWords = allWords(~ismember(allWords, stopwords));
    if isempty(allWords)
        words = strings(0,1); counts = [];
        return
    end
    [words, ~, ic] = unique(allWords);
    counts = accumarray(ic, 1);
end

function predicted = simulateCurrentAlgorithm(desc, monthlyBalances, total)
    n = numel(desc);
    predicted = repmat("Não", n, 1);
    taxOptions = {'icms', ' pis', 'cofins'};
    taxLabels = ["ICMS Telecom", "PIS Telecom", "COFINS Telecom"];
    nonTelecomKw = {'nao telecom', ' sva ', 'valor adicionado', 'valor adcionado', ' locacao', 'instalacao'};
    telecomKw = {'telecom', 'servico', 'receita'};

    for i = 1:n
        d = char(" " + desc(i) + " ");
        taxPos = [-1 -1 -1];
        for j = 1:3
            p = strfind(d, taxOptions{j});
            if ~isempty(p)
                taxPos(j) = p(end);
            end
        end
        if any(taxPos >= 0)
            [~, j] = max(taxPos);
            predicted(i) = taxLabels(j);
            continue
        end

        if total(i) <= 0
            predicted(i) = "Não";
            continue
        end

        nonTelecomHit = any(cellfun(@(x) contains(d, x), nonTelecomKw));
        telecomHits = sum(cellfun(@(x) contains(d, x), telecomKw));

        if nonTelecomHit
            predicted(i) = "Não";
        elseif telecomHits >= 2
            predicted(i) = "Sim";
        else
            predicted(i) = "Não"; % abstained in real algorithm; treated as "Não" baseline here
        end
    end
end

function printConfusion(actual, predicted, cats)
    n = numel(cats);
    M = zeros(n,n);
    for i = 1:n
        for j = 1:n
            M(i,j) = sum(actual == cats(i) & predicted == cats(j));
        end
    end
    fprintf('%-16s', 'actual\\pred');
    for j = 1:n
        fprintf('%-16s', cats(j));
    end
    fprintf('\n');
    for i = 1:n
        fprintf('%-16s', cats(i));
        for j = 1:n
            fprintf('%-16d', M(i,j));
        end
        fprintf('\n');
    end

    correct = sum(diag(M));
    fprintf('\nOverall accuracy: %.2f%%\n', 100*correct/sum(M(:)));
    for i = 1:n
        tp = M(i,i);
        fn = sum(M(i,:)) - tp;
        fp = sum(M(:,i)) - tp;
        precision = tp / max(tp+fp,1);
        recall = tp / max(tp+fn,1);
        fprintf('%-16s precision=%.2f%% recall=%.2f%%\n', cats(i), 100*precision, 100*recall);
    end
end
