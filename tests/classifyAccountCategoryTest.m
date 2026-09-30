function classifyAccountCategoryTest(inputFilename)
    arguments
        inputFilename char = 'C:\Users\anatel_master\Downloads\Contas de resultado anotadas.xlsx'
    end

    t = readtable(inputFilename, 'VariableNamingRule', 'preserve');

    desc  = string(t.('description'));
    total = t.('total');
    monthlyBalances = t{:, {'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'}};

    % Receita candidata de cada arquivo SPED (empresa + ano), como em model.ECD.
    fileId = string(t.('entityId')) + "|" + string(t.('periodYear'));
    [uFiles, ~, fileIndex] = unique(fileId);
    fileRevenueTotal = zeros(numel(uFiles), 1);
    
    parpoolCheck()
    parfor ii = 1:numel(uFiles)
        mask = fileIndex == ii;
        fileRevenueTotal(ii) = util.Classification.computeEntityRevenueTotal(desc(mask), total(mask)); %#ok<PFBNS>
    end
    entityRevenueTotal = fileRevenueTotal(fileIndex);

    % "-" e "Não" têm o mesmo significado (conta não vinculada à telecom).
    actual = strtrim(string(t.('auditorAccountType')));
    actual(actual == "-" | actual == "") = "Não";

    n = height(t);
    predictedOld = repmat("Não", n, 1);
    predictedNew = repmat("Não", n, 1);

    parfor ii = 1:n
        category = classifyAccountCategory_v1_00(desc(ii), monthlyBalances(ii, :), total(ii));
        if category ~= "-"
            predictedOld(ii) = category;
        end

        category = util.Classification.classifyAccountCategory(desc(ii), monthlyBalances(ii, :), total(ii), entityRevenueTotal(ii));
        if category ~= "-"
            predictedNew(ii) = category;
        end
    end

    t.apurado_old = predictedOld;
    t.apurado_novo = predictedNew;

    % Falso positivo: o auditor marcou "Não" e o algoritmo apontou categoria.
    status = repmat("Falso negativo", n, 1);
    status(actual == predictedNew) = "Verdadeiro positivo";
    status(actual == "Não" & predictedNew ~= "Não") = "Falso positivo";
    t.status_apurado_novo = status;

    categories = unique(actual);
    metrics = [ ...
        computeMetrics(actual, predictedOld, categories, 'old'); ...
        computeMetrics(actual, predictedNew, categories, 'novo') ...
    ];

    oldPrecision = metrics.acuracia_geral(find(strcmp(metrics.algoritmo, 'old'), 1));
    newPrecision = metrics.acuracia_geral(find(strcmp(metrics.algoritmo, 'novo'), 1));
    
    disp(metrics)
    fprintf('Acurácia geral: old = %.2f%% | novo = %.2f%%\n', 100 * oldPrecision, 100 * newPrecision);

    [outputFolder, outputName] = fileparts(inputFilename);
    writetable(t, fullfile(outputFolder, [outputName '_classificado.xlsx']));
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
function [category, note] = classifyAccountCategory_v1_00(description, monthlyBalances, totalBalance)
    % Algoritmo de autoFill anterior à calibração por dados (ver
    % util.classifyApuradoCategory), portado para a mesma assinatura
    % apenas para fins de comparação em tests/classifyApuradoCategoryTest.m.
    arguments
        description (1,1) string
        monthlyBalances (1,12) double
        totalBalance (1,1) double
    end

    category = "-";
    note = '';

    accountDescription = textAnalysis.normalizeWords(char(description));
    hasPositiveMonthlyBalance = all(monthlyBalances >= 0);

    % Identifica qual das descrições possuem as palavras 
    % "ICMS", "PIS" ou "COFINS", e qual delas aparece no 
    % final da descrição (e mais próxima da descrição da 
    % conta analítica sob análise).
    taxOptions    = {'icms', ' pis', 'cofins'};
    taxValidation = repmat({[]}, 1, 3);
    
    for jj = 1:numel(taxOptions)
        taxTempValidation = strfind(accountDescription, taxOptions{jj});
        if ~isempty(taxTempValidation)
            taxValidation{jj} = taxTempValidation(end);
        end
    end
    
    if ~isempty(cell2mat(taxValidation))
        taxValidationMax = max(cell2mat(taxValidation));
        taxValidationMaxIndex = find(cellfun(@(x) isequal(taxValidationMax, x), taxValidation), 1);

        switch taxValidationMaxIndex
            case 1 % ICMS
                category = "ICMS Telecom";
                note = '[auto] Descrição inclui termo "ICMS"';

            case 2 % PIS
                category = "PIS Telecom";
                note = '[auto] Descrição inclui termo "PIS"';

            case 3 % COFINS
                category = "COFINS Telecom";
                note = '[auto] Descrição inclui termo "COFINS"';
        end

        return
    end

    if totalBalance <= 0
        return
    end

    keywords = struct( ...
        'nonTelecom', {{'nao telecom', ' sva ', 'valor adicionado', 'valor adcionado', ' locacao', 'instalacao'}}, ...
        'telecom',    {{'telecom', 'servico', 'receita'}} ...
    );

    nonTelecomMatchMask   = cellfun(@(x) contains(accountDescription, x), keywords.nonTelecom);
    telecomTermsMatchMask = cellfun(@(x) contains(accountDescription, x), keywords.telecom);

    if any(nonTelecomMatchMask)
        nonTelecomWords = upper(strcat({'"'}, strtrim(keywords.nonTelecom(nonTelecomMatchMask)), {'"'}));
        if isscalar(nonTelecomWords)
            nonTelecomWords = char(nonTelecomWords);
            note = sprintf('[auto] Descrição inclui termo %s', nonTelecomWords);
        else
            nonTelecomWords = strjoin({strjoin(nonTelecomWords(1:end-1), ', '), nonTelecomWords{end}}, ' e ');
            note = sprintf('[auto] Descrição inclui termos %s', nonTelecomWords);
        end

        category = "Não";

    elseif sum(telecomTermsMatchMask) >= 2
        telecomWords = upper(strcat({'"'}, strtrim(keywords.telecom(telecomTermsMatchMask)), {'"'}));
        telecomWords = strjoin({strjoin(telecomWords(1:end-1), ', '), telecomWords{end}}, ' e ');

        if hasPositiveMonthlyBalance
            note = sprintf('[auto] Saldos mensais não negativos e descrição inclui termos %s', telecomWords);
        else
            note = sprintf('[auto] Saldo anual positivo e descrição inclui termos %s', telecomWords);
        end

        category = "Sim";
    end
end