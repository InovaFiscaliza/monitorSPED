classdef (Abstract) TableGenerator

    methods (Static = true)
        %-----------------------------------------------------------------%
        % <CódigoEscritoPorLeandroEmRevisão>
        %-----------------------------------------------------------------%
        function [outTable, I133Result, I355Result] = parseSplitLine(ecdObj)
            checkIfScalar(ecdObj)
            tableIdList = {'I150', 'I155', 'I350', 'I355'};
            isTableRead(ecdObj, tableIdList)
        
            outTable   = [];
            I133Result = -1;
            I355Result = -1;
        
            if ~isempty(ecdObj.Table.xI150)
                % Concatena os registros "I150" e "I155":
                refTable_I150_I155 = model.TableGenerator.tableTypes1And3(ecdObj, 1, tableIdList);
                refTable_I150_I155.REG = strcat(refTable_I150_I155.REG, '-', ecdObj.Table.('xI155').REG);       % PRECISA DISSO MESMO?
                refTable_I150_I155 = [refTable_I150_I155, removevars(ecdObj.Table.('xI155'), 'REG')];
        
                refTable_I150_I155 = model.TableGenerator.inseriCodCTA(ecdObj, refTable_I150_I155);
        
                if isfield(ecdObj.Table, 'xI350') && ~isempty(ecdObj.Table.('xI350'))
                    % Concatena os registros "I350" e "I355":
                    refTable_I350_I355 = model.TableGenerator.tableTypes1And3(ecdObj, 3, tableIdList);
                    refTable_I350_I355.REG = strcat(refTable_I350_I355.REG, '-', ecdObj.Table.('xI355').REG);
                    refTable_I350_I355 = [refTable_I350_I355, removevars(ecdObj.Table.('xI355'), 'REG')];
        
                    % Cria tabela de nulos de T_I350_I355 com mesmo númeor de linhas de T_I150_I155
                    tableI350_I355Null = table('Size',          [height(refTable_I150_I155), width(refTable_I350_I355)], ...
                                               'VariableTypes', varfun(@class, refTable_I350_I355, 'OutputFormat', 'cell'), ...
                                               'VariableNames', refTable_I350_I355.Properties.VariableNames);
        
                    tableI350_I355Null.REG(:,:) = {char};
                    tableI350_I355Null.COD_CTA(:,:) = {char};
                    tableI350_I355Null.COD_CCUS(:,:) = {char};
                    tableI350_I355Null.IND_DC(:,:) = {char};
                    tableI350_I355Null.IND_DC_MF(:,:) = {char};
        
                    tableI350_I355Null.REG(:) = repmat({strcat(tableIdList{3}, '-', tableIdList{4})}, height(tableI350_I355Null), 1);
        
                    refTable_I150_I155.REG = strcat(refTable_I150_I155.REG, '-', tableI350_I355Null.REG);
        
                    tableI350_I355Null = removevars(tableI350_I355Null, {'REG', 'COD_CTA', 'COD_CCUS'});
        
                    % Concatena as colunas das tabelas T_I150_I155 e T_I350_I355_Null
                    tableI150_I155_I350_I355Null = [refTable_I150_I155, tableI350_I355Null];
        
                    % Concatenar as tabelas T_I150_I155 e T_I350_I355
                    datas_I350 = ecdObj.Table.xI350.("DT_RES");
        
                    lineIni = 1;
                    for kk = 1:numel(datas_I350)
                        I155Parcial = refTable_I150_I155(refTable_I150_I155.DT_FIN == datas_I350(kk), :);                
                        I355Parcial = refTable_I350_I355(refTable_I350_I355.DT_RES == datas_I350(kk), :);                       
        
                        I155Parcial.ordem_original = (1:height(I155Parcial))';
        
                        indexDatasI350 = find(refTable_I150_I155.DT_FIN == datas_I350(kk));
        
                        I155Parcial.COD_CTA = string(I155Parcial.COD_CTA);
                        I155Parcial.COD_CCUS = string(I155Parcial.COD_CCUS);
                        I355Parcial.COD_CTA = string(I355Parcial.COD_CTA);
                        I355Parcial.COD_CCUS = string(I355Parcial.COD_CCUS);
                        I155I355Parcial = outerjoin(I155Parcial, I355Parcial, 'Keys', {'COD_CTA', 'COD_CCUS'}, ...
                                                                              'MergeKeys', true, ...
                                                                              'Type', 'full');
        
                        I155I355Parcial = removevars(I155I355Parcial, 'REG_I355Parcial');
        
                        lineFim = indexDatasI350(1)-1;
                        I150_I155_I350_I355_Null = tableI150_I155_I350_I355Null(lineIni:lineFim,:);
                        lineIni = indexDatasI350(end)+1;
        
                        I155I355Parcial = sortrows(I155I355Parcial, 'ordem_original');
                        I155I355Parcial.ordem_original = [];
        
                        I155I355Parcial(ismissing(I155I355Parcial.REG_I155Parcial), :) = [];
                        I155I355Parcial.Properties.VariableNames{1} = 'REG';
        
                        outTable = [outTable; I150_I155_I350_I355_Null; I155I355Parcial];
                    end
                else
                    outTable = refTable_I150_I155;            
                end
        
                % Calcula os valores de Mov_I155 e de Mov_I155_I355
                originColumnsToInvertValue = {'IND_DC_INI', 'IND_DC_FIN', 'IND_DC'};
                destinColumnsToInvertValue = {'VL_SLD_INI', 'VL_SLD_FIN', 'VL_CTA'};
        
                for ii = 1:numel(destinColumnsToInvertValue)
                    % Identifica registros em que o valor da coluna "IND_DC_INI", 
                    % "IND_DC_FIN" ou "IND_DC" é igual a "D". E também os registros 
                    % "NotANumber" presentes na coluna final - "VL_SLD_INI",
                    % "VL_SLD_FIN" e "VL_CTA", a depender do caso.
        
                    if ismember(destinColumnsToInvertValue{ii}, outTable.Properties.VariableNames)
                        idx1 = isnan(outTable.(destinColumnsToInvertValue{ii}));
                        idx2 = strcmp(outTable.(originColumnsToInvertValue{ii}), 'D');
                        
                        outTable.(destinColumnsToInvertValue{ii})(idx1) = 0;
                        outTable.(destinColumnsToInvertValue{ii})(idx2) = -abs(outTable.(destinColumnsToInvertValue{ii})(idx2));
                    end
                end
        
                % Calcula os valores de Mov_I155 e de Mov_I155_I355
                outTable.Mov_I155 = outTable.VL_SLD_FIN - outTable.VL_SLD_INI;
                
                outTable.Mov_I155_I355 = outTable.Mov_I155;
                if ~isempty(ecdObj.Table.xI350)
                    outTable.Mov_I155_I355 = outTable.Mov_I155_I355 + outTable.VL_CTA;
                end
            end
        
            if ~isempty(outTable)
                I133Result = sum(outTable.Mov_I155);
                I355Result = sum(outTable.Mov_I155_I355);

                if ~iscellstr(outTable.("COD_CTA"))
                    outTable.("COD_CTA") = cellstr(outTable.("COD_CTA"));
                end
            end
        end
        
        %-------------------------------------------------------------------------%
        function tableI150_I155_CTA = inseriCodCTA(obj, tableI150_I155)
            checkIfScalar(obj)
            isTableRead(obj, {'I050'})
        
            I050_CTA = obj.Table.xI050;
        
            % Selecionar apenas a coluna 'CTA' e a chave
            I050_CTA_reduzida = I050_CTA(:, {'COD_CTA', 'CTA'});
            I050_CTA_reduzida = unique(I050_CTA_reduzida, 'rows');
        
            tableI150_I155.ordem_original = (1:height(tableI150_I155))';
        
            % Fazer o join
            tableI150_I155_CTA = outerjoin(tableI150_I155, I050_CTA_reduzida, ...
                'Keys', 'COD_CTA', ...
                'MergeKeys', true, ...
                'Type', 'left');
        
            tableI150_I155_CTA = sortrows(tableI150_I155_CTA, 'ordem_original');
            tableI150_I155_CTA.ordem_original = [];
        
            % Reordenar colunas para colocar 'CTA' na 5ª posição
            varNames = tableI150_I155_CTA.Properties.VariableNames;
        
            % Remover temporariamente a variável 'CTA'
            varNames(strcmp(varNames, 'CTA')) = [];
        
            % Inserir 'CTA' na posição 5
            varNames = [varNames(1:4), {'CTA'}, varNames(5:end)];
        
            % Aplicar nova ordem
            tableI150_I155_CTA = tableI150_I155_CTA(:, varNames);
        end

        %--------------------------------------------------------------%
        function tableOutIdtypes = tableTypes1And3(obj, idtype, tabletype)

                % Filtras as linhas com as informações do primeiro e do segundo tabletype
                regexPattern = ['^\|(' tabletype{idtype} '|' tabletype{idtype + 1} ')\|[^\r\n]*'];
                regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';
                regexMatchesTabletypesFirstAndSecond = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);

                % Cria vetor lógico com o número de aparições sequenciais do segundo tabletype
                isMatch      = contains(regexMatchesTabletypesFirstAndSecond, tabletype{idtype+1});
                diffValues   = diff([0; isMatch; 0]); % Adiciona zeros no início e fim para capturar grupos
                startIndices = find(diffValues == 1); % Início de um grupo
                endIndices   = find(diffValues == -1) - 1; % Fim de um grupo
                nlinesTabletypeSecond = endIndices - startIndices + 1;

                if idtype == 1
                    tableIdtypeFirst = obj.Table.xI150;
                elseif idtype == 3
                    tableIdtypeFirst = obj.Table.xI350;
                end

                % Número de vezes que irá repetir o primeiro tabletype
                numReps = nlinesTabletypeSecond;

                % Índices dos tableIdtypeFirst para replicação
                idxIdtypeFirst = repelem(1:size(tableIdtypeFirst,1), numReps);

                % Tabela do tableIdtypeFirst
                tableOutIdtypes = tableIdtypeFirst(idxIdtypeFirst, :);          
        end

        %-----------------------------------------------------------------%
        function linesTabletype1 = tableTypesLines(obj, Tabletype)
            tabletypeFirst  = Tabletype{1};
            tabletypeSecond = Tabletype{2};

            regexPattern = ['^\|(' tabletypeFirst '|' tabletypeSecond ')\|[^\r\n]*'];
            regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';
            regexMatchesTabletype1Tabletype2 = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);

            % Criar vetor lógico indicando onde I355 aparece
            isMatch = contains(regexMatchesTabletype1Tabletype2, Tabletype{1});
            % Identifica o númeor de linhas que contém as sequências consecutivas de REG em "I355"
            diffValues = diff([0; isMatch; 0]); % Adiciona zeros no início e fim para capturar grupos
            startIndices = find(diffValues == 1); % Início de um grupo
            endIndices = find(diffValues == -1) - 1; % Fim de um grupo
            linesTabletype1 = endIndices - startIndices + 1;
        end

        %-----------------------------------------------------------------%
        function tableOutOthers = parseSplitLineOthers(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
            end

            checkIfScalar(obj)
            isTableRead(obj, tableIdList)

            switch tableIdList{1}
                case "I050"
                    if ~isempty(obj.Table.xI050)
                        tableOutAll = linesTableId(obj, 1, tableIdList, obj.Table.xI050, obj.Table.xI051, obj.Table.xI052);
                    else
                        tableOutOthers = [];
                        return;
                    end

                case "C050"
                        if ~isempty(obj.Table.xC050)
                            tableOutAll = linesTableId(obj, 1, tableIdList, obj.Table.xC050, obj.Table.xC051, obj.Table.xC052);
                        else
                            tableOutOthers = [];
                            return;
                        end

                case "I250"
                    if ~isempty(obj.Table.xI200)
                        for mm = 1: numel(tableIdList)
                            tableOutAll{mm} = linesTableId(obj, mm, tableIdList, obj.Table.xI250, obj.Table.xI200, []);
                        end
                    else
                        tableOutOthers = [];
                        return;
                    end

                case "J100"
                    if ~isempty(obj.Table.xJ100)
                        for mm = 1: numel(tableIdList)
                            tableOutAll{mm} = linesTableId(obj, mm, tableIdList, obj.Table.xJ100, obj.Table.xJ005, []);
                        end
                    else
                        % msgbox("Não há dados referemtes a Tabela I200 e I250!");
                        tableOutOthers = [];
                        return;
                    end

                case "J150"
                    if ~isempty(obj.Table.xJ150)
                        for mm = 1: numel(tableIdList)
                            tableOutAll{mm} = linesTableId(obj, mm, tableIdList, obj.Table.xJ150, obj.Table.xJ005, []);
                        end
                    else
                        tableOutOthers = [];
                        return;
                    end
            end

            % <EscopoLocal>
            function tableOutAll = linesTableId(obj, idtype, tableIdList, x1, x2, x3)
                tableOutAll = {};
                nTabletype  = numel(tableIdList);

                switch idtype
                    case 1
                        if nTabletype ==2
                            tableOutAll = x1;

                        else
                            % Identifica indexes das tabelas sob análise, além da 
                            % ordem dos ids.
                            splitContent   = splitlines(obj.Content);
                            idsIndexes     = cellfun(@(x) find(startsWith(splitContent, x)), {'|I050|', '|I051|', '|I052|'}, 'UniformOutput', false);
                            orderedIndexes = sort(vertcat(idsIndexes{:}));
                            orderedIdList  = cellfun(@(x) x(2:5), splitContent(orderedIndexes), 'UniformOutput', false);

                            % Inicializa coluna numérica "_TEMP_KEY" com valores 
                            % iguais a -1.
                            x1.("_TEMP_KEY")(:) = -1;
                            x2.("_TEMP_KEY")(:) = -1;
                            x3.("_TEMP_KEY")(:) = -1;
                            tableOutAll = {x1, x2, x3};

                            jj = 1;
                            xx = 1;
                            yy = 1;
                            zz = 1;

                            acum1 = 0;
                            acum2 = 0;
                            acum3 = 0;

                            incr1 = 0;
                            incr2 = 0;

                            for ii = 1:numel(orderedIdList)-1
                                currentId = orderedIdList{ii};
                                nextId    = orderedIdList{ii+1};

                                switch currentId
                                    case tableIdList{1}
                                        switch nextId
                                            case tableIdList{1}
                                                acum1 = acum1 + 1;
                                            case tableIdList{2}
                                                tableOutAll{1}.("_TEMP_KEY")(acum1 + xx) = jj;
                                            case tableIdList{3}
                                                tableOutAll{1}.("_TEMP_KEY")(acum1 + xx) = jj;
                                                incr2 = incr2 + 1;
                                        end

                                    case tableIdList{2}
                                        switch nextId
                                            case tableIdList{1}
                                                tableOutAll{2}.("_TEMP_KEY")(acum2 + yy - incr2) = jj;
                                                xx = xx + 1;
                                                yy = yy + 1;
                                                zz = zz + 1;
                                                jj = jj + 1;
                                                incr1 = incr1 + 1;
                                            case tableIdList{2}
                                                tableOutAll{2}.("_TEMP_KEY")(acum2 + yy) = jj;
                                                acum2 = acum2 + 1;
                                            case tableIdList{3}
                                                tableOutAll{2}.("_TEMP_KEY")(acum2 + yy) = jj;
                                        end

                                    case tableIdList{3}
                                        switch nextId
                                            case tableIdList{1}
                                                tableOutAll{3}.("_TEMP_KEY")(acum3 + zz - incr1) = jj;
                                                xx = xx + 1;
                                                yy = yy + 1;
                                                zz = zz + 1;
                                                jj = jj + 1;

                                            case tableIdList{3}
                                                tableOutAll{3}.("_TEMP_KEY")(acum3 + zz) = jj;
                                                acum3 = acum3 + 1;
                                        end
                                end
                            end

                            T1 = tableOutAll{1};
                            T2 = tableOutAll{2};
                            T3 = tableOutAll{3};

                            T3 = T3(~cellfun(@isempty, T3{:,2}), :);

                            T1.ordem_original = (1:height(T1))';

                            % Primeiro join entre T1 e T2
                            J1 = outerjoin(T1, T2, ...
                                'Keys', '_TEMP_KEY', ...
                                'Type', 'left', ...
                                'MergeKeys', true);

                            J1 = sortrows(J1, 'ordem_original');

                            J1.COD_CCUS = string(J1.COD_CCUS);
                            T3.COD_CCUS = string(T3.COD_CCUS);
                           
                            % Depois join entre o resultado e T3
                            Jfinal = outerjoin(J1, T3, ...
                                'Keys', {'_TEMP_KEY', 'COD_CCUS'}, ...
                                'Type', 'left', ...
                                'MergeKeys', true);

                            Jfinal = unique(Jfinal, 'rows');                            
                            Jfinal = sortrows(Jfinal, 'ordem_original');

                            Jfinal.REG_T1 = repmat({[tableIdList{1}, '-', tableIdList{2}, '-', tableIdList{3}]}, height(Jfinal), 1);
                            Jfinal = removevars(Jfinal, {'_TEMP_KEY', 'ordem_original', 'REG_T2', 'REG'});
                            Jfinal.Properties.VariableNames('REG_T1') = {'REG'};

                            tableOutOthers = Jfinal;
                        end

                    case 2

                        linesTabletype1 = model.TableGenerator.tableTypesLines (obj, tableIdList);
    
                        switch nTabletype
                            case 2
                                numReps     = linesTabletype1;
                                % Criação de índices para replicação
                                idx = repelem(1:size(x2,1), numReps);

                                % Repetir linhas
                                tableOutAll = x2(idx, :);
                        end

                    otherwise
                        error('Unexpected value')
                end
            end
            % </EscopoLocal>

            if numel(tableIdList) == 2
                tableOutAll{2}.REG = strcat(tableOutAll{2}.REG, '-', tableOutAll{1}.REG);
                tableOutAll{1}     = removevars(tableOutAll{1}, 'REG');
                tableOutOthers    = [tableOutAll{2}, tableOutAll{1}];
            end
        end

        %-----------------------------------------------------------------%
        function accountMonthlySummary = SummaryByAccount(ecdObj, Table_I150_I155_I350_I355, Table_I200_I250)
            arguments
                ecdObj
                Table_I150_I155_I350_I355;
                Table_I200_I250;
            end

            checkIfScalar(ecdObj)

            accountUniqueIdList   = unique(Table_I150_I155_I350_I355.("COD_CTA"), 'stable');
            accountMonthlySummary = table('Size',          [numel(accountUniqueIdList), 14],                                                                                                           ...
                                          'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                                          'VariableNames', {'COD_CTA', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'});

            % ToDo: Entender exatamente o que está sendo feito aqui...
            % quando não existe o registro "I200", o que significa?!

            if ~isempty(Table_I200_I250)
                xI200_I250_IND_LCTO_N = Table_I200_I250(strcmp(Table_I200_I250.("IND_LCTO"),  'N'), :);
                xI200_I250_IND_LCTO_N.("VL_DC_COM_SINAL") = xI200_I250_IND_LCTO_N.("VL_DC");
                negativeValueIndexes = find(strcmp(xI200_I250_IND_LCTO_N.("IND_DC"), 'D'));
                xI200_I250_IND_LCTO_N.("VL_DC_COM_SINAL")(negativeValueIndexes) = -xI200_I250_IND_LCTO_N.("VL_DC_COM_SINAL")(negativeValueIndexes);

                dateReferenceColumn  = 'DT_LCTO';
                valueReferenceColumn = 'VL_DC_COM_SINAL';

            else
                xI200_I250_IND_LCTO_N = Table_I150_I155_I350_I355;

                dateReferenceColumn  = 'DT_INI';
                valueReferenceColumn = 'VL_CRED';
            end            
          
            for ii = 1: 1:numel(accountUniqueIdList)
                accountId      = accountUniqueIdList{ii};
                accountIndexes = strcmp(xI200_I250_IND_LCTO_N.("COD_CTA"), accountId);
                accountTable   = xI200_I250_IND_LCTO_N(accountIndexes, :);
                
                accountValuesByMonth = zeros(1, 12);
                for jj = 1:12
                    monthIndexes = month(accountTable.(dateReferenceColumn)) == jj;
                    accountValuesByMonth(jj) = sum(accountTable.(valueReferenceColumn)(monthIndexes));
                end

                accountMonthlySummary(ii, :) = [{accountId}, num2cell([accountValuesByMonth, sum(accountValuesByMonth)])];
            end

            % Valida-se se o valor total de transações entre as contas por 
            % mês é igual a zero.
            floatDiffTolerance = 1e-5;
            if any(cellfun(@(x) sum(accountMonthlySummary.(x)) > floatDiffTolerance, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}))
                error('Ao menos um dos meses apresentou um balanço diferente de zero')
            end

            % Cria-se a descrição de todo o encadeamento das suas contas 
            % superiores, caso existentes.
            for kk = 1:height(accountMonthlySummary)
                    dotPositions = strfind(accountMonthlySummary.("COD_CTA"){kk}, '.');
                    description  = {};

                    for dotPosition = dotPositions
                        codeId    = accountMonthlySummary.("COD_CTA"){kk}(1:dotPosition-1);
                        codeIndex = find(strcmp(ecdObj.Table.xI050.("COD_CTA"), codeId), 1);
                        
                        if ~isempty(codeIndex)
                            description{end+1} = ecdObj.Table.xI050.("CTA"){codeIndex};
                        end
                    end

                    accountMonthlySummary.("CTA_SUP"){kk} = strjoin(description, '\n');
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
            accountMonthlySummary = movevars(accountMonthlySummary, {'CTA_SUP', 'CTA'},              'After',  'COD_CTA');
        end

        %-----------------------------------------------------------------%
        function analyticalMonthlySummary = SummaryByAnalyticalAccount(ecdObj, accountMonthlySummary, analyticalCode)
            arguments
                ecdObj
                accountMonthlySummary
                analyticalCode = '04'
            end

            % Código da Natureza das Contas/Grupos de Contas
            % '01': Contas de Ativo
            % '02': Contas de Passivo
            % '03': Patrimônio Líquido
            % '04': Contas de Resultado
            % '05': Contas de Compensação
            % '09': Outras

            checkIfScalar(ecdObj)

            indexes = strcmp(accountMonthlySummary.("COD_NAT"), analyticalCode);
            analyticalMonthlySummary = accountMonthlySummary(indexes, :);
        end
        %-----------------------------------------------------------------%
        % </CódigoEscritoPorLeandroEmRevisão>
        %-----------------------------------------------------------------%
    end
end