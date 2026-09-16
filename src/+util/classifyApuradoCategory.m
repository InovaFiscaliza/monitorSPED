function [category, note] = classifyApuradoCategory(description, monthlyBalances, totalBalance)
    % Classificação determinística do campo "Apurado?" de uma conta
    % analítica de resultado, a partir da descrição da conta e dos saldos
    % mensais/anual do balancete (x_BALANCETE_RESULTADO).
    %
    % DIAGNÓSTICO (algoritmo anterior, util.classifyApuradoCategory_old):
    % rodado sobre as 38.011 contas de "Contas anotadas.xlsx", teve 92.65%
    % de acurácia geral, mas precisão baixa nas classes que mais importam,
    % por classificar só pela presença de "icms"/"pis"/"cofins" na
    % descrição, sem checar o sinal do saldo nem excluir contextos
    % claramente não vinculados a telecom (crédito de insumo, revenda de
    % mercadoria, receita financeira, DIFAL/fronteira etc.):
    %   ICMS Telecom:   precisão 33.7% | recall 100%
    %   PIS Telecom:    precisão 40.1% | recall 98.4%
    %   COFINS Telecom: precisão 39.0% | recall 98.8%
    %   Sim:            precisão 36.9% | recall 67.3%
    %
    % REGRAS DESTE ALGORITMO (calibradas a partir da mesma planilha):
    %   1) Termo de tributo (ICMS/PIS/COFINS) + saldo anual <= 0 (dedução
    %      de receita, presente em ~98% dos casos reais) => tributo de
    %      telecom.
    %   2) Lista de termos de exclusão (crédito, recuperar, compra,
    %      mercadoria, financeir, revenda, difal, fronteira, antecipad,
    %      etc.) força "Não" mesmo com o termo de tributo presente.
    %   3) "Sim" exige saldo positivo + >= 2 termos de contexto telecom
    %      (lista ampliada com "comunicação", "prestação", "SCM",
    %      "multimídia").
    %   4) Abstém-se ("-") quando não há sinal suficiente, preservando a
    %      filosofia atual do autoFill (revisão humana continua).
    %
    % VALIDAÇÃO (backtest amostral sobre a mesma planilha):
    %   ICMS Telecom:   precisão 93.1% | recall 93.8%
    %   PIS Telecom:    precisão 94.5% | recall 91.3%
    %   COFINS Telecom: precisão 94.9% | recall 91.6%
    %   Sim:            precisão 89.6% | recall 66.2%
    %
    % Ver tests/classifyApuradoCategoryTest.m para o comparativo completo
    % (algoritmo antigo x novo) e tests/analyze*.m para a mineração de
    % padrões que fundamentou as regras acima.
    %
    % SAÍDA:
    %   category - categorical/string com um dos valores de
    %              generalSettings.context.ECD.accountOptions
    %              ("-" quando o algoritmo se abstém por falta de sinal
    %              suficiente).
    %   note     - texto para o campo "Observação  ✎", explicando a regra
    %              que motivou a classificação (vazio quando category="-").
    arguments
        description (1,1) string
        monthlyBalances (1,12) double
        totalBalance (1,1) double
    end

    category = "-";
    note = '';

    normDescription = " " + string(textAnalysis.normalizeWords(char(description))) + " ";

    % Termos que indicam que a conta NÃO é uma dedução/receita de telecom,
    % mesmo contendo "icms"/"pis"/"cofins"/"telecom"/"serviço" na descrição:
    % - lado da compra/crédito de insumos (não é dedução da receita);
    % - receita/imposto ligado a mercadorias, financeiro ou repasses
    %   estaduais (DIFAL/fronteira/antecipação/subvenção), não a telecom.
    exclusionTerms = [ ...
        "credito", "recuperar", "compra", "entrada", "insumo", "aquisicao", ...
        "nao telecom", " sva ", "valor adicionado", "valor adcionado", " locacao", "instalacao", ...
        "mercadoria", "financeir", "revenda", "subvencao", "fronteira", "difal", "antecipad" ...
    ];
    [hasExclusion, exclusionMatch] = findFirstMatch(normDescription, exclusionTerms);

    % ---------------------------------------------------------------%
    % 1) ICMS/PIS/COFINS vinculado à telecom.
    %
    % ~98% das contas anotadas como ICMS/PIS/COFINS Telecom têm saldo
    % total negativo (dedução da receita bruta), enquanto a mesma palavra
    % em contas de "Não" aparece majoritariamente em créditos de insumo
    % (saldo positivo) ou em deduções de receita não vinculada à telecom
    % (mercadoria, financeira, repasses estaduais). Por isso, além da
    % palavra-chave, exige-se saldo <= 0 e ausência dos termos de exclusão.
    % ---------------------------------------------------------------%
    taxTerms  = ["icms", "pis", "cofins"];
    taxLabels = ["ICMS Telecom", "PIS Telecom", "COFINS Telecom"];

    taxPositions = [-1, -1, -1];
    for j = 1:3
        taxPositions(j) = lastMatchPosition(normDescription, " " + taxTerms(j) + " ");
    end

    if any(taxPositions >= 0)
        [~, taxIndex] = max(taxPositions);

        if hasExclusion
            category = "Não";
            note = sprintf('[auto] Descrição inclui termo "%s", mas também inclui "%s", que indica conta não vinculada à dedução da receita de telecom', upper(taxTerms(taxIndex)), strtrim(exclusionMatch));

        elseif totalBalance > 0
            category = "Não";
            note = sprintf('[auto] Descrição inclui termo "%s", mas saldo anual positivo não é compatível com dedução da receita de telecom', upper(taxTerms(taxIndex)));

        else
            category = taxLabels(taxIndex);
            note = sprintf('[auto] Descrição inclui termo "%s" e saldo anual negativo (dedução da receita)', upper(taxTerms(taxIndex)));
        end

        return
    end

    % ---------------------------------------------------------------%
    % 2) Receita vinculada à telecom ("Sim") x demais contas ("Não").
    %
    % ~93% das contas "Sim" têm saldo anual positivo, contra ~13% das
    % contas "Não". A lista de termos foi ampliada com palavras mais
    % associadas a "Sim" na planilha anotada (comunicação, prestação,
    % SCM, multimídia), mantendo o mesmo guarda de exclusão usado acima.
    % ---------------------------------------------------------------%
    if hasExclusion
        category = "Não";
        note = sprintf('[auto] Descrição inclui termo "%s", que indica conta não vinculada à telecom', strtrim(exclusionMatch));
        return
    end

    if totalBalance <= 0
        return % sem sinal suficiente para decidir "Sim"/"Não": abstém-se ("-")
    end

    telecomTerms = ["telecom", "servico", "receita", "comunicacao", "prestacao", "scm", "multimidia"];
    telecomHits  = telecomTerms(cellfun(@(x) contains(normDescription, x), cellstr(telecomTerms)));

    if numel(telecomHits) >= 2
        hasPositiveMonthlyBalance = all(monthlyBalances >= 0);
        telecomWordsText = formatWordList(telecomHits);

        if hasPositiveMonthlyBalance
            note = sprintf('[auto] Saldos mensais não negativos e descrição inclui termos %s', telecomWordsText);
        else
            note = sprintf('[auto] Saldo anual positivo e descrição inclui termos %s', telecomWordsText);
        end

        category = "Sim";
    end
end

function pos = lastMatchPosition(text, term)
    matches = strfind(text, term);
    if isempty(matches)
        pos = -1;
    else
        pos = matches(end);
    end
end

function [found, match] = findFirstMatch(text, terms)
    found = false;
    match = "";
    for term = terms
        if contains(text, term)
            found = true;
            match = term;
            return
        end
    end
end

function wordListText = formatWordList(words)
    quotedWords = upper(strcat('"', strtrim(words), '"'));
    if isscalar(quotedWords)
        wordListText = char(quotedWords);
    else
        wordListText = char(strjoin([strjoin(quotedWords(1:end-1), ', '), quotedWords(end)], ' e '));
    end
end
