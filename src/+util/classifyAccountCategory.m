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
    %      telecom.
    %   2) Lista de termos de exclusão (crédito, recuperar, compra,
    %      mercadoria, financeir, revenda, difal, fronteira, antecipad,
    %      alíquota, subst[ituição], estadual, comércio etc.) força "Não"
    %      mesmo com o termo de tributo presente. "Alíquota"/"subst" cobre
    %      DIFAL/ICMS-ST fora do padrão "difal" (ex.: "Dif.Alíquota",
    %      "SUBST. ENT. INTERESTADUAL"), a maior fonte de falsos positivos
    %      de ICMS.
    %   3) "Sim" usa uma lista de exclusão própria, mais enxuta que a da
    %      regra 2 (só crédito/dedução/não-operacional claros), e aceita:
    %        a) termo forte de telecom (lista ampliada: telecom,
    %           comunicação, SCM, multimídia, telefonia, internet, banda
    %           larga, STFC, voz, TV por assinatura, acesso à internet,
    %           cabo, interconexão, linha dedicada) — sempre vence a
    %           exclusão, pois cada termo foi vetado individualmente
    %           (proporção Sim: Não favorável no dado real) antes de
    %           entrar na lista;
    %        b) termo de receita típica de telecom (SVA, locação,
    %           instalação, revenda, mercadoria), desde que sem termo de
    %           exclusão;
    %        c) termo genérico de receita ("serviço"/"receita"/
    %           "prestação"), desde que sem termo de exclusão, sem termo
    %           de negócio claramente não-telecom (streaming, software,
    %           engenharia, brinde etc.) E a conta represente pelo menos
    %           0.1% da receita candidata total da empresa
    %           (`entityRevenueTotal`) — regra 4, abaixo.
    %   4) Critério de magnitude (só usado para o termo genérico da regra
    %      3c): contas de receita real de telecom concentram uma fatia
    %      bem maior da receita total da empresa do que contas de receita
    %      genérica/lateral (aluguel, outras receitas etc.), mesmo quando
    %      o texto das duas é parecido. Sem esse filtro adicional, o
    %      termo genérico sozinho gera falsos positivos em volume maior
    %      que os acertos (ver análise abaixo). Quando `entityRevenueTotal`
    %      não é informado (obj. 0, valor padrão), a regra 3c nunca é
    %      aplicada — comportamento conservador para chamadores antigos.
    %   5) Abstém-se ("-") quando não há sinal suficiente, preservando a
    %      filosofia atual do autoFill (revisão humana continua).
    %
    % VALIDAÇÃO
    % Em números relativos:
    % • COFINS: precisão aumentou de 39.9% para 65.9% (↑ 26.0%) | recall diminuiu de  98.9% para 90.9% (↓  8.0%)
    % • ICMS  : precisão aumentou de 33.8% para 59.4% (↑ 25.6%) | recall diminuiu de 100.0% para 89.3% (↓ 10.7%)
    % • PIS   : precisão aumentou de 40.9% para 64.6% (↑ 23.7%) | recall diminuiu de  98.6% para 90.6% (↓  8.0%)
    % • Sim   : precisão aumentou de 38.1% para 51.6% (↑ 13.5%) | recall aumentou de  69.4% para 79.5% (↑ 10.1%)
    %
    % Em números absolutos:
    % • COFINS: 330 verdadeiros positivos, 171 falsos positivos e  33 falsos negativos
    % • ICMS  : 293 verdadeiros positivos, 200 falsos positivos e  35 falsos negativos
    % • PIS   : 327 verdadeiros positivos, 179 falsos positivos e  34 falsos negativos
    % • Sim   : 732 verdadeiros positivos, 687 falsos positivos e 189 falsos negativos

    arguments
        description (1,1) string
        monthlyBalances (1,12) double
        totalBalance (1,1) double
        entityRevenueTotal (1,1) double = 0
    end

    category = "-";
    note = '';

    normDescription = " " + string(textAnalysis.normalizeWords(char(description))) + " ";
    
    exclusionTerms = [ ...
        "credito", "recuperar", "compra", "entrada", "insumo", "aquisicao", ...
        "nao telecom", " sva ", "valor adicionado", "valor adcionado", " locacao", "instalacao", ...
        "mercadoria", "financeir", "revenda", "subvencao", "fronteira", "difal", "antecipad", ...
        "aliquota", "subst", "estadual", "comercio" ...
    ];
    
    [hasExclusion, exclusionMatch] = findFirstMatch(normDescription, exclusionTerms);

    % ---------------------------------------------------------------%
    % ICMS/PIS/COFINS
    % ---------------------------------------------------------------%
    taxTerms  = ["icms", "pis", "cofins"];
    taxLabels = ["ICMS Telecom", "PIS Telecom", "COFINS Telecom"];

    taxPositions = [-1, -1, -1];
    for ii = 1:3
        taxPositions(ii) = lastMatchPosition(normDescription, " " + taxTerms(ii) + " ");
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
    simExclusionTerms = [ ...
        "credito", "recuperar", "compra", "insumo", "aquisicao", ...
        "nao telecom", "financeir", "subvencao", "fronteira", "difal", "antecipad", ...
        "aliquota", "subst", "estadual", "comercio", ...
        "outras receita", "receitas diversas", "receita diversa", "alienacao", "imobilizado", ...
        "equivalencia patrimonial", "permuta", "sucata", "recuperacao de despesa", "multa", ...
        "custo", "despesa", "provisao", "reversao" ...
    ];

    [hasSimExclusion, simExclusionMatch] = findFirstMatch(normDescription, simExclusionTerms);

    if totalBalance <= 0
        return
    end

    strongTelecomTerms = [ ...
        "telecom", "comunicacao", "scm", "multimidia", ...
        "telefonia", "internet", "banda larga", "stfc", " voz ", "tv por assinatura", ...
        "acesso a internet", "cabo", "interconexao", "linha dedicada" ...
    ];

    revenueTerms = [ ...
        "sva", "valor adicionado", " locacao", "instalacao", "revenda", "mercadoria" ...
    ];
    
    supportTerms = [ ...
        "servico", "receita", "prestacao" ...
    ];
    
    nonTelecomBusinessTerms = [ ...
        "streaming", "musica", "software", "licenciamento", ...
        "representacao comercial", "venda de produto", "periodico", "informatica", ...
        "vod", "engenharia", "brinde" ...
    ];

    strongHits   = strongTelecomTerms(cellfun(@(x) contains(normDescription, x), cellstr(strongTelecomTerms)));
    revenueHits  = revenueTerms(cellfun(@(x) contains(normDescription, x), cellstr(revenueTerms)));
    supportHits  = supportTerms(cellfun(@(x) contains(normDescription, x), cellstr(supportTerms)));
    hasNonTelecomBusiness = any(cellfun(@(x) contains(normDescription, x), cellstr(nonTelecomBusinessTerms)));

    % Fração que o saldo desta conta representa na receita candidata
    % total da empresa (soma de todas as contas de saldo positivo que não
    % sejam ICMS/PIS/COFINS no mesmo arquivo SPED, calculada uma única vez
    % por empresa em util.computeEntityRevenueTotal). Contas de receita
    % "de verdade" de uma operadora de telecom concentram uma fatia bem
    % maior da receita da empresa do que contas de receita
    % genérica/lateral (aluguel, outras receitas, etc.), mesmo quando o
    % texto das duas é parecido ("serviço"/"receita"/"prestação"). Usada
    % só como critério ADICIONAL para termos genéricos (rule 4); não
    % dispensa a lista de exclusão nem substitui os termos fortes/receita.
    revenueShareThreshold = 0.001;
    revenueShare = 0;
    if entityRevenueTotal > 0
        revenueShare = totalBalance / entityRevenueTotal;
    end

    if ~isempty(strongHits)
        telecomHits = [strongHits, revenueHits, supportHits];

    elseif hasSimExclusion
        category = "Não";
        note = sprintf('[auto] Descrição inclui termo "%s", que indica conta não vinculada à telecom', strtrim(simExclusionMatch));
        return
    
    elseif ~isempty(revenueHits)
        telecomHits = [revenueHits, supportHits];
    
    elseif ~isempty(supportHits) && ~hasNonTelecomBusiness && revenueShare >= revenueShareThreshold
        telecomHits = supportHits;
    
    else
        return
    end

    hasPositiveMonthlyBalance = all(monthlyBalances >= 0);
    telecomWordsText = formatWordList(telecomHits);

    if hasPositiveMonthlyBalance
        note = sprintf('[auto] Saldos mensais não negativos e descrição inclui termos %s', telecomWordsText);
    else
        note = sprintf('[auto] Saldo anual positivo e descrição inclui termos %s', telecomWordsText);
    end

    category = "Sim";
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

%-----------------------------------------------------------------%
function wordListText = formatWordList(words)
    quotedWords = upper(strcat('"', strtrim(words), '"'));
    if isscalar(quotedWords)
        wordListText = char(quotedWords);
    else
        wordListText = char(strjoin([strjoin(quotedWords(1:end-1), ', '), quotedWords(end)], ' e '));
    end
end