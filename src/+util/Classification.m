classdef (Abstract) Classification

    % Classificação determinística de contas analíticas de resultado
    % obtidas da análise de Escrituração Contábil Digital (ECD).
    % Versão inicial, referenciada como "CLASSIFICADOR_LEGADO", esteve 
    % acessível no monitorSPED até a sua versão 1.01.11. A partir da 
    % versão 1.01.12, houve a substituição para a versão descrita neste
    % arquivo, referenciada como "CLASSIFICADOR_ATUAL".
    %
    % A classificação consiste na sugestão, para cada conta, de valores 
    % para as colunas "Apurado?  ✎" e "Observação  ✎" da tabela 
    % "_CONTAS_ANOTACAO".
    % • A coluna "Apurado?  ✎" é categórica, podendo receber os valores 
    %   definidos em "src/config/GeneralSettings.json", quais sejam:
    %   "-" | "Não" | "Sim" | "ICMS Telecom" | "PIS Telecom" | "COFINS Telecom"
    % • Por outro lado, a coluna "Observação  ✎" pode receber texto livre, 
    %   sendo utilizada para justificar a classificação da conta.
    %
    % DESEMPENHO CLASSIFICADOR_LEGADO X CLASSIFICADOR_ATUAL
    % (ver tests/classifyAccountCategoryTest.m)
    % Base: 29.587 contas anotadas por auditores.
    %
    % Em números relativos:
    % • COFINS: precisão aumentou de 42.8% para 75.0% (↑ 32.2%) | recall diminuiu de  98.9% para 89.4% (↓  9.5%)
    % • ICMS  : precisão aumentou de 37.3% para 84.2% (↑ 46.9%) | recall diminuiu de 100.0% para 87.4% (↓ 12.6%)
    % • PIS   : precisão aumentou de 44.1% para 72.4% (↑ 28.3%) | recall diminuiu de  98.1% para 89.0% (↓  9.1%)
    % • Sim   : precisão aumentou de 35.0% para 64.3% (↑ 29.3%) | recall aumentou de  71.9% para 74.2% (↑  2.3%)
    %
    % Em números absolutos (CLASSIFICADOR_ATUAL):
    % • COFINS: 237 verdadeiros positivos,  79 falsos positivos e  28 falsos negativos
    % • ICMS  : 208 verdadeiros positivos,  39 falsos positivos e  30 falsos negativos
    % • PIS   : 234 verdadeiros positivos,  89 falsos positivos e  29 falsos negativos
    % • Sim   : 489 verdadeiros positivos, 271 falsos positivos e 170 falsos negativos
    %
    % Acurácia geral: aumentou de 92.74% para 97.52% (↑ 4.8%)

    properties (Constant)
        %-----------------------------------------------------------------%
        TAX = struct( ...
            'ExclusionTerms', [ ...
                "credito", "recuperar", "compra", "entrada", "insumo", "aquisicao", ...
                "nao telecom", " sva ", "valor adicionado", "valor adcionado", " locacao", "instalacao", ...
                "mercadoria", "financeir", "revenda", "subvencao", "fronteira", "difal", "antecipad", ...
                "aliquota", "subst", "estadual", "comercio", ...
                "custo", "despesa" ...
            ], ...
            'StrongTerms', [ ...
                "icms", "pis", "cofins" ...
            ], ...
            'Categories', [ ...
                "ICMS Telecom", "PIS Telecom", "COFINS Telecom" ...
            ] ...
        )

        TELECOM = struct( ...
            'ExclusionTerms', [ ...
                "credito", "recuperar", "compra", "insumo", "aquisicao", ...
                "nao telecom", "financeir", "subvencao", "fronteira", "difal", "antecipad", ...
                "aliquota", "subst", "estadual", "comercio", ...
                "outras receita", "receita diversas", "receita diversa", "alienacao", "imobilizado", ...
                "equivalencia patrimonial", "permuta", "sucata", "recuperacao despesa", "multa", ...
                "custo", "despesa", "provisao", "reversao", ...
                "venda produto", "venda mercadoria", "demais servicos", "outros servicos" ...
            ], ...
            'StrongTerms', [ ...
                "telecom", "comunicacao", "scm", "multimidia", ...
                "telefonia", "internet", "banda larga", "stfc", " voz ", "tv assinatura", "seac", ...
                "acesso a internet", "cabo", "interconexao", "linha dedicada", "link", "fttc", "ftth", "fttp", "ftts" ...
            ], ...
            'RevenueTerms', [ ...
                "sva", "valor adicionado", " locacao", "instalacao", "revenda", "mercadoria" ...
            ], ...
            'SupportTerms', [ ...
                "servico", "receita", "prestacao" ...
            ], ...
            'NonTelecomBusinessTerms', [ ...
                "streaming", "musica", "software", "licenciamento", ...
                "representacao comercial", "venda produto", "periodico", "informatica", ...
                "vod", "engenharia", "brinde" ...
            ] ...
        )

        REVENUE_SHARE_THRESHOLD = 0.001
    end

    
    methods (Static)
        %-----------------------------------------------------------------%
        function [category, note] = classifyAccountCategory(description, monthlyBalances, totalBalance, entityRevenueTotal)
            arguments
                description (1,1) string
                monthlyBalances double
                totalBalance (1,1) double
                entityRevenueTotal (1,1) double = 0
            end

            if ~isempty(monthlyBalances) && ~isequal(size(monthlyBalances), [1 12])
                monthlyBalances = [];
            end

            category = "-";
            note = '';

            % Normaliza a descrição completa da conta, além de identificar 
            % o último nível.
            normDescription = textAnalysis.normalizeWords(description, 'pt_eng');
            normDescription = util.Classification.singularizeCommonWords(normDescription);
            paddedDescription = " " + normDescription + " ";

            normLastLevel = textAnalysis.normalizeWords(util.Classification.extractLastLevel(description), 'pt_eng');
            normLastLevel = util.Classification.singularizeCommonWords(normLastLevel);
            paddedLastLevel = " " + normLastLevel + " ";

            % Classificação de contas relacionadas a tributos: 
            % "ICMS Telecom" | "PIS Telecom" | "COFINS Telecom"
            [hasTaxExclusion, taxExclusionMatch] = util.Classification.findFirstMatch(paddedDescription, util.Classification.TAX.ExclusionTerms);

            taxTerms = util.Classification.TAX.StrongTerms;
            taxPositions = [-1, -1, -1];
            for ii = 1:3
                taxPositions(ii) = util.Classification.lastMatchPosition(paddedDescription, " " + taxTerms(ii) + " ");
            end

            if any(taxPositions >= 0)
                [~, taxIndex] = max(taxPositions);

                if hasTaxExclusion
                    category = "Não";
                    note = sprintf('[auto] Descrição inclui termo "%s", mas também inclui "%s", que indica conta não vinculada à dedução da receita de telecom', upper(taxTerms(taxIndex)), strtrim(taxExclusionMatch));

                elseif totalBalance > 0
                    category = "Não";
                    note = sprintf('[auto] Descrição inclui termo "%s", mas saldo anual positivo não é compatível com dedução da receita de telecom', upper(taxTerms(taxIndex)));

                else
                    category = util.Classification.TAX.Categories(taxIndex);
                    note = sprintf('[auto] Descrição inclui termo "%s" e saldo anual negativo (dedução da receita)', upper(taxTerms(taxIndex)));
                end

                return
            end

            % Classificação de contas relacionadas a receitas de telecomunicações:
            % "Sim" | "Não"
            [hasTelecomExclusion, telecomExclusionMatch] = util.Classification.findFirstMatch(paddedLastLevel, util.Classification.TELECOM.ExclusionTerms);

            if totalBalance <= 0
                return
            end

            strongHits = util.Classification.findMatchingTerms(paddedLastLevel, util.Classification.TELECOM.StrongTerms);
            revenueHits = util.Classification.findMatchingTerms(paddedLastLevel, util.Classification.TELECOM.RevenueTerms);
            supportHits = util.Classification.findMatchingTerms(paddedLastLevel, util.Classification.TELECOM.SupportTerms);
            hasNonTelecomBusiness = ~isempty(util.Classification.findMatchingTerms(paddedLastLevel, util.Classification.TELECOM.NonTelecomBusinessTerms));

            % A magnitude complementa os termos de receita típica/genéricos,
            % mas não filtra os termos fortes previamente validados.
            revenueShare = 0;
            if entityRevenueTotal > 0
                revenueShare = totalBalance / entityRevenueTotal;
            end
            hasSufficientMagnitude = entityRevenueTotal <= 0 || revenueShare >= util.Classification.REVENUE_SHARE_THRESHOLD;

            if ~isempty(strongHits)
                telecomHits = [strongHits, revenueHits, supportHits];

            elseif hasTelecomExclusion
                category = "Não";
                note = sprintf('[auto] Descrição inclui termo "%s", que indica conta não vinculada à telecom', strtrim(telecomExclusionMatch));
                return

            elseif ~isempty(revenueHits) && hasSufficientMagnitude
                telecomHits = [revenueHits, supportHits];

            elseif ~isempty(supportHits) && ~hasNonTelecomBusiness && hasSufficientMagnitude
                telecomHits = supportHits;

            else
                return
            end

            telecomWordsText = util.Classification.formatWordList(telecomHits);

            if ~isempty(monthlyBalances) && all(monthlyBalances >= 0)
                note = sprintf('[auto] Saldos mensais não negativos e descrição inclui termos %s', telecomWordsText);
            else
                note = sprintf('[auto] Saldo anual positivo e descrição inclui termos %s', telecomWordsText);
            end

            category = "Sim";
        end

        %-----------------------------------------------------------------%
        function total = computeEntityRevenueTotal(descriptions, totals)
            % Soma saldos positivos de uma única empresa, excluindo contas
            % cuja descrição identifica ICMS/PIS/COFINS.
            arguments
                descriptions (:,1) string
                totals (:,1) double
            end

            n = numel(descriptions);
            isCandidate = false(n, 1);
            taxTerms = [" icms ", " pis ", " cofins "];

            for ii = 1:n
                normDescription = " " + textAnalysis.normalizeWords(descriptions(ii)) + " ";
                isCandidate(ii) = totals(ii) > 0 && ~any(contains(normDescription, taxTerms));
            end

            total = sum(totals(isCandidate));
        end
    end


    methods (Static, Access = private)
        %-----------------------------------------------------------------%
        function lastLevelText = extractLastLevel(description)
            parts = strsplit(description, '↳');
            lastLevelText = strtrim(parts(end));
        end

        %-----------------------------------------------------------------%
        function text = singularizeCommonWords(text)
            pluralWords = ["vendas", "produtos", "mercadorias", "receitas", "custos", "despesas"];
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
            matches = util.Classification.findMatchingTerms(text, terms);
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
    end
end