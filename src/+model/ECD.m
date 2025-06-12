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
        function tableOutIdtypes = tableTypes1And3 (obj, idtype, tabletype)

                % Filtras as linhas com as informações do primeiro  do segundo tabletype
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

        function [linesTabletype1, linesIniIdxTabletype2] = tableTypesLines (obj, tableId,  Tabletype, typeCase)
            switch typeCase
                case 1
                    tabletypeFirst  = Tabletype{1};
                    tabletypeSecond = Tabletype{2};
                case 2
                    tabletypeFirst  = Tabletype{1};
                    tabletypeSecond = Tabletype{3};
            end
            regexPattern = ['^\|(' tabletypeFirst '|' tabletypeSecond ')\|[^\r\n]*'];
            regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';
            regexMatchesTabletype1Tabletype2 = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);

            % Criar vetor lógico indicando onde I355 aparece
            isMatch = contains(regexMatchesTabletype1Tabletype2, tableId);
            % Identifica o númeor de linhas que contém as sequências consecutivas de REG em "I355"
            diffValues = diff([0; isMatch; 0]); % Adiciona zeros no início e fim para capturar grupos
            startIndices = find(diffValues == 1); % Início de um grupo
            endIndices = find(diffValues == -1) - 1; % Fim de um grupo
            linesTabletype1 = endIndices - startIndices + 1;

            % Identifica as linhas com a informações de tableId
            linesIniIdxTabletype2 = find(contains(regexMatchesTabletype1Tabletype2, Tabletype{2}));
        end

        function tableI150_I155_CTA = inseriCodCTA(obj, tableI150_I155)
            I050_CTA = obj.Table.xI050;

            % Selecionar apenas a coluna 'CTA' e a chave
            I050_CTA_reduzida = I050_CTA(:, {'COD_CTA', 'CTA'});

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
        %-----------------------------------------------------------------%
        function [tableOutAllTypes, soma_Mov_I155, soma_Mov_I355] = parseSplitLine(obj, tableId)
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
                    case 1
                        if ~isempty(obj.Table.xI150)
                            tableOut_I150_155_350_355{mm} = tableTypes1And3(obj, mm, tableId);
                        end
                    case 2
                        if ~isempty(obj.Table.xI155)
                            tableOut_I150_155_350_355{mm} = obj.Table.xI155;
                        end
                    case 3
                        if ~isempty(obj.Table.xI350)
                            tableOut_I150_155_350_355{mm} = tableTypes1And3(obj, mm, tableId);
                        end
                    case 4
                        if ~isempty(obj.Table.xI355)
                            tableOut_I150_155_350_355{mm} = obj.Table.xI355;
                        end
                end
            end

            if ~isempty(obj.Table.xI150)
                tableOut_I150_155_350_355{1}.REG = strcat(tableOut_I150_155_350_355{1}.REG, '-', tableOut_I150_155_350_355{2}.REG);
                tableOut_I150_155_350_355{2} = removevars(tableOut_I150_155_350_355{2}, 'REG');

                % Concatena as tabelas I150 e I155
                tableI150_I155 = [tableOut_I150_155_350_355{1}, tableOut_I150_155_350_355{2}];

                tableI150_I155 = inseriCodCTA(obj, tableI150_I155);

                if ~isempty(obj.Table.xI350)
                    tableOut_I150_155_350_355{3}.REG = strcat(tableOut_I150_155_350_355{3}.REG, '-', tableOut_I150_155_350_355{4}.REG);
                    tableOut_I150_155_350_355{4}     = removevars(tableOut_I150_155_350_355{4}, 'REG');

                    % Concatenar colunas das tabelas I350 e I355
                    tableI350_I355 = [tableOut_I150_155_350_355{3}, tableOut_I150_155_350_355{4}];

                    % Cria tabela de nulos de T_I350_I355 com mesmo númeor de linhas de T_I150_I155
                    tableI350_I355Null = table('Size', [height(tableI150_I155), width(tableI350_I355)], ...
                        'VariableTypes', varfun(@class, tableI350_I355, 'OutputFormat', 'cell'), ...
                        'VariableNames', tableI350_I355.Properties.VariableNames);

                    tableI350_I355Null.REG(:,:) = {char};
                    tableI350_I355Null.COD_CTA(:,:) = {char};
                    tableI350_I355Null.COD_CCUS(:,:) = {char};
                    tableI350_I355Null.IND_DC(:,:) = {char};
                    tableI350_I355Null.IND_DC_MF(:,:) = {char};

                    tableI350_I355Null.REG(:) = repmat({strcat(tableId{3}, '-', tableId{4})}, height(tableI350_I355Null), 1);

                    tableI150_I155.REG = strcat(tableI150_I155.REG, '-', tableI350_I355Null.REG);

                    tableI350_I355Null = removevars(tableI350_I355Null, 'REG');
                    tableI350_I355Null = removevars(tableI350_I355Null, 'COD_CTA');
                    tableI350_I355Null = removevars(tableI350_I355Null, 'COD_CCUS');

                    % Concatena as colunas das tabelas T_I150_I155 e T_I350_I355_Null
                    tableI150_I155_I350_I355Null = [tableI150_I155, tableI350_I355Null];

                    % Concatenar as tabelas T_I150_I155 e T_I350_I355
                    I150_I155_I350_I355 = [];

                    datas_I350 = obj.Table.xI350.DT_RES;

                    lineIni = 1;

                    for kk = 1:numel(datas_I350)
                        I155Parcial = tableI150_I155(tableI150_I155.DT_FIN == datas_I350(kk),:);
                        
                        I355Parcial = tableI350_I355(tableI350_I355.DT_RES == datas_I350(kk),:);                       

                        I155Parcial.ordem_original = (1:height(I155Parcial))';

                        indexDatasI350 = find(tableI150_I155.DT_FIN == datas_I350(kk));

                        I155Parcial.COD_CTA = string(I155Parcial.COD_CTA);
                        I155Parcial.COD_CCUS = string(I155Parcial.COD_CCUS);
                        I355Parcial.COD_CTA = string(I355Parcial.COD_CTA);
                        I355Parcial.COD_CCUS = string(I355Parcial.COD_CCUS);
                        I155I355Parcial = outerjoin(I155Parcial, I355Parcial, ...
                            'Keys', {'COD_CTA', 'COD_CCUS'}, ...
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

                        I150_I155_I350_I355 = [I150_I155_I350_I355; I150_I155_I350_I355_Null; I155I355Parcial];
                    end

                    % Calcula os valores de Mov_I155 e de Mov_I155_I355
                    idx_IND_DC_INI_D = find(I150_I155_I350_I355.IND_DC_INI == "D");
                    I150_I155_I350_I355.VL_SLD_INI(idx_IND_DC_INI_D) = -abs(I150_I155_I350_I355.VL_SLD_INI(idx_IND_DC_INI_D));

                    idx_IND_DC_FIN_D = find(I150_I155_I350_I355.IND_DC_FIN == "D");
                    I150_I155_I350_I355.VL_SLD_FIN(idx_IND_DC_FIN_D) = -abs(I150_I155_I350_I355.VL_SLD_FIN(idx_IND_DC_FIN_D));

                    idx_VL_CTA_D = find(I150_I155_I350_I355.IND_DC == "D");
                    I150_I155_I350_I355.VL_CTA = I150_I155_I350_I355.VL_CTA;
                    I150_I155_I350_I355.VL_CTA(idx_VL_CTA_D) = -abs(I150_I155_I350_I355.VL_CTA(idx_VL_CTA_D));
                    I150_I155_I350_I355.VL_CTA(isnan(I150_I155_I350_I355.VL_CTA)) = 0;

                    I150_I155_I350_I355.Mov_I155 = I150_I155_I350_I355.VL_SLD_FIN - I150_I155_I350_I355.VL_SLD_INI;
                    I150_I155_I350_I355.Mov_I155_I355 = I150_I155_I350_I355.Mov_I155 + I150_I155_I350_I355.VL_CTA;

                else
                    I150_I155_I350_I355 = tableI150_I155;

                    % Calcula os valores de Mov_I155 e de Mov_I155_I355
                    idx_IND_DC_INI_D = find(I150_I155_I350_I355.IND_DC_INI == "D");
                    I150_I155_I350_I355.VL_SLD_INI(idx_IND_DC_INI_D) = -abs(I150_I155_I350_I355.VL_SLD_INI(idx_IND_DC_INI_D));

                    idx_IND_DC_FIN_D = find(I150_I155_I350_I355.IND_DC_FIN == "D");
                    I150_I155_I350_I355.VL_SLD_FIN(idx_IND_DC_FIN_D) = -abs(I150_I155_I350_I355.VL_SLD_FIN(idx_IND_DC_FIN_D));

                    I150_I155_I350_I355.Mov_I155 = I150_I155_I350_I355.VL_SLD_FIN - I150_I155_I350_I355.VL_SLD_INI;
                    I150_I155_I350_I355.Mov_I155_I355 = I150_I155_I350_I355.Mov_I155;
                end
            else
                I150_I155_I350_I355 = [];
            end

            if ~isempty(I150_I155_I350_I355)
                soma_Mov_I155 = sum(I150_I155_I350_I355.Mov_I155);
                soma_Mov_I355 = sum(I150_I155_I350_I355.Mov_I155_I355);
            else
                soma_Mov_I155 = -1;
                soma_Mov_I355 = -1;
            end

            tableOutAllTypes = I150_I155_I350_I355;
        end

        %-----------------------------------------------------------------%
        function tableOutOthers = parseSplitLineOthers(obj, tableId)
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
                            tableOutOthers = [];
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
                case "J150"
                    for mm = 1: numel(tableId)
                        tableOutAll{mm} = linesTableId(obj, mm, tableId, obj.Table.xJ150, obj.Table.xJ005, []);
                    end
            end

            function tableOutAll = linesTableId(obj, idtype, Tabletype, x1, x2, x3)
                tableOutAll = [];
                nTabletype  = numel(Tabletype);

                switch idtype
                    case 1
                        tableOutAll = x1;

                    case 2

                        [linesTabletype1, linesIniIdxTabletype2] = tableTypesLines (obj, tableId{1}, Tabletype, 1);
    
                        switch nTabletype
                            case 2
                                numReps     = linesTabletype1;
                                % Criação de índices para replicação
                                idx = repelem(1:size(x2,1), numReps);

                                % Repetir linhas
                                tableOutAll = x2(idx, :);

                            case 3
                                for ii = 1:height(linesIniIdxTabletype2)

                                    % Cria tabela de nulos de x2 com mesmo número de linhas de x1
                                    tableOutAll = table('Size', [height(x1), width(x2)], ...
                                        'VariableTypes', varfun(@class, x2, 'OutputFormat', 'cell'), ...
                                        'VariableNames', x2.Properties.VariableNames);

                                    tableOutAll.REG(:,:)         = {char};
                                    tableOutAll.COD_CCUS(:,:)    = {char};
                                    tableOutAll.COD_CTA_REF(:,:) = {char};

                                    tableOutAll.REG(1:end) = cellstr(Tabletype{2});

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

                        [linesTabletype1, linesIniIdxTabletype2] = tableTypesLines (obj, tableId{1}, Tabletype, 2);

                        % Cria tabela de nulos de x3 com mesmo número de linhas de x1
                        tableOutAll = table('Size', [height(x1), width(x3)], ...
                            'VariableTypes', varfun(@class, x3, 'OutputFormat', 'cell'), ...
                            'VariableNames', x3.Properties.VariableNames);

                        tableOutAll.REG(:,:)      = {char};
                        tableOutAll.COD_CCUS(:,:) = {char};
                        tableOutAll.COD_AGL(:,:)  = {char};

                        tableOutAll.REG(1:end) = cellstr(Tabletype{3});
    
                        for ii = 1:height(linesIniIdxTabletype2)    
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
                    tableOutOthers    = [tableOutAll{2}, tableOutAll{1}];

                case 3
                    tableOutAll{1}.REG = strcat(tableOutAll{1}.REG, '-', tableOutAll{2}.REG, '-', tableOutAll{3}.REG);
                    tableOutAll{2}     = removevars(tableOutAll{2}, 'REG');
                    tableOutAll{3}     = removevars(tableOutAll{3}, 'REG');
                    tableOutAll{3}     = removevars(tableOutAll{3}, 'COD_CCUS');
                    tableOutOthers    = [tableOutAll{1}, tableOutAll{2}, tableOutAll{3}];

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

                tableDinamica(ii,:) = [ { {Cod_CTA_I155_Din(ii)} }, num2cell([Val_Mes, Valor_Total_Mes]) ];
            end
        end

        %-----------------------------------------------------------------%
        function tableDinamica = lucrAcum_I150_I155_I350_I355(obj, tableDinamica, Table_I200_I250)
            arguments
                obj;
                tableDinamica;
                Table_I200_I250;
            end

            Sum_month_Lucr=0;
            Sum_month_Prej=0;

                if ~isempty(find(strcmp(obj.Table.xI050.CTA, "LUCROS ACUMULADOS"), 1))
                    idx_LC_Lucr        = find(strcmp(obj.Table.xI050.CTA, "LUCROS ACUMULADOS"));
                    idx_200_Lucr       = obj.Table.xI050.COD_CTA(idx_LC_Lucr);
                    idx_LC_200_Lucr    = find(strcmp(Table_I200_I250.COD_CTA, string(idx_200_Lucr)));
                    filter_LC_200_Lucr = Table_I200_I250(idx_LC_200_Lucr,:);

                    idx_filter_LC_IND_DC_D_Lucr = find(filter_LC_200_Lucr.IND_DC == "D");
                    filter_LC_200_Lucr.VL_DC(idx_filter_LC_IND_DC_D_Lucr) = -abs(filter_LC_200_Lucr.VL_DC(idx_filter_LC_IND_DC_D_Lucr));

                    % soma_VL_DC = sum(filter_LC.VL_DC);

                    % str = string(filter_LC_200_Lucr.HIST);
                    % 
                    % % Expressão regular para datas no formato dd.mm.yyyy ou dd-mm-yyyy
                    % padraoData = "\d{2}.\d{2}.\d{4}|\d{2}-\d{2}-\d{4}";
                    % 
                    % idxtData_Lucr = ~cellfun('isempty', regexp(str, padraoData));
                    % 
                    % filter_Table_I250_Lucr = filter_LC_200_Lucr.VL_DC(~idxtData_Lucr,:);
                    filter_Table_I250_Lucr = filter_LC_200_Lucr;

                    Sum_month_Lucr = sum(filter_Table_I250_Lucr.VL_DC);

                    % idx_tab_dinam = find(strcmp(string(tableDinamica.COD_CTA), idx_200_Lucr));
                    % tableDinamica(idx_tab_dinam, 3:12) = array2table(repmat(0, numel(idx_tab_dinam), numel(3:12)));
                    
                    if ~isempty(find(strcmp(obj.Table.xI050.CTA, "(-) PREJUIZOS ACUMULADOS"), 1))
                        idx_LC_Prej        = find(strcmp(obj.Table.xI050.CTA, "(-) PREJUIZOS ACUMULADOS"));
                        idx_200_Prej       = obj.Table.xI050.COD_CTA(idx_LC_Prej);
                        idx_LC_200_Prej    = find(strcmp(Table_I200_I250.COD_CTA, string(idx_200_Prej)));
                        filter_LC_200_Prej = Table_I200_I250(idx_LC_200_Prej,:);
    
                        idx_filter_LC_IND_DC_D_Prej = find(filter_LC_200_Prej.IND_DC == "D");
                        filter_LC_200_Prej.VL_DC(idx_filter_LC_IND_DC_D_Prej) = -abs(filter_LC_200_Prej.VL_DC(idx_filter_LC_IND_DC_D_Prej));
    
                        % soma_VL_DC = sum(filter_LC.VL_DC);
    
                        % str = string(filter_LC_200_Prej.HIST);
                        % 
                        % % Expressão regular para datas no formato dd.mm.yyyy ou dd-mm-yyyy
                        % padraoData = "\d{2}.\d{2}.\d{4}|\d{2}-\d{2}-\d{4}";
                        % 
                        % idxtData_Prej = ~cellfun('isempty', regexp(str, padraoData));
                        % 
                        % filter_Table_I250_Prej = filter_LC_200_Prej.VL_DC(~idxtData_Prej,:);

                        filter_Table_I250_Prej = filter_LC_200_Prej;
    
                        Sum_month_Prej = sum(filter_Table_I250_Prej.VL_DC);
                    end

                    Sum_total_month = Sum_month_Lucr + Sum_month_Prej

                    % tableDinamica.MES12(idx_tab_dinam) = Sum_month_Prej - tableDinamica.MES01(idx_tab_dinam);
                    % tableDinamica.MesTotal_Geral(idx_tab_dinam) = Sum_month_Prej;
                    % 
                    % tableDinamica.COD_CTA = string(tableDinamica.COD_CTA);
                    % tableDinamica = sortrows(tableDinamica, 'COD_CTA');

                    
                elseif ~isempty(find(strcmp(obj.Table.xI050.CTA, "LUCROS OU PREJUIZOS ACUMULADOS"), 1))
                    idx_LC_Prej        = find(strcmp(obj.Table.xI050.CTA, "LUCROS OU PREJUIZOS ACUMULADOS"));
                    idx_LC_Prej = idx_LC_Prej(2);
                    idx_200_Prej = obj.Table.xI050.COD_CTA(idx_LC_Prej);
                    idx_LC_200_Prej    = find(strcmp(obj.Table.xI250.COD_CTA, string(idx_200_Prej)));
                    filter_LC_200_Prej     = obj.Table.xI250(idx_LC_200_Prej,:);

                    idx_filter_LC_IND_DC_D_Lucr = find(filter_LC_200_Prej.IND_DC == "D");
                    filter_LC_200_Prej.VL_DC(idx_filter_LC_IND_DC_D_Lucr) = -abs(filter_LC_200_Prej.VL_DC(idx_filter_LC_IND_DC_D_Lucr));

                    soma_VL_DC = sum(filter_LC_200_Prej.VL_DC);

                    idx_tab_dinam = find(strcmp(tableDinamica.COD_CTA, idx_200_Prej));
                    tableDinamica(idx_tab_dinam, 2:11) = array2table(repmat(0, numel(idx_tab_dinam), numel(2:11)));

                    tableDinamica.MES12(idx_tab_dinam) = soma_VL_DC - tableDinamica.MES12(idx_tab_dinam);
                    tableDinamica.MesTotal_Geral(idx_tab_dinam) = tableDinamica.MES01(idx_tab_dinam);

                    tableDinamica.COD_CTA = string(tableDinamica.COD_CTA);
                    tableDinamica = sortrows(tableDinamica, 'COD_CTA');
                else
                    tableDinamica = tableDinamica;
                end
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