classdef (Abstract) TableGenerator

    methods (Static = true)
        %-----------------------------------------------------------------%
        function accountMonthlySummary = SummaryByAccount(ecdObj)
            checkIfScalar(ecdObj)

            parseTableAndAddToCache(ecdObj, {'I050', 'I200_I250'})
            if ~isfield(ecdObj.Table, 'xI200') || isempty(ecdObj.Table.xI200)
                error(['Não foram encontrados lançamentos contábeis (I200) nesta escrituração. ' ...
                       'Isso indica que a empresa provavelmente está inativa, sem movimentação fiscal.'])
            end

            % Aplica filtros na tabela de fatos contábeis (I200_I250), de forma 
            % que sejam considerados apenas os lançamentos "NORMAIS". Além
            % disso, cria-se coluna "VL_DC_COM_SINAL".
            mergedTable_I200_I250 = ecdObj.Table.mI200_I250;
            mergedTable_I200_I250.("VL_DC_COM_SINAL") = mergedTable_I200_I250.("VL_DC");
            negativeValueIndexes = find(strcmp(mergedTable_I200_I250.("IND_DC"), 'D'));
            mergedTable_I200_I250.("VL_DC_COM_SINAL")(negativeValueIndexes) = -mergedTable_I200_I250.("VL_DC_COM_SINAL")(negativeValueIndexes);
            unnormalEntryIndexes = ~strcmp(mergedTable_I200_I250.("IND_LCTO"), 'N');
            mergedTable_I200_I250(unnormalEntryIndexes, :) = [];
            
            accountUniqueIdList   = unique(ecdObj.Table.xI250.("COD_CTA"));
            accountMonthlySummary = table('Size',          [numel(accountUniqueIdList), 15],                                                                                                                   ...
                                          'VariableTypes', {'cell', 'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                                          'VariableNames', {'COD_CTA', 'CTA_SUP', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'});

            for ii = 1: 1:numel(accountUniqueIdList)
                accountId      = accountUniqueIdList{ii};
                accountIndexes = strcmp(mergedTable_I200_I250.("COD_CTA"), accountId);
                accountTable   = mergedTable_I200_I250(accountIndexes, :);

                % Cria-se a descrição de todo o encadeamento das contas superiores, 
                % caso existentes.
                dotPositions  = strfind(accountId, '.');
                description   = {};

                for dotPosition = dotPositions
                    codeId    = accountId(1:dotPosition-1);
                    codeIndex = find(strcmp(ecdObj.Table.xI050.("COD_CTA"), codeId), 1);
                    
                    if ~isempty(codeIndex)
                        description{end+1} = ecdObj.Table.xI050.("CTA"){codeIndex};
                    end
                end

                description  = strjoin(description, '\n');
                
                % Sumariza-se mensalmente os fatos contábeis para cada conta.
                accountBalanceByMonth = zeros(1, 12);
                for jj = 1:12
                    monthIndexes = month(accountTable.("DT_LCTO")) == jj;
                    accountBalanceByMonth(jj) = sum(accountTable.("VL_DC_COM_SINAL")(monthIndexes));
                end

                accountMonthlySummary(ii, :) = [{accountId}, {description}, num2cell([accountBalanceByMonth, sum(accountBalanceByMonth)])];
            end

            % Valida-se se o valor total de transações entre as contas por 
            % mês é igual a zero.
            floatDiffTolerance = 1e-5;
            if any(cellfun(@(x) sum(accountMonthlySummary.(x)) > floatDiffTolerance, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}))
                error('Ao menos um dos meses apresentou um balanço diferente de zero, o que evidencia erro.')
            end

            % Complementa com informações do registro "I050", inserindo as
            % colunas na mesma ordem que aparecem em "I050".
            accountMonthlySummary = innerjoin( ...
                accountMonthlySummary, ...
                ecdObj.Table.xI050, ...
                'Keys', 'COD_CTA', ...
                'RightVariables', {'COD_NAT', 'IND_CTA', 'NIVEL', 'CTA'} ...
            );

            accountMonthlySummary = movevars(accountMonthlySummary, {'COD_NAT', 'IND_CTA', 'NIVEL'}, 'Before', 'COD_CTA');
            accountMonthlySummary = movevars(accountMonthlySummary, 'CTA',                           'After',  'COD_CTA');

            ecdObj.Table.mAccountSummary = accountMonthlySummary;
        end

        %-----------------------------------------------------------------%
        function accountMonthlySummary = SummaryByAccountType(ecdObj, accountMonthlySummary, accountType)
            arguments
                ecdObj
                accountMonthlySummary
                accountType char {mustBeMember(accountType, {'01', '02', '03', '04', '05', '09'})} = '04'
            end

            % O campo "Código da Natureza das Contas/Grupos de Contas" classifica 
            % a natureza contábil de cada conta ou grupo de contas no plano de 
            % contas da empresa.
            % '01': Contas de Ativo
            % '02': Contas de Passivo
            % '03': Patrimônio Líquido
            % '04': Contas de Resultado
            % '05': Contas de Compensação
            % '09': Outras

            checkIfScalar(ecdObj)

            indexes = strcmp(accountMonthlySummary.("COD_NAT"), accountType);
            accountMonthlySummary = accountMonthlySummary(indexes, :);
            ecdObj.Table.(['mAccountSummary_' accountType]) = accountMonthlySummary;
        end
    end
    
end