function [category, note] = classifyApuradoCategory_old(description, monthlyBalances, totalBalance)
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
