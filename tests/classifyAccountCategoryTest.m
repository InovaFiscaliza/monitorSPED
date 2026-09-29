function classifyAccountCategoryTest(inputFilename, inputFileType, descriptionScope)
    arguments
        inputFilename char = ''
        inputFileType {mustBeMember(inputFileType, {'Base bruta scarab', 'Auditorias válidas QlikSense'})} = 'Auditorias válidas QlikSense'
        descriptionScope {mustBeMember(descriptionScope, {'completa', 'ultimoNivel'})} = 'completa'
    end

    if isempty(inputFilename)
        inputFilename = defaultInputFilename(inputFileType);
    end

    % "Auditorias válidas QlikSense" não tem lançamentos mensais (só
    % entityId/description/auditorAccountType/total).
    hasMonthlyBalances = inputFileType == "Base bruta scarab";
    if hasMonthlyBalances
        t = readtable(inputFilename, 'VariableNamingRule', 'preserve', 'Sheet', 'CONTAS');
        t = removevars(t, {'correlationKey', 'entityName', 'entityState', 'entryHistoryCount', 'deduplicatedEntryHistory', 'periodYear', 'entitySelfDeclaration', 'auditorIcmsConfig'});
    else
        t = readtable(inputFilename, 'VariableNamingRule', 'preserve');
    end

    desc  = string(t.('description'));
    total = toNumeric(t.('total'));

    % "ultimoNivel" usa apenas o trecho após o último "↳" (nome da conta
    % analítica em si, sem as categorias superiores da hierarquia).
    classifyDesc = desc;
    if descriptionScope == "ultimoNivel"
        classifyDesc = extractLastLevel(desc);
    end

    % Receita candidata total de cada empresa (soma dos saldos positivos
    % das contas não-tributárias da MESMA empresa), usada por
    % util.classifyAccountCategory como sinal de magnitude para o termo
    % genérico da regra "Sim" (ver util.computeEntityRevenueTotal).
    entityId = string(t.('entityId'));
    [uEntities, ~, entityIndex] = unique(entityId);
    entityRevenueTotal = zeros(numel(uEntities), 1);
    parfor e = 1:numel(uEntities)
        mask = entityIndex == e;
        entityRevenueTotal(e) = util.computeEntityRevenueTotal(desc(mask), total(mask)); %#ok<PFBNS>
    end
    entityRevenueTotalPerRow = entityRevenueTotal(entityIndex);

    if hasMonthlyBalances
        months = {'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'};
        monthlyBalances = zeros(height(t), 12);
        for m = 1:12
            monthlyBalances(:, m) = toNumeric(t.(months{m}));
        end
    else
        monthlyBalances = zeros(height(t), 0);
    end

    % "-" e "Não" têm o mesmo significado para fins de análise (ambos
    % indicam conta não vinculada à receita/tributo de telecom).
    actualCollapsed = strtrim(string(t.('auditorAccountType')));
    actualCollapsed(actualCollapsed == "-" | actualCollapsed == "") = "Não";

    n = height(t);
    apuradoOld  = repmat("-", n, 1);
    apuradoNovo = repmat("-", n, 1);

    parpoolCheck()
    parfor ii = 1:n
        % O algoritmo v1.00 (baseline antigo) depende de lançamentos
        % mensais, indisponíveis em "Auditorias válidas QlikSense".
        if hasMonthlyBalances
            apuradoOld(ii) = classifyAccountCategory_v1_00(desc(ii), monthlyBalances(ii, :), total(ii));
            if apuradoOld(ii) == "-"
                apuradoOld(ii) = "Não";
            end
        end

        apuradoNovo(ii) = util.classifyAccountCategory(classifyDesc(ii), monthlyBalances(ii, :), total(ii), entityRevenueTotalPerRow(ii));
        if apuradoNovo(ii) == "-"
            apuradoNovo(ii) = "Não";
        end
    end

    t.apurado_novo = apuradoNovo;

    % "Não" é tratada como classe negativa: acerto (mesmo entre "Não"s)
    % é verdadeiro positivo; algoritmo aponta categoria indevida sobre
    % conta que é "Não" é falso positivo; demais divergências (conta com
    % categoria real não identificada corretamente) são falso negativo.
    statusApuradoNovo = repmat("Falso negativo", n, 1);
    statusApuradoNovo(actualCollapsed == apuradoNovo) = "Verdadeiro positivo";
    statusApuradoNovo(actualCollapsed == "Não" & apuradoNovo ~= "Não") = "Falso positivo";
    t.status_apurado_novo = statusApuradoNovo;

    categories = unique(actualCollapsed);
    metrics = computeMetrics(actualCollapsed, apuradoNovo, categories, ['novo_' descriptionScope]);

    if hasMonthlyBalances
        t.apurado_old = apuradoOld;
        metrics = [computeMetrics(actualCollapsed, apuradoOld, categories, 'old'); metrics];
    end

    [outputFolder, outputName] = fileparts(inputFilename);
    outputFilename = fullfile(outputFolder, [outputName '_classificado.xlsx']);
    writetable(t, outputFilename);

    disp(metrics)
end

%-------------------------------------------------------------------------%
function filename = defaultInputFilename(inputFileType)
    switch inputFileType
        case 'Base bruta scarab'
            filename = 'C:\Users\anatel_master\Downloads\appMonitorSPED.xlsx';
        case 'Auditorias válidas QlikSense'
            filename = 'C:\Users\anatel_master\Downloads\Contas de resultado anotadas.xlsx';
    end
end

%-------------------------------------------------------------------------%
function lastLevelDesc = extractLastLevel(desc)
    lastLevelDesc = strings(size(desc));
    for ii = 1:numel(desc)
        parts = strsplit(desc(ii), '↳');
        lastLevelDesc(ii) = strtrim(parts{end});
    end
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