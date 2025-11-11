classdef (Abstract) TableGenerator

    methods (Static = true)
        %-----------------------------------------------------------------%
        function accountMonthlySummary = SummaryByAccount(ecdObj)
            checkIfScalar(ecdObj)

            accountMonthlySummary = table( ...
                'Size', [0, 14], ...
                'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'COD_CTA', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'} ...
            );

            parseTableAndAddToCache(ecdObj, {'I200_I250'})

            if isfield(ecdObj.Table, 'xI200') && ~isempty(ecdObj.Table.xI200)
                % Aplica filtros na tabela de fatos contábeis (I200_I250), de forma 
                % que sejam considerados apenas os lançamentos "NORMAIS". Além
                % disso, cria-se coluna "VL_DC_COM_SINAL".

                mergedTable_I200_I250 = ecdObj.Table.xI200_I250;
                mergedTable_I200_I250.("VL_DC_COM_SINAL") = mergedTable_I200_I250.("VL_DC");
                negativeValueIndexes  = strcmp(mergedTable_I200_I250.("IND_DC"), 'D');
                mergedTable_I200_I250.("VL_DC_COM_SINAL")(negativeValueIndexes) = -mergedTable_I200_I250.("VL_DC_COM_SINAL")(negativeValueIndexes);

                unnormalEntryIndexes  = ~strcmp(mergedTable_I200_I250.("IND_LCTO"), 'N');
                mergedTable_I200_I250(unnormalEntryIndexes, :) = [];
                
                accountUniqueIdList = unique(ecdObj.Table.xI250.("COD_CTA"));
    
                for ii = 1: 1:numel(accountUniqueIdList)
                    accountId      = accountUniqueIdList{ii};
                    accountIndexes = strcmp(mergedTable_I200_I250.("COD_CTA"), accountId);
                    accountTable   = mergedTable_I200_I250(accountIndexes, :);
                    
                    % Sumariza-se mensalmente os fatos contábeis para cada conta.
                    accountBalanceByMonth = zeros(1, 12);
                    for jj = 1:12
                        monthIndexes = month(accountTable.("DT_LCTO")) == jj;
                        accountBalanceByMonth(jj) = sum(accountTable.("VL_DC_COM_SINAL")(monthIndexes));
                    end
    
                    accountMonthlySummary(end+1, :) = [{accountId}, num2cell([accountBalanceByMonth, sum(accountBalanceByMonth)])];
                end
    
                % Valida-se se o valor total de transações entre as contas por 
                % mês é igual a zero.
                floatDiffTolerance = 1e-5;
                if any(cellfun(@(x) sum(accountMonthlySummary.(x)) > floatDiffTolerance, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}))
                    ecdObj.GUI.warnings{end+1} = jsonencode(struct('id', 'mBALANCETE_GERAL', 'message', 'Ao menos um dos meses apresentou um balanço diferente de zero, o que evidencia erro no arquivo contábil ou na análise dos seus dados.'));
                end
            end
            
            accountMonthlySummary = model.TableGenerator.AddAccountGeneralInfo(ecdObj, accountMonthlySummary);
        end

        %-----------------------------------------------------------------%
        function accountMonthlySummary = AddAccountGeneralInfo(ecdObj, accountMonthlySummary)
            xI050 = flip(ecdObj.Table.xI050);
            [~, accountUniqueIdFirstIndex] = unique(xI050.('COD_CTA'), "sorted");
            accountDataBase = xI050(accountUniqueIdFirstIndex, :);

            accountMonthlySummary = join( ...
                accountMonthlySummary, ...
                accountDataBase, ...
                'Keys', 'COD_CTA', ...
                'RightVariables', 'COD_NAT' ...
            );

            accountMonthlySummary = movevars(accountMonthlySummary, 'COD_NAT', 'Before', 'COD_CTA');
            accountMonthlySummary = unique(accountMonthlySummary, "rows");
        end

        %-----------------------------------------------------------------%
        function accountMonthlySummary = SummaryByAccountType(ecdObj, accountType)
            arguments
                ecdObj
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

            accountMonthlySummary = ecdObj.Table.x_BALANCETE_GERAL;
            indexes = strcmp(accountMonthlySummary.("COD_NAT"), accountType);
            accountMonthlySummary = removevars(accountMonthlySummary(indexes, :), 'COD_NAT');
        end
    end
    
end