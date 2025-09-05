classdef ECD < model.ECDBase

    % Inicialização:
    % >> ecdObj = model.ECD.empty;

    % Leitura de arquivos:
    % >> ecdObj = addFiles(ecdObj, {'Filename1', 'Filename2'});

    properties
        %-----------------------------------------------------------------%
        CompanyName
        CompanyId
        CompanyInfo = struct('CNPJ', {}, 'IE', {}, 'IM', {}, 'NIRE', {}, 'UF', {}, 'City', {})

        Period = []
        PeriodMerged = false

        FileName
        FileFullName
        FileEncoding
        
        FileHash   = ''
        FileStatus = 0 % -2 (Erro) | -1 (Diverge) | 0 (Pendente) | 1 (Coincide)
        ReceitaFederal

        Content
        Layout
        Table
                
        GUI  = struct('isRead', false,  ...
                      'warnings', {{}}, ...
                      'rtfFiles', {{}}, ...
                      'tableView', struct('id', {}, 'widths', {}, 'filters', {}, 'style', {}));
        UUID = char(matlab.lang.internal.uuid())
    end

    methods (Access = public)
        %-----------------------------------------------------------------%
        % MÉTODOS RELACIONADOS AO OBJETO VISTO COMO UM ARRAY
        % (ESCALAR, OU NÃO)
        %-----------------------------------------------------------------%
        function [obj, msg] = addFiles(obj, fileNameList, fileEncoding, receitaFederalObj, mergeFlag, tableIdList)
            arguments
                obj
                fileNameList
                fileEncoding (1,:) char    = 'ISO-8859-1'
                receitaFederalObj          = []
                mergeFlag    (1,1) logical = false
                tableIdList  (1,:) cell    = {'0000', 'I030', '9900'}
            end

            if ~iscellstr(fileNameList)
                fileNameList = cellstr(fileNameList);
            end

            msg = {};

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
                    obj(idx).Content      = fileread(fileFullName, 'Encoding', fileEncoding);
                    obj(idx).FileEncoding = fileEncoding;

                    % Leitura da ficha "I010", identificando o layout do
                    % arquivo. Como essa ficha não mudou ao longo do tempo, 
                    % considera-se que o layout é igual a 1, mas depois de 
                    % lida a ficha, o valor é atualizado.

                    % A outra ficha lida no início do processo é a "I010",
                    % que registra os campos opcionais, caso aplicável.

                    obj(idx).Layout = 1;
                    parseTableAndAddToCache(obj(idx), {'I010'})

                    obj(idx).Layout = obj(idx).Table.xI010.COD_VER_LC(1);                    
                    parseTableAndAddToCache(obj(idx), tableIdList)

                    if isfield(obj(idx).Table, 'x0000') && ~isempty(obj(idx).Table.x0000)
                        obj(idx).CompanyName    = obj(idx).Table.x0000.NOME{1};
                        obj(idx).CompanyId      = checkCNPJOrCPF(obj(idx).Table.x0000.CNPJ{1}, 'NumberValidation');
                        obj(idx).CompanyInfo(1) = struct('CNPJ',  obj(idx).Table.x0000.CNPJ{1}, ...
                                                         'IE',    obj(idx).Table.x0000.IE{1},   ...
                                                         'IM',    obj(idx).Table.x0000.IM{1},   ...
                                                         'NIRE',  '',                           ...
                                                         'UF',    obj(idx).Table.x0000.UF{1},   ...
                                                         'City',  obj(idx).Table.x0000.COD_MUN{1});

                        obj(idx).Period = [min(obj(idx).Table.x0000.DT_INI), max(obj(idx).Table.x0000.DT_FIN)];
                        obj(idx).Period.Format = 'dd/MM/yyyy';
                    end

                    if isfield(obj(idx).Table, 'xI030') && ~isempty(obj(idx).Table.xI030)
                         obj(idx).CompanyInfo(1).NIRE = obj(idx).Table.xI030.NIRE{1};
                    end

                    obj(idx).FileHash     = util.calculateFileHash(obj(idx).Content, fileEncoding);
                    if ~isempty(receitaFederalObj)
                        checkFileStatus(obj(idx), receitaFederalObj);
                    end
                    obj(idx).PeriodMerged = mergeFlag;

                catch ME
                    delete(obj(idx))
                    obj(idx) = [];
                    msg{end+1} = ME.message;
                end
            end

            msg = strjoin(msg, '\n');
        end

        %-----------------------------------------------------------------%
        function parseTableAndAddToCache(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText} = {'all'}
            end

            if isequal(tableIdList, {'all'})
                isRead = true;
                tableIdList = model.ECDBase.checkImplementedTables();
            end

            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};

                    if isfield(obj(ii).Table, ['x' tableId])
                        continue
                    end

                    obj(ii).Table.(['x' tableId]) = parseTable(obj(ii), tableId);

                    % Valida se foi lido o número de linhas esperado...
                    if isfield(obj(ii).Table, 'x9900')
                        tableIdIndex = find(strcmp(obj(ii).Table.x9900.("REG_BLC"), tableId));
                        if ~isempty(tableIdIndex)
                            expectedRows = sum(obj(ii).Table.x9900.("QTD_REG_BLC")(tableIdIndex));
                            readRows     = height(obj(ii).Table.(['x' tableId]));                            
                            if expectedRows ~= readRows
                                obj(ii).GUI.warnings{end+1} = jsonencode(struct('id', tableId, 'expectedRows', expectedRows, 'readRows', readRows));
                            end
                        end
                    end
                end

                if exist('isRead', 'var')
                    obj(ii).GUI.isRead = isRead;
                end
            end
        end

        %-----------------------------------------------------------------%
        function customMergedTablesKeyOriented(obj, tableIdList, parameters)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
                parameters struct
            end

            % - "key-oriented"
            % parameters(1) = struct('fcn', 'outerjoin', 'leftId', 'I050', 'rightId', 'I155', 'args', {{'LeftKeys', 'COD_CTA', 'RightKeys', 'COD_CTA', 'MergeKeys', true, 'Type', 'full'}})
            % parameters(2) = struct('fcn', 'innerjoin', 'leftId', '*',    'rightId', 'I165', 'args', {{'LeftKeys', 'COD_CTA', 'RightKeys', 'COD_CTA', 'MergeKeys', true, 'Type', 'full'}})

            mergedTableId = ['x_' strjoin(tableIdList, '_') '_KeyOriented'];

            for ii = 1:numel(obj)
                if isfield(obj(ii).Table, mergedTableId)
                    continue
                end

                isTableRead(obj(ii), tableIdList)

                mergedTable = obj(ii).Table.(['x' parameters(1).leftId]);
                for jj = 1:numel(parameters)
                    joinFcn   = str2func(parameters(jj).fcn);
                    joinArgs  = parameters(jj).args;
                    leftTable = mergedTable;                            

                    if isfield(parameters(jj), 'rightTable')
                        rightTable = parameters(jj).rightTable;
                    elseif isfield(parameters(jj), 'rightId')
                        rightTable = obj(ii).Table.(['x' parameters(jj).rightId]);
                    else
                        error('UnexpectedField')
                    end

                    mergedTable = joinFcn(leftTable, rightTable, joinArgs{:});
                end

                obj(ii).Table.(mergedTableId) = mergedTable;
            end
        end

        %-----------------------------------------------------------------%
        function customMergedTablesRowOriented(obj, mainId, secundaryIds, secundaryIdsKey)
            arguments
                obj
                mainId          (1,:) char              = 'I050'            % 'C050'
                secundaryIds    (1,2) cell {mustBeText} = {'I051', 'I052'}  % {'C051', 'C052'}
                secundaryIdsKey (1,:) char              = 'COD_CCUS'
            end

            tableIdList     = [mainId, secundaryIds];
            tableIdFileList = strcat('|', tableIdList, '|');

            mergedTableId   = ['x_' strjoin(tableIdList, '_') '_RowOriented'];

            for ii = 1:numel(obj)
                if isfield(obj(ii).Table, mergedTableId)
                    continue
                end

                isTableRead(obj(ii), {mainId})

                splitContent = splitlines(obj(ii).Content);

                % Em relação à tabela principal:                
                % mainIdFile   = ['|', mainId, '|'];
                % mainFileIdx  = find(startsWith(splitContent, mainIdFile));

                fileIndexes  = cellfun(@(x) find(startsWith(splitContent, x)), tableIdFileList, 'UniformOutput', false);
                mainFileIdx  = fileIndexes{1};

                mainIdTable  = ['x', mainId];                
                mainTable    = obj(ii).Table.(mainIdTable);
                if isempty(mainTable)
                    return
                end

                mainTableHeight = height(mainTable);
                mainTable.("_TEMP_KEY") = (1:mainTableHeight)';
                
                % Em relação às tabelas auxiliares:
                secundaryTable = [];
                secundarySpec  = getColumnSpecifications(obj(ii), secundaryIds, 'index');

                for jj = 1:mainTableHeight
                    currentIdx  = mainFileIdx(jj);
                    if jj < mainTableHeight
                        nextIdx = mainFileIdx(jj+1);
                    else
                        nextIdx = currentIdx+1;
                        while true
                            if nextIdx < numel(splitContent) && any(cellfun(@(x) startsWith(splitContent{nextIdx}, x), strcat('|', {secundarySpec.id}, '|')))
                                nextIdx = nextIdx+1;
                            else
                                break;
                            end
                        end
                    end
    
                    if nextIdx == currentIdx+1
                        continue
                    end
    
                    % Para cada bloco entre duas linhas |mainId|, parseiam-se
                    % as tabelas auxiliares, guardando-as em "tempTable".
                    % E, posteriormente, mesclam-se essas tabelas auxiliares,
                    % guardando-as em "secundaryTable".
                    blockLines = splitContent(currentIdx+1 : nextIdx-1);
                    refTable = [];

                    for kk = 1:numel(secundarySpec)
                        tempTable = parseFileBlock(obj(ii), blockLines, secundarySpec(kk), true);
                        if isempty(tempTable)
                            continue
                        end

                        preffixCol = secundarySpec(kk).preffix;
                        tempTable.Properties.VariableNames = replace(tempTable.Properties.VariableNames, strcat(preffixCol, secundaryIdsKey), secundaryIdsKey);

                        if isempty(refTable)
                            refTable = tempTable;
                        else
                            if all(cellfun(@(x) isempty(x), refTable.(secundaryIdsKey))) && all(cellfun(@(x) isempty(x), tempTable.(secundaryIdsKey)))
                                % Cria uma chave p/ forçar concatenação da
                                % informação, caso necessário.
                                refTable.(secundaryIdsKey)(:)  = {'-1'};
                                tempTable.(secundaryIdsKey)(:) = {'-1'};
                                refTable = outerjoin(refTable, tempTable, 'Keys', secundaryIdsKey, 'MergeKeys', true, 'Type', 'full');
                                refTable.(secundaryIdsKey)(:)  = {''};
                            else
                                refTable = outerjoin(refTable, tempTable, 'Keys', secundaryIdsKey, 'MergeKeys', true, 'Type', 'full');
                            end
                        end
                    end

                    if isempty(refTable)
                        continue
                    end

                    refTable.Properties.VariableNames = replace(refTable.Properties.VariableNames, secundaryIdsKey, strcat('_', secundaryIdsKey));
                    refTable.("_TEMP_KEY")(:) = jj;

                    if isempty(secundaryTable)
                        secundaryTable = refTable;
                    else
                        secundaryTable = outerjoin(secundaryTable, refTable, 'MergeKeys', true, 'Type', 'full');
                    end
                end

                mergedTable = outerjoin(mainTable, secundaryTable, 'Keys', '_TEMP_KEY', 'MergeKeys', true, 'Type', 'left');
                mergedTable = removevars(mergedTable, '_TEMP_KEY');

                obj(ii).Table.(mergedTableId) = mergedTable;
            end
        end

        %-----------------------------------------------------------------%
        function isTableRead(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
            end

            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};
                    if ~isfield(obj(ii).Table, ['x' tableId])
                        parseTableAndAddToCache(obj(ii), {tableId})
                    end
                end
            end
        end

        %-----------------------------------------------------------------%
        function checkFileFlag = checkFileStatus(obj, receitaFederalObj, fileEncoding, terminator)
            arguments
                obj
                receitaFederalObj ws.ReceitaFederal
                fileEncoding (1,:) char  = 'ISO-8859-1'
                terminator   (1,2) uint8 = [13, 10]
            end

            % Se o registro for resultado da mesclagem de fluxos, ou se o 
            % registro já tiver sido validado na base da Receita Federal,
            % então não é feita uma nova requisição à API.
            checkFileFlag = false;

            for ii = 1:numel(obj)
                if obj(ii).PeriodMerged || ismember(obj(ii).FileStatus, [-1, 1])
                    continue
                end

                try
                    requestAnswer = Get(receitaFederalObj, 'Cache+RealTime', 'ECD', obj(ii).FileHash);
                    obj(ii).ReceitaFederal = requestAnswer;

                    if ~isempty(requestAnswer) && isstruct(requestAnswer) && isfield(requestAnswer, 'retVerif')
                        if contains(requestAnswer.retVerif, 'mesma', 'IgnoreCase', true)
                            obj(ii).FileStatus = 1;
                        elseif contains(requestAnswer.retVerif, 'não', 'IgnoreCase', true)
                            obj(ii).FileStatus = -1;
                        else
                            obj(ii).FileStatus = -2;
                        end
                    else
                        obj(ii).FileStatus = -2;
                    end

                catch ME
                    obj(ii).FileStatus = -2;
                    obj(ii).ReceitaFederal = ME.message;
                end

                checkFileFlag = true;
            end
        end

        %-----------------------------------------------------------------%
        function index = findSpecificObject(obj, uuid)
            index = find(strcmp({obj.UUID}, uuid), 1);
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
        function [ordinaryIds, customIds, readOrdinaryIds] = getTableIds(obj, nonemptyFlag)
            arguments
                obj 
                nonemptyFlag = true
            end

            checkIfScalar(obj)

            tableNames = fieldnames(obj.Table);
            if nonemptyFlag
                tableNames(cellfun(@(x) isempty(obj.Table.(x)), tableNames)) = [];
            end

            customIds = tableNames(startsWith(tableNames, 'x_'));
            readOrdinaryIds = setdiff(tableNames, customIds);

            customIds = extractAfter(sort(customIds), 'x');
            readOrdinaryIds = extractAfter(sort(readOrdinaryIds), 'x');

            if isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                ordinaryIds = unique(obj.Table.x9900.("REG_BLC"));
            else
                ordinaryIds = {'-1'};
            end            
        end

        %-----------------------------------------------------------------%
        function tableOut = parseFileBlock(obj, fileBlock, columnsSpec, regexpFlag)
            arguments
                obj
                fileBlock
                columnsSpec % struct('id', {}, 'preffix', {}, 'requiredCol', {}, 'optionalCol', {}, 'completeCol', {})
                regexpFlag = false
            end           

            checkIfScalar(obj)

            if regexpFlag
                fileBlock = fileBlock(startsWith(fileBlock, ['|' columnsSpec.id '|']));
                if isempty(fileBlock)
                    tableOut = [];
                    return
                end
            end

            mergedFileBlock = split(cellfun(@(x) x(2:end-1), fileBlock, 'UniformOutput', false), '|', 2);

            switch width(mergedFileBlock)
                case numel(columnsSpec.required)
                    tableOut = cell2table(mergedFileBlock, 'VariableNames', strcat(columnsSpec.preffix, columnsSpec.required));

                    for ii = 1:numel(columnsSpec.optional)
                        columnName = columnsSpec.optional{ii};
                        tableOut.([columnsSpec.preffix columnName]) = repmat(model.ECDBase.defaultValue(obj.(columnName).DataType), height(tableOut), 1);
                    end
    
                case numel(columnsSpec.complete)
                    tableOut = cell2table(mergedFileBlock, 'VariableNames', strcat(columnsSpec.preffixs, columnsSpec.complete));
    
                otherwise
                    error('UnexpectedTableWidth')
            end

            for ii = 1:numel(columnsSpec.complete)
                columnName = columnsSpec.complete{ii};

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

        %-----------------------------------------------------------------%
        function columnsSpec = getColumnSpecifications(obj, tableIdList, preffixType)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
                preffixType = 'none'
            end

            checkIfScalar(obj)

            for ii = 1:numel(tableIdList)
                tableId     = tableIdList{ii};
                tableIdObj  = ['x' tableId];

                layoutIdx   = find(cellfun(@(x) ismember(obj.Layout, x), obj.(tableIdObj)(:,1)), 1);
                required    = obj.(tableIdObj){layoutIdx, 2};
                optional    = obj.(tableIdObj){layoutIdx, 3};
                complete    = [required, optional];

                switch preffixType
                    case 'none'
                        preffix = '';
                    otherwise
                        preffix = repmat('_', 1, ii);
                end

                columnsSpec(ii) = struct('id',       tableId,    ...
                                         'required', {required}, ...
                                         'optional', {optional}, ...
                                         'complete', {complete}, ... 
                                         'preffix',  preffix);
            end
        end

        %-----------------------------------------------------------------%
        function tableOut = parseTable(obj, tableId)
            arguments
                obj
                tableId (1,4) char
            end

            checkIfScalar(obj)

            switch tableId
                case {'J800', 'J801'}
                    regexMatches = extractBetween(obj.Content, ['|' tableId '|'], ['|' tableId 'FIM|'], 'Boundaries', 'inclusive');
                otherwise
                    regexPattern = ['^\|' tableId '\|[^\r\n]*'];
                    regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';
            end

            columnsSpec = getColumnSpecifications(obj, {tableId});

            if isempty(regexMatches)
                columnTypes = cellfun(@(x) obj.(x).DataType, columnsSpec.complete, 'UniformOutput', false);
                tableOut    = table('Size', [0, numel(columnsSpec.complete)], 'VariableNames', columnsSpec.complete, 'VariableTypes', columnTypes);
            else
                tableOut    = parseFileBlock(obj, regexMatches, columnsSpec, false);
            end
        end

        %-----------------------------------------------------------------%
        function [obj, msg] = mergeFiles(obj, mergedIndexes, tempPath)
            try
                mergedContent  = strjoin({obj(mergedIndexes).Content}, '\n');    
                mergedTempFile = [appUtil.DefaultFileName(tempPath, 'monitorSPED', -1) '.txt'];

                fileEncoding   = 'ISO-8859-1';
                writematrix(mergedContent, mergedTempFile, "FileType", "text", "QuoteStrings", "none", "Encoding", fileEncoding);
    
                [obj, msg] = obj.addFiles(mergedTempFile, fileEncoding, [], true);
            catch ME
                msg = ME.message;
            end
        end

        %-----------------------------------------------------------------%
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
        function tableI150_I155_CTA = inseriCodCTA(obj, tableI150_I155)
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

        %-----------------------------------------------------------------%
        function [tableOutAllTypes, soma_Mov_I155, soma_Mov_I355] = parseSplitLine(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
            end

            checkIfScalar(obj)

            for mm = 1:numel(tableIdList)
                switch mm
                    case 1
                        if ~isempty(obj.Table.xI150)
                            tableOut_I150_155_350_355{mm} = tableTypes1And3(obj, mm, tableIdList);
                        end
                    case 2
                        if ~isempty(obj.Table.xI155)
                            tableOut_I150_155_350_355{mm} = obj.Table.xI155;
                        end
                    case 3
                        if ~isempty(obj.Table.xI350)
                            tableOut_I150_155_350_355{mm} = tableTypes1And3(obj, mm, tableIdList);
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

                    tableI350_I355Null.REG(:) = repmat({strcat(tableIdList{3}, '-', tableIdList{4})}, height(tableI350_I355Null), 1);

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

                        linesTabletype1 = tableTypesLines (obj, tableIdList);
    
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
        function tableDinamica = tableDinamica_I150_I155_I350_I355(obj, Table_I150_I155_I350_I355, Table_I200_I250)
            arguments
                obj
                Table_I150_I155_I350_I355;
                Table_I200_I250;
            end

            checkIfScalar(obj)

            Cod_CTA_I155_Din = unique(Table_I150_I155_I350_I355.COD_CTA, 'stable');
            tableDinamica    = table('Size', [height(Cod_CTA_I155_Din), 14], ...
                                     'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                                     'VariableNames',  {'COD_CTA'	'MES01',	'MES02',	'MES03',	'MES04',	'MES05',	'MES06',	'MES07',	'MES08',	'MES09',	'MES10',	'MES11',	'MES12',	'MesTotal_Geral'});

            if ~isempty(Table_I200_I250)
                Table_I200_I250_IND_LCTO_N = Table_I200_I250(Table_I200_I250.IND_LCTO == "N",:);
                idx_IND_DC_D = find(Table_I200_I250_IND_LCTO_N.IND_DC == "D");
                Table_I200_I250_IND_LCTO_N.VL_DC(idx_IND_DC_D) = -abs(Table_I200_I250_IND_LCTO_N.VL_DC(idx_IND_DC_D));
            else
                Table_I200_I250_IND_LCTO_N = Table_I150_I155_I350_I355;
            end            
          
            for ii = 1: 1:height(Cod_CTA_I155_Din)
                index_COD_CTA_Din = strcmp(Table_I200_I250_IND_LCTO_N.COD_CTA, Cod_CTA_I155_Din{ii});
                Table_I200_I250_COD_CTA_Din = Table_I200_I250_IND_LCTO_N(index_COD_CTA_Din, :);
                kk = 1;
                Val_Mes = zeros(1, 12);

                try
                    months_Table_I200_I250 = unique(month(Table_I200_I250_COD_CTA_Din.DT_LCTO));
                catch
                    months_Table_I200_I250 = unique(month(Table_I200_I250_COD_CTA_Din.DT_INI));
                end
                    

                    if ~isempty(months_Table_I200_I250)
                        for jj = 1:numel(months_Table_I200_I250)
                            try
                                Value_Month = Table_I200_I250_COD_CTA_Din(month(Table_I200_I250_COD_CTA_Din.DT_LCTO) == months_Table_I200_I250(jj),:);
                                Val_Mes(months_Table_I200_I250(jj)) = sum(Value_Month.VL_DC);
                            catch
                                Value_Month = Table_I200_I250_COD_CTA_Din(month(Table_I200_I250_COD_CTA_Din.DT_INI) == months_Table_I200_I250(jj),:);
                                Val_Mes(months_Table_I200_I250(jj)) = sum(Value_Month.VL_CRED);
                            end
                            

                            Valor_Total_Mes = sum(Val_Mes);
                        end
                    else
                        Valor_Total_Mes = sum(Val_Mes);
                    end

                if iscell(Cod_CTA_I155_Din)
                    tableDinamica(ii,:) = [ { Cod_CTA_I155_Din(ii) }, num2cell([Val_Mes, Valor_Total_Mes]) ];
                else
                    tableDinamica(ii,:) = [ cellstr(Cod_CTA_I155_Din(ii)), num2cell([Val_Mes, Valor_Total_Mes]) ];
                end
            end
        end

        %-----------------------------------------------------------------%
        function tableBalancete = Balancete(obj, tableDinamica, Table_I050_I051_I052, Table_J005_J150)
            arguments
                obj
                tableDinamica;
                Table_I050_I051_I052;
                Table_J005_J150;
            end

            checkIfScalar(obj)

            tableDinamica.COD_CTA = string(tableDinamica.COD_CTA);

            if ~isempty(Table_J005_J150)
                Table_J150_parcial = Table_J005_J150(:, {'COD_AGL', 'DESCR_COD_AGL'});
                Table_J150_parcial.Properties.VariableNames{'DESCR_COD_AGL'} = 'CLASS_DRE';
                Table_J150_parcial.COD_AGL = string(Table_J150_parcial.COD_AGL);
                Table_J150_parcial.CLASS_DRE = string(Table_J150_parcial.CLASS_DRE);
            end

            Table_I050_I051_I052_parcial = Table_I050_I051_I052(:, {'COD_CTA', 'COD_NAT', 'COD_CTA_SUP', 'CTA', 'NIVEL', 'COD_AGL'});
            Table_I050_I051_I052_parcial.COD_CTA = string(Table_I050_I051_I052_parcial.COD_CTA);

            tableDinamicaParcial = outerjoin(tableDinamica, Table_I050_I051_I052_parcial, ...
                'Keys', 'COD_CTA', ...
                'MergeKeys', true, ...
                'Type', 'inner');

            tableDinamicaUnica = unique(tableDinamicaParcial, 'rows');

            if ~isempty(Table_J005_J150) && isempty(tableDinamicaUnica.COD_AGL)
                tableDinamicaUnica.COD_AGL = string(tableDinamicaUnica.COD_AGL);
                tableDinamicaTotal = outerjoin(tableDinamicaUnica, Table_J150_parcial, ...
                    'Keys', 'COD_AGL', ...
                    'MergeKeys', true, ...
                    'Type', 'inner');
                % Remove linhas duplicadas (todas as colunas iguais)
                tableDinamicaTotal = unique(tableDinamicaTotal);

                tableDinamicaTotal = rmmissing(tableDinamicaTotal, 'DataVariables', {'COD_CTA'});

                tableDinamicaTotal.Properties.VariableNames{'COD_AGL'} = 'CTA_AGRUP';

                tableDinamicaTotal.Properties.VariableNames{'CTA'} = 'DESC_CONTA';

                tableBalancete = tableDinamicaTotal(:, {'COD_NAT', 'CTA_AGRUP',  'CLASS_DRE', 'NIVEL', 'COD_CTA', 'DESC_CONTA', 'MES01', ...
                    'MES02', 'MES03', 'MES04', 'MES05', 'MES06', 'MES07', 'MES08', 'MES09', 'MES10', 'MES11', 'MES12', 'MesTotal_Geral'});

                tableBalancete.COD_NAT = string(tableBalancete.COD_NAT);
                tableBalancete = tableBalancete(tableBalancete.COD_NAT == "04", :);
            else
                % Remove linhas duplicadas (todas as colunas iguais)
                tableDinamicaTotal = tableDinamicaUnica;

                tableDinamicaTotal = rmmissing(tableDinamicaTotal, 'DataVariables', {'COD_CTA'});

                tableDinamicaTotal.Properties.VariableNames{'COD_AGL'} = 'CTA_AGRUP';

                tableDinamicaTotal.Properties.VariableNames{'CTA'} = 'DESC_CONTA';

                tableBalancete = tableDinamicaTotal(:, {'COD_NAT', 'CTA_AGRUP',  'NIVEL', 'COD_CTA', 'DESC_CONTA', 'MES01', ...
                    'MES02', 'MES03', 'MES04', 'MES05', 'MES06', 'MES07', 'MES08', 'MES09', 'MES10', 'MES11', 'MES12', 'MesTotal_Geral'});

                tableBalancete.COD_NAT = string(tableBalancete.COD_NAT);
                tableBalancete = tableBalancete(tableBalancete.COD_NAT == "04", :);
            end

            % Colunas para agrupar (sem CTA_AGRUP)
            colsAgrupar = {'COD_NAT', 'NIVEL', 'COD_CTA', 'DESC_CONTA', ...
                'MES01','MES02','MES03','MES04','MES05','MES06', ...
                'MES07','MES08','MES09','MES10','MES11','MES12', ...
                'MesTotal_Geral'};

            % Criar grupos a partir da tabela original
            [G, keysTable] = findgroups(tableBalancete(:, colsAgrupar));

            % Pegar a primeira CTA_AGRUP de cada grupo
            CTA_AGRUP_first = splitapply(@(x) x(1), tableBalancete.CTA_AGRUP, G);

            % Montar tabela final
            tableBalancete = [keysTable, table(CTA_AGRUP_first)];
        end
    end
end