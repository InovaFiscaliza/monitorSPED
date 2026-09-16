function evaluateNewAlgorithm()
    addpath('C:\InovaFiscaliza\monitorSPED\src');

    filePath = 'C:\Users\anatel_master\Downloads\Contas anotadas.xlsx';
    T = readtable(filePath, 'VariableNamingRule', 'preserve');

    labels = strtrim(string(T.('auditorAccountType')));
    labelsCollapsed = labels;
    labelsCollapsed(labelsCollapsed == "-" | labelsCollapsed == "") = "Não";
    uCats = unique(labelsCollapsed);

    months = {'jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'};
    monthlyBalances = zeros(height(T), 12);
    for m = 1:12
        monthlyBalances(:, m) = toNumeric(T.(months{m}));
    end
    total = toNumeric(T.('total'));
    desc = string(T.('description'));

    % Amostragem para acelerar o backtest: mantém 100% das classes raras
    % (Sim/ICMS/PIS/COFINS Telecom) e uma amostra aleatória de "Não".
    rng(42);
    noMask = labelsCollapsed == "Não";
    noIdxs = find(noMask);
    sampleSize = min(2500, numel(noIdxs));
    sampledNoIdxs = noIdxs(randperm(numel(noIdxs), sampleSize));
    keepIdxs = sort([find(~noMask); sampledNoIdxs]);

    labelsCollapsed = labelsCollapsed(keepIdxs);
    monthlyBalances = monthlyBalances(keepIdxs, :);
    total = total(keepIdxs);
    desc = desc(keepIdxs);

    n = numel(keepIdxs);
    fprintf('Backtest sample size: %d (all non-"Não" + %d random "Não")\n\n', n, sampleSize);

    predicted = repmat("-", n, 1);
    for i = 1:n
        [category, ~] = util.classifyApuradoCategory(desc(i), monthlyBalances(i,:), total(i));
        predicted(i) = category;
    end

    fprintf('=== NEW ALGORITHM: coverage (non "-") ===\n');
    fprintf('Classified (non "-"): %d of %d (%.1f%%)\n\n', sum(predicted ~= "-"), n, 100*sum(predicted ~= "-")/n);

    fprintf('=== NEW ALGORITHM CONFUSION MATRIX (rows=actual, cols=predicted, "-" = absteve) ===\n');
    predCats = unique([uCats(:); "-"]);
    printConfusion(labelsCollapsed, predicted, uCats, predCats);
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

function printConfusion(actual, predicted, actualCats, predCats)
    nA = numel(actualCats);
    nP = numel(predCats);
    M = zeros(nA, nP);
    for i = 1:nA
        for j = 1:nP
            M(i,j) = sum(actual == actualCats(i) & predicted == predCats(j));
        end
    end
    fprintf('%-16s', 'actual\\pred');
    for j = 1:nP
        fprintf('%-16s', predCats(j));
    end
    fprintf('\n');
    for i = 1:nA
        fprintf('%-16s', actualCats(i));
        for j = 1:nP
            fprintf('%-16d', M(i,j));
        end
        fprintf('\n');
    end

    fprintf('\n');
    for i = 1:nA
        catIdxInPred = find(predCats == actualCats(i), 1);
        if isempty(catIdxInPred)
            continue
        end
        tp = M(i, catIdxInPred);
        fn = sum(M(i,:)) - tp;
        fp = sum(M(:,catIdxInPred)) - tp;
        precision = tp / max(tp+fp,1);
        recall = tp / max(tp+fn,1);
        fprintf('%-16s precision=%.2f%% recall=%.2f%% (tp=%d fp=%d fn=%d)\n', actualCats(i), 100*precision, 100*recall, tp, fp, fn);
    end

    correctMask = false(size(actual));
    for i = 1:numel(actual)
        correctMask(i) = actual(i) == predicted(i);
    end
    fprintf('\nOverall accuracy (against all rows, treating "-" as its own class): %.2f%%\n', 100*sum(correctMask)/numel(actual));
end
