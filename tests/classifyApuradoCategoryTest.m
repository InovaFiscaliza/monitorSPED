function [T, metrics] = classifyApuradoCategoryTest(inputFilename, outputFilename, maxRows)
    % Compara util.classifyApuradoCategory_old (algoritmo anterior) com
    % util.classifyApuradoCategory (algoritmo calibrado por dados) sobre a
    % planilha de contas anotadas, gravando as duas classificações lado a
    % lado ("apurado_old"/"apurado_novo") e as métricas de precisão/recall
    % de cada algoritmo.
    %
    % Aviso: com maxRows = Inf (padrão), o teste processa a planilha
    % inteira e pode levar dezenas de minutos, pois cada chamada aos
    % algoritmos depende de textAnalysis.normalizeWords (~30-40 ms/linha).
    % Use maxRows para iterações rápidas durante o desenvolvimento.
    arguments
        inputFilename char = 'C:\Users\anatel_master\Downloads\Contas anotadas.xlsx'
        outputFilename char = 'classifyApuradoCategoryTest.xlsx'
        maxRows double = Inf
    end

    addpath(fullfile(ProjectPath, 'src'));

    T = readtable(inputFilename, 'VariableNamingRule', 'preserve');
    if isfinite(maxRows)
        T = T(1:min(maxRows, height(T)), :);
    end

    desc  = string(T.('description'));
    total = toNumeric(T.('total'));

    months = {'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'};
    monthlyBalances = zeros(height(T), 12);
    for m = 1:12
        monthlyBalances(:, m) = toNumeric(T.(months{m}));
    end

    % "-" e "Não" têm o mesmo significado para fins de análise (ambos
    % indicam conta não vinculada à receita/tributo de telecom).
    actualCollapsed = strtrim(string(T.('auditorAccountType')));
    actualCollapsed(actualCollapsed == "-" | actualCollapsed == "") = "Não";

    n = height(T);
    apuradoOld  = repmat("-", n, 1);
    apuradoNovo = repmat("-", n, 1);

    for ii = 1:n
        apuradoOld(ii)  = util.classifyApuradoCategory_old(desc(ii), monthlyBalances(ii, :), total(ii));
        apuradoNovo(ii) = util.classifyApuradoCategory(desc(ii), monthlyBalances(ii, :), total(ii));
    end

    T.apurado_old  = apuradoOld;
    T.apurado_novo = apuradoNovo;

    categories = unique(actualCollapsed);
    metrics = [ ...
        computeMetrics(actualCollapsed, apuradoOld,  categories, 'old'); ...
        computeMetrics(actualCollapsed, apuradoNovo, categories, 'novo') ...
    ];

    disp(metrics)

    writetable(T,       outputFilename, "Sheet", "Contas",   "WriteMode", "replacefile")
    writetable(metrics, outputFilename, "Sheet", "Metricas", "WriteMode", "append")
end

%-------------------------------------------------------------------------%
function metrics = computeMetrics(actual, predicted, categories, algorithmName)
    numCategories = numel(categories);

    truePositive  = zeros(numCategories, 1);
    falsePositive = zeros(numCategories, 1);
    falseNegative = zeros(numCategories, 1);
    precision     = zeros(numCategories, 1);
    recall        = zeros(numCategories, 1);

    for ii = 1:numCategories
        tp = sum(actual == categories(ii) & predicted == categories(ii));
        fp = sum(actual ~= categories(ii) & predicted == categories(ii));
        fn = sum(actual == categories(ii) & predicted ~= categories(ii));

        truePositive(ii)  = tp;
        falsePositive(ii) = fp;
        falseNegative(ii) = fn;
        precision(ii)     = tp / max(tp + fp, 1);
        recall(ii)        = tp / max(tp + fn, 1);
    end

    coverage = sum(predicted ~= "-") / numel(predicted);
    accuracy = sum(actual == predicted) / numel(actual);

    metrics = table( ...
        repmat(string(algorithmName), numCategories, 1), categories(:), truePositive, falsePositive, falseNegative, precision, recall, ...
        repmat(coverage, numCategories, 1), repmat(accuracy, numCategories, 1), ...
        'VariableNames', {'algoritmo', 'categoria', 'vp', 'fp', 'fn', 'precisao', 'recall', 'cobertura_geral', 'acuracia_geral'} ...
    );
end

%-------------------------------------------------------------------------%
function out = toNumeric(col)
    if isnumeric(col)
        out = double(col);
        return
    end

    if iscell(col)
        out = zeros(numel(col), 1);
        for ii = 1:numel(col)
            v = col{ii};
            if isnumeric(v)
                out(ii) = double(v);
            elseif isempty(v)
                out(ii) = 0;
            else
                s = strtrim(string(v));
                s = replace(s, '.', '');
                s = replace(s, ',', '.');
                out(ii) = str2double(s);
            end
        end
        out(isnan(out)) = 0;
        return
    end

    out = str2double(string(col));
    out(isnan(out)) = 0;
end
