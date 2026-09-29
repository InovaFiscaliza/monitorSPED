function [category, note] = classifyAccountCategory(description, monthlyBalances, totalBalance, entityRevenueTotal)
    % Classificação determinística do campo "Apurado?" de uma conta
    % analítica de resultado, além de preenchimento do campo 
    % "Observação  ✎".
    %
    % Como referência para construção do algoritmo, utilizou-se a 
    % planilha "appMonitorSPED.xlsx", de 28/09/2026, composta por 
    % 42.103 contas anotadas. Trata-se de plnilha gerado pelo scarab 
    % por meio da agregação de auditorias contábeis.
    %
    % O algoritmo implantado na versão 1.00 do monitorSPED teve 92.83%
    % de acurácia geral, mas precisão baixa nas classes que mais importam.
    % Por conta disso, as regras deste algoritmo foram construídas com 
    % foco em reduzir falsos positivos, mesmo que isso implique em menor 
    % recall.
    %
    % Regras:
    %   1) Termo de tributo (ICMS/PIS/COFINS) + saldo anual <= 0 (dedução
    %      de receita, presente em ~98% dos casos reais) => tributo de
    %      telecom. Regras 1-2 avaliam a DESCRIÇÃO COMPLETA da conta
    %      (todos os níveis hierárquicos).
    %   2) Lista de termos de exclusão (crédito, recuperar, compra,
    %      mercadoria, financeir, revenda, difal, fronteira, antecipad,
    %      alíquota, subst[ituição], estadual, comércio etc.) força "Não"
    %      mesmo com o termo de tributo presente. "Alíquota"/"subst" cobre
    %      DIFAL/ICMS-ST fora do padrão "difal" (ex.: "Dif.Alíquota",
    %      "SUBST. ENT. INTERESTADUAL"), a maior fonte de falsos positivos
    %      de ICMS.
    %   3) "Sim" usa uma lista de exclusão própria, mais enxuta que a da
    %      regra 2 (só crédito/dedução/não-operacional claros), e aceita:
    %      Regra 3 (e sua lista de exclusão) avalia apenas o ÚLTIMO NÍVEL
    %      hierárquico da descrição (trecho após o último "↳", nome da
    %      conta em si), que se mostrou mais preciso para esse fim do que
    %      a descrição completa (ver VALIDAÇÃO).
    %        a) termo forte de telecom (lista ampliada: telecom,
    %           comunicação, SCM, multimídia, telefonia, internet, banda
    %           larga, STFC, voz, TV por assinatura, acesso à internet,
    %           cabo, interconexão, linha dedicada) — sempre vence a
    %           exclusão, pois cada termo foi vetado individualmente
    %           (proporção Sim: Não favorável no dado real) antes de
    %           entrar na lista; não está sujeito ao critério de
    %           magnitude da regra 4;
    %        b) termo de receita típica de telecom (SVA, locação,
    %           instalação, revenda, mercadoria), desde que sem termo de
    %           exclusão e sujeito ao critério de magnitude da regra 4;
    %        c) termo genérico de receita ("serviço"/"receita"/
    %           "prestação"), desde que sem termo de exclusão, sem termo
    %           de negócio claramente não-telecom (streaming, software,
    %           engenharia, brinde etc.) e sujeito ao critério de
    %           magnitude da regra 4.
    %   4) Critério de magnitude (aplicado a b/c da regra 3, mas não a
    %      a/strongHits): a conta precisa representar pelo menos 0.1% da
    %      receita candidata total da empresa (`entityRevenueTotal`) —
    %      contas de receita real de telecom concentram uma fatia bem
    %      maior da receita total da empresa do que contas de receita
    %      genérica/lateral (aluguel, outras receitas etc.), mesmo quando
    %      o texto das duas é parecido ou até coincide (termo de receita
    %      típica presente). Quando `entityRevenueTotal` não é informado
    %      (0, valor padrão), a regra 4 é ignorada — comportamento
    %      conservador para chamadores antigos.
    %   5) Abstém-se ("-") quando não há sinal suficiente, preservando a
    %      filosofia atual do autoFill (revisão humana continua).
    %
    % VALIDAÇÃO (ver tests/classifyAccountCategoryTest.m)
    % Em números relativos:
    % • COFINS: precisão aumentou de 39.9% para 65.9% (↑ 26.0%) | recall diminuiu de  98.9% para 90.9% (↓  8.0%)
    % • ICMS  : precisão aumentou de 33.8% para 59.4% (↑ 25.6%) | recall diminuiu de 100.0% para 89.3% (↓ 10.7%)
    % • PIS   : precisão aumentou de 40.9% para 64.6% (↑ 23.7%) | recall diminuiu de  98.6% para 90.6% (↓  8.0%)
    % • Sim   : precisão aumentou de 38.1% para 66.7% (↑ 28.5%) | recall diminuiu de  69.4% para 69.3% (↓  0.1%)
    %
    % Em números absolutos:
    % • COFINS:   330 verdadeiros positivos, 171 falsos positivos e  33 falsos negativos
    % • ICMS  :   293 verdadeiros positivos, 200 falsos positivos e  35 falsos negativos
    % • PIS   :   327 verdadeiros positivos, 179 falsos positivos e  34 falsos negativos
    % • Sim   :   638 verdadeiros positivos, 319 falsos positivos e 283 falsos negativos
    %
    % Acurácia geral: 97.04% (descrição completa para tributos + último
    % nível para "Sim"/"Não" + critério de magnitude em b/c, mas não em a;
    % melhor resultado entre as variâncias testadas — descrição completa
    % para tudo: 96.62%; último nível para tudo: 96.72%; híbrido sem
    % magnitude em a/b: 96.90%; híbrido com magnitude em a/b/c: 97.02%;
    % baseline v1.00: 92.83%).

    arguments
        description (1,1) string
        monthlyBalances double {mustBeMonthlyBalances}
        totalBalance (1,1) double
        entityRevenueTotal (1,1) double = 0
    end

    category = "-";
    note = '';

    % "pt_eng" remove preposições/conectivos (de, para, com etc.), o que
    % permite enxugar termos compostos (ver singularizeCommonWords e a
    % simplificação da lista de "venda ... produto/mercadoria" abaixo).
    % A detecção de tributo (ICMS/PIS/COFINS) usa a descrição completa da
    % conta, mas a classificação "Sim"/"Não" usa só o último nível
    % hierárquico (trecho após o último "↳", nome da conta em si), que se
    % mostrou mais preciso para esse propósito (ver tests/classifyAccountCategoryTest.m).
    normDescription = string(textAnalysis.normalizeWords(char(description), 'pt_eng'));
    normDescription = singularizeCommonWords(normDescription);
    paddedDescription = " " + normDescription + " ";

    normLastLevel = string(textAnalysis.normalizeWords(char(extractLastLevel(description)), 'pt_eng'));
    normLastLevel = singularizeCommonWords(normLastLevel);
    paddedLastLevel = " " + normLastLevel + " ";

    % ---------------------------------------------------------------%
    % ICMS/PIS/COFINS
    % ---------------------------------------------------------------%
    taxExclusionTerms = [ ...
        "credito", "recuperar", "compra", "entrada", "insumo", "aquisicao", ...
        "nao telecom", " sva ", "valor adicionado", "valor adcionado", " locacao", "instalacao", ...
        "mercadoria", "financeir", "revenda", "subvencao", "fronteira", "difal", "antecipad", ...
        "aliquota", "subst", "estadual", "comercio", ...
        "custo", "despesa" ...
    ];
    
    [hasExclusion, exclusionMatch] = findFirstMatch(paddedDescription, taxExclusionTerms);
    
    taxTerms  = ["icms", "pis", "cofins"];
    taxLabels = ["ICMS Telecom", "PIS Telecom", "COFINS Telecom"];

    taxPositions = [-1, -1, -1];
    for ii = 1:3
        taxPositions(ii) = lastMatchPosition(paddedDescription, " " + taxTerms(ii) + " ");
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
    % Receita vinculada à telecom ("Sim") e demais contas ("Não")
    % ---------------------------------------------------------------%
    telecomExclusionTerms = [ ...
        "credito", "recuperar", "compra", "insumo", "aquisicao", ...
        "nao telecom", "financeir", "subvencao", "fronteira", "difal", "antecipad", ...
        "aliquota", "subst", "estadual", "comercio", ...
        "outras receita", "receita diversas", "receita diversa", "alienacao", "imobilizado", ...
        "equivalencia patrimonial", "permuta", "sucata", "recuperacao despesa", "multa", ...
        "custo", "despesa", "provisao", "reversao", ...
        "venda produto", "venda mercadoria", "demais servicos", "outros servicos" ...
    ];

    [hasSimExclusion, simExclusionMatch] = findFirstMatch(paddedLastLevel, telecomExclusionTerms);

    if totalBalance <= 0
        return
    end

    telecomStrongTerms = [ ...
        "telecom", "comunicacao", "scm", "multimidia", ...
        "telefonia", "internet", "banda larga", "stfc", " voz ", "tv assinatura", "seac", ...
        "acesso a internet", "cabo", "interconexao", "linha dedicada", "link", "fttc", "ftth", "fttp", "ftts" ...
    ];

    telecomRevenueTerms = [ ...
        "sva", "valor adicionado", " locacao", "instalacao", "revenda", "mercadoria" ...
    ];
    
    telecomSupportTerms = [ ...
        "servico", "receita", "prestacao" ...
    ];
    
    nonTelecomBusinessTerms = [ ...
        "streaming", "musica", "software", "licenciamento", ...
        "representacao comercial", "venda produto", "periodico", "informatica", ...
        "vod", "engenharia", "brinde" ...
    ];

    strongHits   = findMatchingTerms(paddedLastLevel, telecomStrongTerms);
    revenueHits  = findMatchingTerms(paddedLastLevel, telecomRevenueTerms);
    supportHits  = findMatchingTerms(paddedLastLevel, telecomSupportTerms);
    hasNonTelecomBusiness = ~isempty(findMatchingTerms(paddedLastLevel, nonTelecomBusinessTerms));

    % Fração que o saldo desta conta representa na receita candidata
    % total da empresa (soma de todas as contas de saldo positivo que não
    % sejam ICMS/PIS/COFINS no mesmo arquivo SPED, calculada uma única vez
    % por empresa em util.computeEntityRevenueTotal). Contas de receita
    % "de verdade" de uma operadora de telecom concentram uma fatia bem
    % maior da receita da empresa do que contas de receita
    % genérica/lateral (aluguel, outras receitas, etc.), mesmo quando o
    % texto das duas é parecido ("serviço"/"receita"/"prestação"). Usada
    % como critério ADICIONAL para os termos de receita típica e
    % genéricos (regra 3b/3c); não se aplica a strongHits (regra 3a, que
    % sempre vence a exclusão) nem dispensa a lista de exclusão.
    revenueShareThreshold = 0.001;
    revenueShare = 0;
    if entityRevenueTotal > 0
        revenueShare = totalBalance / entityRevenueTotal;
    end

    % Sem entityRevenueTotal (chamador antigo), o critério de magnitude
    % é ignorado (comportamento conservador, ver comentário acima).
    hasSufficientMagnitude = entityRevenueTotal <= 0 || revenueShare >= revenueShareThreshold;

    if ~isempty(strongHits)
        telecomHits = [strongHits, revenueHits, supportHits];

    elseif hasSimExclusion
        category = "Não";
        note = sprintf('[auto] Descrição inclui termo "%s", que indica conta não vinculada à telecom', strtrim(simExclusionMatch));
        return
    
    elseif ~isempty(revenueHits) && hasSufficientMagnitude
        telecomHits = [revenueHits, supportHits];
    
    elseif ~isempty(supportHits) && ~hasNonTelecomBusiness && hasSufficientMagnitude
        telecomHits = supportHits;
    
    else
        return
    end

    telecomWordsText = formatWordList(telecomHits);

    % Sem monthlyBalances (ex.: base "Auditorias válidas QlikSense", sem
    % lançamentos mensais), usa-se apenas o saldo anual na observação.
    if ~isempty(monthlyBalances) && all(monthlyBalances >= 0)
        note = sprintf('[auto] Saldos mensais não negativos e descrição inclui termos %s', telecomWordsText);
    else
        note = sprintf('[auto] Saldo anual positivo e descrição inclui termos %s', telecomWordsText);
    end

    category = "Sim";
end

%-----------------------------------------------------------------%
function lastLevelText = extractLastLevel(description)
    parts = strsplit(description, '↳');
    lastLevelText = strtrim(string(parts{end}));
end

%-----------------------------------------------------------------%
function mustBeMonthlyBalances(x)
    % Aceita [] (base sem lançamentos mensais, ex.: "Auditorias válidas
    % QlikSense") ou um vetor 1x12 (um saldo por mês).
    if ~isempty(x) && ~isequal(size(x), [1 12])
        error('classifyAccountCategory:invalidMonthlyBalances', 'monthlyBalances deve ser vazio ([]) ou um vetor 1x12.');
    end
end

%-----------------------------------------------------------------%
function text = singularizeCommonWords(text)
    % Converte para singular palavras comuns cuja flexão de número, em
    % posição não-final de termos compostos (ex.: "vendas de produto"),
    % quebraria a comparação por substring contra a forma canônica
    % singular (ex.: "venda produto").
    pluralWords   = ["vendas", "produtos", "mercadorias", "receitas", "custos", "despesas"];
    singularWords = ["venda", "produto", "mercadoria", "receita", "custo", "despesa"];

    for ii = 1:numel(pluralWords)
        text = regexprep(text, ['\<' char(pluralWords(ii)) '\>'], char(singularWords(ii)));
    end
end

%-----------------------------------------------------------------%
function pos = lastMatchPosition(text, term)
    matches = strfind(text, term);
    if isempty(matches)
        pos = -1;
    else
        pos = matches(end);
    end
end

%-----------------------------------------------------------------%
function found = findMatchingTerms(text, termList)
    if isempty(termList)
        found = strings(1, 0);
        return
    end

    mask = cellfun(@(term) contains(text, term), cellstr(termList));
    found = termList(mask);
end

%-----------------------------------------------------------------%
function [found, match] = findFirstMatch(text, terms)
    matches = findMatchingTerms(text, terms);
    found = ~isempty(matches);
    match = "";
    if found
        match = matches(1);
    end
end

%-----------------------------------------------------------------%
function wordListText = formatWordList(words)
    quotedWords = upper(strcat('"', strtrim(words), '"'));
    if isscalar(quotedWords)
        wordListText = char(quotedWords);
    else
        wordListText = char(strjoin([strjoin(quotedWords(1:end-1), ', '), quotedWords(end)], ' e '));
    end
end