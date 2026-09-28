function total = computeEntityRevenueTotal(descriptions, totals)
    % Soma dos saldos anuais positivos de todas as contas de uma mesma
    % empresa (arquivo SPED) que não sejam claramente contas de
    % ICMS/PIS/COFINS, usada como referência de "receita candidata total
    % da empresa" para o critério de magnitude de util.classifyAccountCategory
    % (ver rule 4 no cabeçalho daquela função).
    %
    % `descriptions`/`totals` devem conter TODAS as contas de UMA mesma
    % empresa (não misturar empresas diferentes), pois o valor retornado
    % é usado como denominador de "fração da receita da empresa" por
    % conta, e só faz sentido dentro do universo de contas de uma única
    % empresa (cada arquivo SPED processado pelo autoFill já é de uma
    % única empresa por vez).
    arguments
        descriptions (:,1) string
        totals (:,1) double
    end

    n = numel(descriptions);
    isCandidate = false(n, 1);
    taxTerms = [" icms ", " pis ", " cofins "];

    for ii = 1:n
        normDescription = " " + string(textAnalysis.normalizeWords(char(descriptions(ii)))) + " ";
        isCandidate(ii) = totals(ii) > 0 && ~any(contains(normDescription, taxTerms));
    end

    total = sum(totals(isCandidate));
end
