classdef ECD < model.ECDBase

    % Inicialização:
    % >> ecdObj = model.ECD.empty;

    % Leitura de arquivos:
    % >> ecdObj = addFiles(ecdObj, {'Filename1', 'Filename2'});

    properties
        %-----------------------------------------------------------------%
        CompanyName 
        CompanyInfo = struct('CNPJ', {}, 'IE', {}, 'IM', {}, 'UF', {}, 'City', {})
        Period  = []

        FileName
        FileFullName

        Content
        Layout
        Table
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        % MÉTODOS RELACIONADOS AO OBJETO VISTO COMO UM ARRAY
        % (ESCALAR, OU NÃO)
        %-----------------------------------------------------------------%
        function obj = addFiles(obj, fileNameList, tableIdList)
            arguments
                obj
                fileNameList
                tableIdList (1,:) cell = {'0000'}
            end

            if ~iscellstr(fileNameList)
                fileNameList = cellstr(fileNameList);
            end

            for ii = 1:numel(fileNameList)
                fileFullName = fileNameList{ii};
                [~, fileName, fileExt] = fileparts(fileFullName);
                fileName = [fileName, fileExt];

                if any(arrayfun(@(x) isequal(x.FileName, fileName), obj))
                    continue
                end

                idx = numel(obj)+1;

                try
                    obj(idx).FileName     = fileName;
                    obj(idx).FileFullName = fileFullName;
                    obj(idx).Content      = fileread(fileFullName);

                    % Leitura da ficha "I010", identificando o layout do
                    % arquivo. Como essa ficha não mudou ao longo do tempo, 
                    % considera-se que o layout é igual a 1, mas depois de 
                    % lida a ficha, o valor é atualizado.

                    % A outra ficha lida no início do processo é a "I020",
                    % que registra os campos opcionais, caso aplicável.
                    obj(idx).Layout       = 1;
                    parseTableAndAddToCache(obj(idx), {'I010'})
                    obj(idx).Layout       = obj(idx).Table.xI010.COD_VER_LC(1);                    
                    parseTableAndAddToCache(obj(idx), tableIdList)

                    if isfield(obj(idx).Table, 'x0000') && ~isempty(obj(idx).Table.x0000)
                        obj(idx).CompanyName = obj(idx).Table.x0000.NOME{1};
                        obj(idx).CompanyInfo = struct('CNPJ',  obj(idx).Table.x0000.CNPJ{1}, ...
                                                      'IE',    obj(idx).Table.x0000.IE{1},   ...
                                                      'IM',    obj(idx).Table.x0000.IM{1},   ...
                                                      'UF',    obj(idx).Table.x0000.UF{1},   ...
                                                      'City',  obj(idx).Table.x0000.COD_MUN{1});
                        obj(idx).Period      = [obj(idx).Table.x0000.DT_INI(1), obj(idx).Table.x0000.DT_FIN(1)];
                    end

                catch ME
                    delete(obj(idx))
                    obj(idx) = [];

                    warning('"%s" - %s', fileFullName, ME.message)
                end
            end
        end

        %-----------------------------------------------------------------%
        function parseTableAndAddToCache(obj, tableIdList)
            % ToDo: 
            % Avaliar performance. Numa análise inicial de paralelismo, o
            % tempo reduziu de 24s para 20s.
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
            end

            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};

                    if ~isfield(obj(ii).Table, ['x' tableId])
                        obj(ii).Table.(['x' tableId]) = parseTable(obj(ii), tableId, obj(ii).Layout);
                    end
                end
            end

            % parpoolCheck()
            % for ii = 1:numel(obj)
            %     currentObj  = obj(ii);
            %     tableOutput = repmat({[]}, 1, numel(tableIdList));
            % 
            %     parfor jj = 1:numel(tableIdList)
            %         tableId = tableIdList{jj};
            % 
            %         if ~isfield(currentObj.Table, ['x' tableId])
            %             tableOutput{jj} = parseTable(currentObj, tableId, currentObj.Layout);
            %         end
            %     end
            % 
            %     tableIndex = find(cellfun(@(x) ~isempty(x), tableOutput));
            %     for kk = tableIndex
            %         obj(ii).Table.(['x' tableIdList{kk}]) = tableOutput{kk};
            %     end
            % end
        end

        %-----------------------------------------------------------------%
        function mergedTable = mergeTable(obj, tableID)
            arguments
                obj
                tableID (1,4) char
            end

            isTableRead(obj, {tableID})

            mergedTable = arrayfun(@(x) x.Table.(['x' tableID]), obj, 'UniformOutput', false);
            mergedTable = vertcat(mergedTable{:});
        end

        %-----------------------------------------------------------------%
        function isTableRead(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
            end

            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableID = tableIdList{jj};
                    if ~isfield(obj(ii).Table, ['x' tableID])
                        parseTableAndAddToCache(obj(ii), {tableID})
                    end
                end
            end
        end
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        % MÉTODOS RELACIONADOS AO OBJETO ESCALAR
        %-----------------------------------------------------------------%
        function checkIfScalar(obj)
            if ~isscalar(obj)
                error('Método aplicável a um objeto escalar')
            end
        end

        %-----------------------------------------------------------------%
        function tableOut = parseTable(obj, tableId, fileLayout)
            arguments
                obj
                tableId (1,4) char
                fileLayout  = 1
            end

            checkIfScalar(obj)

            if ~ismember(tableId, model.ECDBase.checkImplementedTables())
                error('Ficha ainda não implementada')
            end

            % Identifica a tabela sob análise e a sua estrutura, registrando
            % as colunas opcionais até quando não preenchidas e, assim,
            % mantendo a estrutura de dados homogênea.
            idxLayout       = find(cellfun(@(x) ismember(fileLayout, x), obj.(['x' tableId])(:,1)), 1);

            requiredColumns = obj.(['x' tableId]){idxLayout, 2};
            optionalColumns = obj.(['x' tableId]){idxLayout, 3};
            completeColumns = [requiredColumns, optionalColumns];

            % Busca no conteúdo do arquivo o ID da tabela sob análise.
            regexPattern    = ['^\|' tableId '\|[^\r\n]*'];
            regexMatches    = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';

            if isempty(regexMatches)
                columnTypes = cellfun(@(x) obj.(x).DataType, completeColumns, 'UniformOutput', false);
                tableOut    = table('Size', [0, numel(completeColumns)], 'VariableNames', completeColumns, 'VariableTypes', columnTypes);

            else
                % Elimina primeiro e último caractere "|", separa e
                % concatena.
                regexMatchesTransformation1 = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);
                regexMatchesTransformation2 = cellfun(@(x) strsplit(x, '|', 'CollapseDelimiters', false), regexMatchesTransformation1, 'UniformOutput', false);
                regexMatchesTransformation3 = vertcat(regexMatchesTransformation2{:});

                % Converte para tabela...
                switch width(regexMatchesTransformation3)
                    case numel(requiredColumns)
                        tableOut = cell2table(regexMatchesTransformation3, 'VariableNames', requiredColumns);

                        % Cria colunas opcionais p/ manter estrutura de dados 
                        % homogênea.
                        for ii = 1:numel(optionalColumns)
                            columnName = optionalColumns{ii};
                            tableOut.(columnName) = repmat(model.ECD.defaultValue(obj.(columnName).DataType), height(tableOut), 1);
                        end

                    case numel(completeColumns)
                        tableOut = cell2table(regexMatchesTransformation3, 'VariableNames', completeColumns);

                    otherwise
                        error('UnexpectedTableWidth')
                end

                % Aplica mudança do tipo de dado p/ colunas que não são textuais.
                for ii = 1:numel(completeColumns)
                    columnName = completeColumns{ii};

                    switch obj.(columnName).DataType
                        case 'double'
                            if ~isa(tableOut.(columnName), 'double')
                                tableOut.(columnName) = str2double(replace(tableOut.(columnName), ',', '.'));
                            end
                        case 'datetime'
                            if ~isa(tableOut.(columnName), 'datetime')
                                tableOut.(columnName) = datetime(tableOut.(columnName), 'InputFormat', 'ddMMyyyy');
                            end
                    end
                end
            end
        end

        %-----------------------------------------------------------------%
        function [timeTable, dataTable] = createKeyBetweenTables(obj, timeTable, timeTableColumnName, dataTable, dataTableReferenceColumnName, newColumnName)
            arguments
                obj
                timeTable
                timeTableColumnName
                dataTable
                dataTableReferenceColumnName
                newColumnName
            end

            checkIfScalar(obj)

            % Referência temporal.
            monthRefIDs = unique(month(timeTable.(timeTableColumnName)));

            % Mapeamento índice x mês.
            [keys, ~, ...
             indexes]   = unique(dataTable.(dataTableReferenceColumnName), 'stable');
            keysIndex   = accumarray(indexes, (1:numel(indexes))', [], @(x) {x});
            keysNum     = cellfun(@(x) numel(x), keysIndex, 'UniformOutput', false);
            
            keysInfo    = struct('key',        keys,      ...
                                 'indexes',    keysIndex, ...
                                 'numIndexes', keysNum,   ...
                                 'monthIDs',   monthRefIDs);

            refKey      = [keysInfo.numIndexes] == numel(monthRefIDs);
            nonRefKey   = find(~refKey);
            
            monthIndex  = min(horzcat(keysInfo(refKey).indexes), [], 2);

            % A validação abaixo resolve apenas o índice relacionado ao
            % primeiro mês, mas pode haver um deslocamente também de
            % outros meses. 
            if monthIndex(1) ~= 1
                monthIndex(1) = 1;
                warning('"%s" - %s', obj.FileFullName, '...')
            end

            for jj = nonRefKey
                monthIDsValidation = arrayfun(@(x) find(x > monthIndex), keysInfo(jj).indexes, 'UniformOutput', false);
                monthIDsValidation = cellfun(@(x) max(x), monthIDsValidation);
                monthIDs           = monthRefIDs(monthIDsValidation);

                if ~issorted(monthIDs, 'strictascend')
                    error('Índice repetido, o que evidencia problema com as referências dos meses registradas em "monthIndex". Pendente criar função que lide com essa exceção! :(')
                end

                keysInfo(jj).monthIDs = monthIDs;
            end

            recreatedKeysIndex        = arrayfun(@(x) x.indexes, keysInfo, 'UniformOutput', false);
            recreatedKeysIndex        = vertcat(recreatedKeysIndex{:});
            [~, idxSort]              = sort(recreatedKeysIndex);
            keysMonthIndex            = arrayfun(@(x) x.monthIDs, keysInfo, 'UniformOutput', false);
            keysMonthIndex            = vertcat(keysMonthIndex{:});
            keysMonthIndex            = keysMonthIndex(idxSort);

            % Cria uma "coluna chave" nas tabelas sob análise.
            timeTable.(newColumnName) = month(timeTable.(timeTableColumnName));
            dataTable.(newColumnName) = keysMonthIndex;                
        end

        %-----------------------------------------------------------------%
        function tableOut_idtypes = TableTypes_1_3 (obj, idtype, Tabletype)
                % Filtras as linhas com as informações de Tabletype{1} e Tabletype{2}
                regexPattern = ['^\|(' Tabletype{idtype} '|' Tabletype{idtype+1} ')\|[^\r\n]*'];
                regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';
                regexMatches_idtypes = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);

                % Identifica as primeiras linhas com a informações de Tabletype
                linesIniIdxI_1_3 = find(contains(regexMatches_idtypes, Tabletype{idtype}));

                tableOut_All = [];

                if idtype == 1
                    Table_idtype_first = obj.Table.xI150;
                    Table_idtype_second = obj.Table.xI155;
                elseif idtype == 3
                    Table_idtype_first = obj.Table.xI350;
                    Table_idtype_second = obj.Table.xI355;
                end

                for ii = 1:height(Table_idtype_first)
                    if ii < height(Table_idtype_first)
                        numReps = linesIniIdxI_1_3(ii+1) - linesIniIdxI_1_3(ii) - 1;
                    else
                        numReps = height(Table_idtype_second) - linesIniIdxI_1_3(ii) + ii;
                    end

                    % Repete cada valor da linha 'ii', 'numReps' vezes
                    tableOutRowData = repmat(Table_idtype_first(ii, :), numReps, 1);

                    % Acumula resultado
                    tableOut_All = [tableOut_All; tableOutRowData];
                end
                tableOut_idtypes = tableOut_All;
        end

        %-----------------------------------------------------------------%
        function tableOut = parseSplitLine(obj, tableId)
            arguments
                obj
                tableId {mustBeMember(tableId,{'0000', '0007', '0020', '0035', '0150', '0180', '0990', 'C001', 'C040', 'C050', 'C051', 'C052', 'C150', 'C155', ...
                                               'C600', 'C650', 'C990', 'I001', 'I010', 'I001', 'I012', 'I015', 'I020', 'I030', 'I050', 'I051', 'I052', 'I053', ...
                                               'I075', 'I100', 'I150', 'I155', 'I157', 'I200', 'I250', 'I300', 'I310', 'I350', 'I355', 'I500', 'I510', 'I550', ...
                                               'I555', 'I990', 'J001', 'J005', 'J100', 'J150', 'J210', 'J215', 'J801', 'J900', 'J930', 'J932', 'J935', 'J990', ...
                                               'K001', 'K030', 'K100', 'K110', 'K115', 'K200', 'K210', 'K300', 'K310', 'K315', 'K990', '9001', '9900', '9990', ...
                                               '9999'})}
            end

            checkIfScalar(obj)

            for mm = 1: numel(tableId)
                switch mm
                    case 1; tableOut_I150_155_350_355{mm} = TableTypes_1_3(obj, mm, tableId);
                    case 2; tableOut_I150_155_350_355{mm} = obj.Table.xI155;
                    case 3; tableOut_I150_155_350_355{mm} = TableTypes_1_3(obj, mm, tableId);
                    case 4; tableOut_I150_155_350_355{mm} = obj.Table.xI355;
                end

            end

            tableOut_I150_155_350_355{1}.REG = strcat(tableOut_I150_155_350_355{1}.REG, '-', tableOut_I150_155_350_355{2}.REG);
            tableOut_I150_155_350_355{2} = removevars(tableOut_I150_155_350_355{2}, 'REG');

            % Concatenar tabelas I150 e I155
            T_I150_I155 = [tableOut_I150_155_350_355{1}, tableOut_I150_155_350_355{2}];
            tableOut_I150_155_350_355{3}.REG = strcat(tableOut_I150_155_350_355{3}.REG, '-', tableOut_I150_155_350_355{4}.REG);
            tableOut_I150_155_350_355{4} = removevars(tableOut_I150_155_350_355{4}, 'REG');

            % Concatenar colunas das tabelas I350 e I355
            T_I350_I355 = [tableOut_I150_155_350_355{3}, tableOut_I150_155_350_355{4}];

            % Concatenar as tabelas T_I150_I155 e T_I350_I355
            I150_I155_I350_I355 = [];
            pp = 1;

            datas_I150 = obj.Table.xI150.DT_INI;
            datas_I350 = obj.Table.xI350.DT_RES;

            line_Fim_155 = 0;
            line_Fim_355 = 0;

            for kk = 1:numel(datas_I150)
                if month(datas_I350(pp)) == month(datas_I150(kk))
                    line_Ini_155 = line_Fim_155 + 1;
                    line_Fim_155 = line_Fim_155 + numel(find(month(T_I150_I155.DT_INI) == month(datas_I150(kk))));

                    line_Ini_355 = line_Fim_355 + 1;
                    line_Fim_355 = line_Fim_355 + numel(find(month(T_I350_I355.DT_RES) == month(datas_I350(pp))));

                    I155_parcial = T_I150_I155(line_Ini_155:line_Fim_155,:);
                    I355_parcial = T_I350_I355(line_Ini_355:line_Fim_355,:);

                    I155_parcial.ordem_original = (1:height(I155_parcial))';

                    resultado = outerjoin(I155_parcial, I355_parcial, ...
                        'Keys', 'COD_CTA', ...
                        'MergeKeys', true, ...
                        'Type', 'full');

                    resultado = sortrows(resultado, 'ordem_original');
                    resultado.ordem_original = [];

                    resultado(ismissing(resultado.REG_I155_parcial), :) = [];

                    resultado.Properties.VariableNames{1} = 'REG';
                    resultado.Properties.VariableNames{5} = 'COD_CCUS';

                    resultado.REG = strcat(resultado.REG, '-', "I350-I355");
                    resultado = removevars(resultado, 'REG_I355_parcial');
                    resultado = removevars(resultado, 'COD_CCUS_I355_parcial');

                    I150_I155_I350_I355 = [I150_I155_I350_I355; resultado];
                    pp = pp+1;

                else
                    line_Ini_155 = line_Fim_155 + 1;
                    line_Fim_155 = line_Fim_155 + numel(find(month(T_I150_I155.DT_INI) == month(datas_I150(kk))));

                    resultado = T_I150_I155(line_Ini_155:line_Fim_155, :);

                    array_vazios = repmat({""}, (line_Fim_155 - line_Ini_155 +  1), numel(T_I350_I355.Properties.VariableNames));
                    array_vazios(:,2) = {NaT};

                    table_array_vazios_155 = cell2table(array_vazios, 'VariableNames', T_I350_I355.Properties.VariableNames);

                    resultado.REG = strcat(resultado.REG, '-', "I350-I355");

                    table_array_vazios_155 = removevars(table_array_vazios_155, 'REG');
                    table_array_vazios_155 = removevars(table_array_vazios_155, 'COD_CTA');
                    table_array_vazios_155 = removevars(table_array_vazios_155, 'COD_CCUS');

                    I150_I155_nullos = [resultado, table_array_vazios_155];

                    I150_I155_I350_I355 = [I150_I155_I350_I355; I150_I155_nullos];
                end
            end

            numrows = height(I150_I155_I350_I355);
            TNuls = array2table(NaN(numrows, 2), 'VariableNames', {'Mov_155', 'Mov_155_355'});

            I150_I155_I350_I355 = [I150_I155_I350_I355, TNuls];

            % Calcula os valores de Mov_I155 e de Mov_I155_I355
            idx_IND_DC_INI_D = find(I150_I155_I350_I355.IND_DC_INI == "D");
            I150_I155_I350_I355.VL_SLD_INI(idx_IND_DC_INI_D) = -abs(I150_I155_I350_I355.VL_SLD_INI(idx_IND_DC_INI_D));

            idx_IND_DC_FIN_D = find(I150_I155_I350_I355.IND_DC_FIN == "D");
            I150_I155_I350_I355.VL_SLD_FIN(idx_IND_DC_FIN_D) = -abs(I150_I155_I350_I355.VL_SLD_FIN(idx_IND_DC_FIN_D));

            idx_VL_CTA_D = find(I150_I155_I350_I355.IND_DC == "D");
            I150_I155_I350_I355.VL_CTA = str2double(replace(I150_I155_I350_I355.VL_CTA, ",", "."));
            I150_I155_I350_I355.VL_CTA(idx_VL_CTA_D) = -abs(I150_I155_I350_I355.VL_CTA(idx_VL_CTA_D));
            I150_I155_I350_I355.VL_CTA(isnan(I150_I155_I350_I355.VL_CTA)) = 0;

            I150_I155_I350_I355.Mov_I155 = I150_I155_I350_I355.VL_SLD_FIN - I150_I155_I350_I355.VL_SLD_INI;
            I150_I155_I350_I355.Mov_I155_I355 = I150_I155_I350_I355.Mov_I155 + I150_I155_I350_I355.VL_CTA;

            tableOut = I150_I155_I350_I355;
        end

        %-----------------------------------------------------------------%
        function tableOut_others = parseSplitLineOthers(obj, tableId)
            arguments
                obj
                tableId {mustBeMember(tableId,{'0000', '0007', '0020', '0035', '0150', '0180', '0990', 'C001', 'C040', 'C050', 'C051', 'C052', 'C150', 'C155', ...
                                               'C600', 'C650', 'C990', 'I001', 'I010', 'I001', 'I012', 'I015', 'I020', 'I030', 'I050', 'I051', 'I052', 'I053', ...
                                               'I075', 'I100', 'I150', 'I155', 'I157', 'I200', 'I250', 'I300', 'I310', 'I350', 'I355', 'I500', 'I510', 'I550', ...
                                               'I555', 'I990', 'J001', 'J005', 'J100', 'J150', 'J210', 'J215', 'J801', 'J900', 'J930', 'J932', 'J935', 'J990', ...
                                               'K001', 'K030', 'K100', 'K110', 'K115', 'K200', 'K210', 'K300', 'K310', 'K315', 'K990', '9001', '9900', '9990', ...
                                               '9999'})}
            end

            checkIfScalar(obj)

            switch tableId{1}
                case "I050"
                    for mm = 1: numel(tableId)
                        tableOutAll{mm} = linesTableId(obj, mm, tableId, obj.Table.xI050, obj.Table.xI051, obj.Table.xI052);
                    end

                case "C050"
                    for mm = 1: numel(tableId)
                        if ~isempty(obj.Table.xC050)
                            tableOutAll{mm} = linesTableId(obj, mm, tableId, obj.Table.xC050, obj.Table.xC051, obj.Table.xC052);
                        else
                            msgbox("Não há dados referemtes a Tabela C50, C51 e C52!");
                            tableOut_others = [];
                            return;
                        end
                    end

                case "I250"
                    for mm = 1: numel(tableId)
                        tableOutAll{mm} = linesTableId(obj, mm, tableId, obj.Table.xI250, obj.Table.xI200, []);
                    end

                case "J100"
                    for mm = 1: numel(tableId)
                        tableOutAll{mm} = linesTableId(obj, mm, tableId, obj.Table.xJ100, obj.Table.xJ005, []);
                    end
            end

            function tableOutAll = linesTableId(obj, idtype, Tabletype, x1, x2, x3)
                tableOutAll = [];
                nTabletype  = numel(Tabletype);

                switch idtype
                    case 1
                        tableOutAll = x1;

                    case 2
                        regexPattern = ['^\|(' Tabletype{1} '|' Tabletype{2} ')\|[^\r\n]*'];
                        regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';
                        regexMatches_Tabletype1_Tabletype2 = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);
    
                        % Identifica as linhas com a informações de tableId
                        linesIniIdx_Tabletype2 = find(contains(regexMatches_Tabletype1_Tabletype2, Tabletype{2}));
    
                        % Criar vetor lógico indicando onde I355 aparece
                        isMatch = contains(regexMatches_Tabletype1_Tabletype2, tableId{1});
                        % Identifica o númeor de linhas que contém as sequências consecutivas de REG em "I355"
                        diffValues = diff([0; isMatch; 0]); % Adiciona zeros no início e fim para capturar grupos
                        startIndices = find(diffValues == 1); % Início de um grupo
                        endIndices = find(diffValues == -1) - 1; % Fim de um grupo
                        linesTabletype1 = endIndices - startIndices + 1;
    
                        for ii = 1:height(linesIniIdx_Tabletype2)
                            switch nTabletype
                                case 2
                                    numReps     = linesTabletype1(ii);        
                                    newRow      = repmat(x2(ii, :), numReps, 1);
                                    tableOutAll = [tableOutAll; newRow];

                                case 3
                                    % Cria uma matriz de strings vazias
                                    stringMatrix = strings(height(x1), numel(x2.Properties.VariableNames));
        
                                    % Converte para tabela
                                    tableOutAll = array2table(stringMatrix, 'VariableNames', x2.Properties.VariableNames);
                                    tableOutAll.REG(1:end) = Tabletype{2};
        
                                    if ii == 1
                                        numReps = linesTabletype1(1);
                                    else
                                        numReps = numReps + linesTabletype1(ii);
                                    end
        
                                    newRow = x2(ii,:);
                                    tableOutAll(numReps,:) = newRow;
                            end
                        end

                    case 3
                        regexPattern = ['^\|(' Tabletype{1} '|' Tabletype{3} ')\|[^\r\n]*'];
                        regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';
                        regexMatches_Tabletype1_Tabletype3 = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);
    
                        % Criar vetor lógico indicando onde I355 aparece
                        isMatch = contains(regexMatches_Tabletype1_Tabletype3, tableId{1});
                        % Identifica o númeor de linhas que contém as sequências consecutivas de REG em "I355"
                        diffValues = diff([0; isMatch; 0]); % Adiciona zeros no início e fim para capturar grupos
                        startIndices = find(diffValues == 1); % Início de um grupo
                        endIndices = find(diffValues == -1) - 1; % Fim de um grupo
                        linesTabletype1 = endIndices - startIndices + 1;
    
                        % Identifica as linhas com a informações de tableId
                        linesIniIdx_Tabletype3 = find(contains(regexMatches_Tabletype1_Tabletype3, Tabletype{3}));
    
                        % Cria uma matriz de strings vazias
                        stringMatrix = strings(height(x1), numel(x3.Properties.VariableNames));
    
                        % Converte para tabela
                        tableOutAll = array2table(stringMatrix, 'VariableNames', x3.Properties.VariableNames);
                        tableOutAll.REG(1:end) = Tabletype{3};
    
                        for ii = 1:height(linesIniIdx_Tabletype3)    
                            if nTabletype == 3
                                % Cria uma matriz de strings vazias
                                stringMatrix = strings(height(x1), numel(x3.Properties.VariableNames));
    
                                % Converte para tabela
                                tableOutAll = array2table(stringMatrix, 'VariableNames', x3.Properties.VariableNames);    
                                tableOutAll.REG(1:end) = Tabletype{2};
    
                                if ii == 1
                                    numReps = linesTabletype1(1);
                                else
                                    numReps = numReps + linesTabletype1(ii);
                                end
    
                                newRow = x3(ii,:);
                                tableOutAll(numReps,:) = newRow;    
                            end
                        end

                    otherwise
                        error('Unexpected value')
                end
            end

            switch numel(tableId)
                case 2
                    tableOutAll{2}.REG = strcat(tableOutAll{2}.REG, '-', tableOutAll{1}.REG);
                    tableOutAll{1}     = removevars(tableOutAll{1}, 'REG');
                    tableOut_others    = [tableOutAll{2}, tableOutAll{1}];

                case 3
                    tableOutAll{1}.REG = strcat(tableOutAll{1}.REG, '-', tableOutAll{2}.REG, '-', tableOutAll{3}.REG);
                    tableOutAll{2}     = removevars(tableOutAll{2}, 'REG');
                    tableOutAll{3}     = removevars(tableOutAll{3}, 'REG');
                    tableOutAll{3}     = removevars(tableOutAll{3}, 'COD_CCUS');
                    tableOut_others    = [tableOutAll{1}, tableOutAll{2}, tableOutAll{3}];

                otherwise
                    error('Unexpected value')
            end
        end

        %-----------------------------------------------------------------%
        function tableDinamica = tableDinamica_I150_I155_I350_I355(obj, leftTable)
            arguments
                obj
                leftTable;
            end

            checkIfScalar(obj)

            Cod_CTA_I155_Din = unique(leftTable.COD_CTA, 'stable');
            tableDinamica    = table('Size', [height(Cod_CTA_I155_Din), 14], ...
                                     'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                                     'VariableNames',  {'COD_CTA'	'MES01',	'MES02',	'MES03',	'MES04',	'MES05',	'MES06',	'MES07',	'MES08',	'MES09',	'MES10',	'MES11',	'MES12',	'MesTotal_Geral'});

            for ii = 1: 1:height(Cod_CTA_I155_Din)
                index_COD_CTA_Din = find(strcmp(leftTable.COD_CTA, Cod_CTA_I155_Din{ii}));
                kk = 1;
                Val_Mes = zeros(1, 12);

                for jj = 1:12
                    month_list = month(leftTable.DT_INI(index_COD_CTA_Din));
                    if kk <= numel(month_list)
                        if month_list(kk) == jj
                            Val_Mes(jj) = leftTable.Mov_I155_I355(index_COD_CTA_Din(kk));
                            kk = kk + 1;
                        else
                            Val_Mes(jj) = "0";
                        end
                    else
                        Val_Mes(jj) = "0";
                    end
                end
                Valor_Total_Mes = sum(Val_Mes);

                tableDinamica(ii,:) = [Cod_CTA_I155_Din(ii), num2cell([Val_Mes, Valor_Total_Mes])];
            end
        end

        %-----------------------------------------------------------------%
        function tableDinamica = lucrAcum_I150_I155_I350_I355(obj, tableDinamica)
            arguments
                obj;
                tableDinamica;
            end

            idx_LC        = find(strcmp(obj.Table.xI050.CTA, "LUCROS ACUMULADOS"));
            Value_idx_200 = obj.Table.xI050.COD_CTA(idx_LC);
            idx_LC_200    = find(strcmp(obj.Table.xI250.COD_CTA, string(Value_idx_200)));
            filter_LC     = obj.Table.xI250(idx_LC_200,:);
            idx_Filter_LC = find(strcmp(filter_LC.COD_HIST_PAD, "350"));

            for yy = 1:numel(filter_LC.VL_DC)
                if strcmp(filter_LC.IND_DC(yy), "D")
                    filter_LC.VL_DC(yy) = -abs(filter_LC.VL_DC(yy));
                end
            end
            Value_Real    = sum(filter_LC.VL_DC (idx_Filter_LC,:));

            idx_tab_dinam = find(strcmp(tableDinamica.COD_CTA, Value_idx_200));
            tableDinamica.MES02(idx_tab_dinam) = "0";
            tableDinamica.MES03(idx_tab_dinam) = "0";
            tableDinamica.MES04(idx_tab_dinam) = "0";
            tableDinamica.MES05(idx_tab_dinam) = "0";
            tableDinamica.MES06(idx_tab_dinam) = "0";
            tableDinamica.MES07(idx_tab_dinam) = "0";
            tableDinamica.MES08(idx_tab_dinam) = "0";
            tableDinamica.MES09(idx_tab_dinam) = "0";
            tableDinamica.MES10(idx_tab_dinam) = "0";
            tableDinamica.MES11(idx_tab_dinam) = "0";

            tableDinamica.MES12(idx_tab_dinam) = Value_Real - str2double(tableDinamica.MES01(idx_tab_dinam));
            tableDinamica.MesTotal_Geral(idx_tab_dinam) = Value_Real;
            tableDinamica = sortrows(tableDinamica, 'COD_CTA');
        end
    end


    methods (Static = true)
        %-----------------------------------------------------------------%
        % MÉTODOS ESTÁTICOS
        %-----------------------------------------------------------------%
        function value = defaultValue(dataType)
            switch dataType
                case 'cell';     value = {''};
                case 'datetime'; value = datetime([0,0,0,0,0,0]);                                
                case 'double';   value = -1;
                otherwise;       error('UnexpectedValue')
            end
        end
    end
end