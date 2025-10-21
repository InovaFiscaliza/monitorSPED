classdef ECD < model.ECDBase
    
    % ## methods(ECD) ##
    % - OBJETO VISTO COMO UM ARRAY (ESCALAR OU NÃO)
    %   ├── addFiles
    %   │    ├─ parseTableAndAddToCache
    %   │    └─ checkFileStatus
    %   ├── parseTableAndAddToCache
    %   │    └─ parseTable
    %   ├── mergeFiles
    %   │    └─ addFiles
    %   ├── customMergedTablesKeyOriented
    %   │    └─ isTableRead
    %   ├── customMergedTablesRowOriented
    %   │    ├─ isTableRead
    %   │    ├─ getColumnSpecifications
    %   │    └─ parseFileBlock
    %   ├── isTableRead
    %   ├── checkFileStatus
    %   └── findSpecificObject
    
    % - OBJETO VISTO COMO UM ESCALAR
    %   ├── checkIfScalar
    %   ├── checkIfHasTransactions (I200_I255)
    %   ├── checkIfValidPeriod     (Anual)
    %   ├── checkIfValidStatus     (Receita Federal)
    %   ├── getTableIds
    %   ├── getColumnSpecifications
    %   ├── parseTable
    %   │    ├─ getColumnSpecifications
    %   │    └─ parseFileBlock
    %   │── parseFileBlock
    %   └── addCustomTables

    % Sintaxe:
    % >> ecdObj = model.ECD.empty;
    % >> ecdObj = addFiles(ecdObj, {'Filename1.txt', 'Filename2.txt'});

    properties
        %-----------------------------------------------------------------%
        FileName
        FileFullName

        Content
        Layout
        Table

        CompanyName
        CompanyId % CNPJ
        CompanyInfo = struct( ...
            'CNPJ', {}, ...
            'IE', {}, ...
            'IM', {}, ...
            'NIRE', {}, ...
            'UF', {}, ...
            'City', {} ...
        )
        
        State
        Period
        PeriodMerged = false

        Sources = struct( ...
            'file', {}, ...
            'period', {}, ...
            'encoding', {}, ...
            'terminator', {}, ...
            'hash', {}, ...
            'validationMessage', {}, ...
            'validationStatus', {} ... % -2 (Erro) | -1 (Diverge) | 0 (Pendente) | 1 (Coincide)
        )
                
        GUI = struct( ...
            'isRead', false,  ...
            'hasTransactions', false, ...
            'hasValidStatus', false, ...
            'hasValidPeriod', false, ...
            'warnings', {{}}, ...
            'rtfFiles', {{}}, ...
            'externalFiles', table( ...
                'Size', [0, 4], ...
                'VariableTypes', {'cell', 'cell', 'cell', 'int8'}, ...
                'VariableNames', {'Type', 'Tag', 'Filename', 'ID'} ...
            ), ...
            'tableView', struct( ...
                'id', {}, ...
                'widths', {}, ...
                'filters', {}, ...
                'style', {} ...
            ) ...
        )
        
        Enable = true
        UUID = char(matlab.lang.internal.uuid())
    end


    properties (Constant)
        %-----------------------------------------------------------------%
        ENCODING   (1,:) char  = 'ISO-8859-1'
        TERMINATOR (1,2) uint8 = [13, 10]
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        % MÉTODOS RELACIONADOS AO OBJETO VISTO COMO UM ARRAY
        % (ESCALAR, OU NÃO)
        %-----------------------------------------------------------------%
        function [obj, msg] = addFiles(obj, fileNameList, mergedIndexes, receitaFederalObj)
            arguments
                obj
                fileNameList
                mergedIndexes     = []
                receitaFederalObj = []
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
                    obj(idx).FileName = fileName;
                    obj(idx).FileFullName = fileFullName;
                    obj(idx).Content = fileread(fileFullName, 'Encoding', obj(idx).ENCODING);

                    % Leitura do registro "I010", identificando o layout do
                    % arquivo. Como essa ficha não mudou ao longo do tempo, 
                    % considera-se que o layout é igual a 9 (mais recente), 
                    % mas depois de lida a ficha, o valor é atualizado.
                    obj(idx).Layout = 9;
                    parseTableAndAddToCache(obj(idx), {'I010'})

                    if ~isfield(obj(idx).Table, 'xI010') || isempty(obj(idx).Table.('xI010'))
                        error('UnexpectedEmptyTable: "I010"')
                    end
                    obj(idx).Layout = obj(idx).Table.xI010.COD_VER_LC(1);

                    % Leitura do registro "9900", , o qual registra o número
                    % de linhas de cada registro, o que possibilita validação 
                    % do processo de leitura. No caso de um registro mesclado,
                    % o registro "9900" deve ser agrupado.
                    parseTableAndAddToCache(obj(idx), {'9900'})

                    % A mesclagem da informação contábil ocorre nos casos em 
                    % que a declaração não é anual, mas mensal, trimestral etc.
                    % Nesse caso, cria-se um arquivo temporário, formado pela
                    % concatenação de todos os arquivos brutos, e depois é
                    % feita a leitura desse arquivo temporário. O mapeamento
                    % com os arquivos brutos se mantém na propriedade "Sources".
                    if ~isempty(mergedIndexes)
                        obj(idx).PeriodMerged = true;

                        for index = mergedIndexes
                            nSources = numel(obj(index).Sources);
                            obj(idx).Sources(end+1:end+nSources) = obj(index).Sources;
                        end

                        if isfield(obj(idx).Table, 'x9900') && ~isempty(obj(idx).Table.x9900)
                            tempSummaryTable = groupsummary(obj(idx).Table.x9900, "REG_BLC", "sum", "QTD_REG_BLC");
                            tempSummaryTable = renamevars(tempSummaryTable, "sum_QTD_REG_BLC", "QTD_REG_BLC");
                            obj(idx).Table.x9900 = [obj(idx).Table.x9900(1:height(tempSummaryTable), 'REG'), tempSummaryTable(:, {'REG_BLC', 'QTD_REG_BLC'})];

                            x9900Index = find(strcmp(obj(idx).Table.x9900.("REG_BLC"), '9900'), 1);
                            if ~isempty(x9900Index)
                                obj(idx).Table.x9900.("QTD_REG_BLC")(x9900Index) = height(obj(idx).Table.x9900);
                            end
                        end
                    end

                    % Leitura de outros registros essenciais de identificação
                    % ("0000" e "I030"), plano de contas ("I050") e fatos 
                    % contábeis ("I200_I250").
                    parseTableAndAddToCache(obj(idx), {'0000', 'I030', 'I050', 'I200_I250'})
                    if isfield(obj(idx).Table, 'x0000') && ~isempty(obj(idx).Table.x0000)
                        obj(idx).CompanyName    = obj(idx).Table.x0000.NOME{1};
                        obj(idx).CompanyId      = checkCNPJOrCPF(obj(idx).Table.x0000.CNPJ{1}, 'NumberValidation');
                        obj(idx).CompanyInfo(1) = struct('CNPJ', obj(idx).Table.x0000.CNPJ{1}, ...
                                                         'IE',   obj(idx).Table.x0000.IE{1},   ...
                                                         'IM',   obj(idx).Table.x0000.IM{1},   ...
                                                         'NIRE', '',                           ...
                                                         'UF',   obj(idx).Table.x0000.UF{1},   ...
                                                         'City', obj(idx).Table.x0000.COD_MUN{1});

                        obj(idx).State          = obj(idx).CompanyInfo.UF;
                        obj(idx).Period         = [min(obj(idx).Table.x0000.DT_INI), max(obj(idx).Table.x0000.DT_FIN)];
                        obj(idx).Period.Format  = 'dd/MM/yyyy';
                    end

                    if isfield(obj(idx).Table, 'xI030') && ~isempty(obj(idx).Table.xI030)
                         obj(idx).CompanyInfo(1).NIRE = obj(idx).Table.xI030.NIRE{1};
                    end

                    if ~isempty(receitaFederalObj)
                        checkFileStatus(obj(idx), receitaFederalObj);
                    end

                    obj(idx).GUI.hasTransactions = checkIfHasTransactions(obj(idx));
                    obj(idx).GUI.hasValidPeriod  = checkIfValidPeriod(obj(idx));
                    obj(idx).GUI.hasValidStatus  = checkIfValidStatus(obj(idx));

                    addCustomTables(obj(idx), mergedIndexes);

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
                    tableIdPreffix = 'x';
                    if contains(tableId, '_')
                        tableIdPreffix = 'm';
                    end

                    if isfield(obj(ii).Table, [tableIdPreffix, tableId])
                        continue
                    end

                    obj(ii).Table.([tableIdPreffix, tableId]) = parseTable(obj(ii), tableId);

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
        function [obj, msg] = mergeFiles(obj, indexes, tempPath)
            try
                content  = strjoin({obj(indexes).Content}, char(obj(indexes(1)).TERMINATOR));
                tempFile = [appUtil.DefaultFileName(tempPath, 'monitorSPED') '.txt'];
                writematrix(content, tempFile, "FileType", "text", "QuoteStrings", "none", "Encoding", obj(indexes(1)).ENCODING);
    
                [obj, msg] = obj.addFiles(tempFile, indexes);
            catch ME
                msg = ME.message;
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

            isTableRead(obj, tableIdList)

            % Verifica se a tabela mesclada já foi criada.
            mergedTableId = ['m' strjoin(tableIdList, '_')];
            if isfield(obj.Table, mergedTableId)
                mergedTable = obj.Table.(mergedTableId);
                return
            end

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

        %-----------------------------------------------------------------%
        function mergedTable = customMergedTablesRowOriented(obj, mainId, secundaryIds)
            arguments
                obj
                mainId          (1,:) char {mustBeMember(mainId, {'I050', 'I200', 'C050'})}
                secundaryIds    (1,:) cell % {'I051', 'I052'} | {'I250'} | {'C051', 'C052'}
            end

            checkIfScalar(obj)

            % Verifica se os registros ordinários foram lidos.
            tableIdList = [mainId, secundaryIds];
            isTableRead(obj, tableIdList)

            % Verifica se a tabela mesclada já foi criada.
            mergedTableId = ['m' strjoin(tableIdList, '_')];
            if isfield(obj.Table, mergedTableId)
                mergedTable = obj.Table.(mergedTableId);
                return
            end

            % Converte conteúdo de arquivo em lista de células, orientada à
            % quebra de linha. Identifica o número da linha de cada um dos
            % registros sob análise - "mainId" e "secundaryIds".
            splitContent = splitlines(obj.Content);
            fileIndexes  = cellfun(@(x) find(startsWith(splitContent, x)), strcat('|', tableIdList, '|'), 'UniformOutput', false);

            % Cria coluna que servirá como "chave", relacionando as tabelas
            % que são apresentadas em sequência no arquivo. Nome da coluna
            % é "_TEM_KEY".
            mainTable = obj.Table.(['x' mainId]);
            if isempty(mainTable)
                mergedTable = [];
                return
            end

            mainTableHeight = height(mainTable);
            mainTable.("_TEMP_KEY") = (1:mainTableHeight)';
            
            % Em relação às tabelas auxiliares:
            secundaryTables = repmat({[]}, 1, numel(secundaryIds));
            secundarySpec   = getColumnSpecifications(obj, secundaryIds, 'index');

            for ii = 1:mainTableHeight
                currentIdx  = fileIndexes{1}(ii);
                if ii < mainTableHeight
                    nextIdx = fileIndexes{1}(ii+1);
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

                for jj = 1:numel(secundaryIds)
                    if isempty(secundaryTables{jj})
                        secundaryTables{jj} = obj.Table.(['x' secundaryIds{jj}]);
                    end

                    secundaryTableIndexes = fileIndexes{jj+1} > currentIdx & fileIndexes{jj+1} < nextIdx;
                    secundaryTables{jj}.("_TEMP_KEY")(secundaryTableIndexes) = ii;
                end
            end

            if isscalar(secundarySpec)
                secundaryTable = secundaryTables{1};                
            else
                secundaryTable = outerjoin( ...
                    removevars(secundaryTables{1}, 'REG'), ...
                    removevars(secundaryTables{2}, 'REG'), ...
                    "Keys", '_TEMP_KEY', ...
                    "MergeKeys", true, ...
                    'RightVariables', setdiff(secundaryTables{2}.Properties.VariableNames, secundaryTables{1}.Properties.VariableNames) ...
                );
            end

            mergedTable = outerjoin( ...
                mainTable, ...
                secundaryTable, ...
                'Keys', '_TEMP_KEY', ...
                'MergeKeys', true, ...
                'Type', 'left', ...
                'RightVariables', setdiff(secundaryTable.Properties.VariableNames, mainTable.Properties.VariableNames) ...
            );
            
            mergedTable = removevars(mergedTable, '_TEMP_KEY');
            mergedTable.("REG")(:) = {strjoin(tableIdList, '_')};
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
        function checkFileFlag = checkFileStatus(obj, receitaFederalObj, checkType, encodingList)
            arguments
                obj
                receitaFederalObj ws.ReceitaFederal
                checkType char {mustBeMember(checkType, {'OnlyCache', 'Cache+RealTime', 'RealTime'})} = 'Cache+RealTime'
                encodingList cell = {'ISO-8859-1', 'UTF-8', 'windows-1251', 'windows-1252'}
            end

            % O argumento de saída "checkFileFlag" possibilita que a GUI
            % renderize novamente a informação em tela, caso ocorra alguma
            % consulta válida à API.

            % Se o registro for resultado da mesclagem de fluxos, ou se o 
            % registro já tiver sido validado na base da Receita Federal,
            % então não é feita uma nova requisição à API. Exceto se for
            % passado como "checkType" o valor "RealTime", quando então é
            % forçada uma nova consulta.
            checkFileFlag = false;

            for ii = 1:numel(obj)
                if obj(ii).PeriodMerged || (any(ismember([obj(ii).Sources.validationStatus], [-1, 1])) && ~strcmp(checkType, 'RealTime'))
                    continue
                end

                for jj = 1:numel(encodingList) 
                    encoding = encodingList{jj};
                    index = find(strcmp({obj(ii).Sources.encoding}, encoding), 1);

                    if ~isempty(index)
                        fileHash = obj(ii).Sources(index).hash;
                    else
                        switch encoding
                            case obj(ii).ENCODING % 'ISO-8859-1'
                                fileContent = obj(ii).Content;
                            otherwise
                                fileContent = fileread(obj(ii).FileFullName, 'Encoding', encoding);
                        end

                        index = numel(obj(ii).Sources)+1;
                        obj(ii).Sources(index).file       = obj(ii).FileName;
                        obj(ii).Sources(index).period     = obj(ii).Period;
                        obj(ii).Sources(index).encoding   = encoding;
                        obj(ii).Sources(index).terminator = obj(ii).TERMINATOR;
                        
                        fileHash = util.calculateFileHash(fileContent, encoding, obj(ii).TERMINATOR);
                        obj(ii).Sources(index).hash = fileHash;
                    end

                    [validationMessage, validationStatus]    = Get(receitaFederalObj, checkType, 'ECD', fileHash);
                    obj(ii).Sources(index).validationMessage = validationMessage;
                    obj(ii).Sources(index).validationStatus  = validationStatus;

                    if validationStatus == 1
                        break;
                    end
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
        function hasTransactions = checkIfHasTransactions(obj)
            checkIfScalar(obj)

            hasTransactions = false;
            if isfield(obj.Table, 'xI200') && ~isempty(obj.Table.xI200)
                hasTransactions = true;

            elseif isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                xI200Index = find(strcmp(obj.Table.x9900.("REG_BLC"), 'I200'), 1);
                if ~isempty(xI200Index) && obj.Table.x9900.("QTD_REG_BLC")(xI200Index) > 0
                    hasTransactions = true;
                end
            end
        end

        %-----------------------------------------------------------------%
        function validFile = checkIfValidPeriod(obj)
            checkIfScalar(obj)

            yearsCovered = unique(year(obj.Period));
            if isscalar(yearsCovered)
                monthsCovered = [];
                for ii = 1:numel(obj.Sources)
                    [beginPeriod, endPeriod] = bounds(obj.Sources(ii).period);
                    monthsCovered = [monthsCovered, month(beginPeriod):month(endPeriod)];
                end
                monthsCovered = unique(monthsCovered);

                validFile = isequal(monthsCovered, 1:12);
            else
                validFile = false;
            end
        end

        %-----------------------------------------------------------------%
        function [validFile, filesStatus] = checkIfValidStatus(obj)
            checkIfScalar(obj)

            fileList = {obj.Sources.file};
            filesStatus = [];

            if isempty(fileList)
                validFile = false;
            else
                filesValidation = [];
    
                for file = unique(fileList)
                    fileIndex   = strcmp(fileList, file);
                    statusList  = [obj.Sources(fileIndex).validationStatus];
                    
                    filesStatus = [filesStatus, max(statusList)];
                    filesValidation = [filesValidation, any(statusList > 0)];
                end
        
                validFile = all(filesValidation);
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

            customIds = tableNames(startsWith(tableNames, 'm'));
            readOrdinaryIds = setdiff(tableNames, customIds);
            readOrdinaryIds = extractAfter(sort(readOrdinaryIds), 'x');

            if isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                ordinaryIds = unique(obj.Table.x9900.("REG_BLC")(obj.Table.x9900.("QTD_REG_BLC") > 0));
            else
                ordinaryIds = {'-1'};
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
                tableId    = tableIdList{ii};
                tableIdObj = ['x' tableId];

                layoutIdx  = find(cellfun(@(x) ismember(obj.Layout, x), obj.(tableIdObj)(:,1)), 1);
                required   = obj.(tableIdObj){layoutIdx, 2};
                optional   = obj.(tableIdObj){layoutIdx, 3};
                complete   = [required, optional];

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
                tableId (1,:) char
            end

            checkIfScalar(obj)

            switch tableId
                case {'C050_C051_C052', 'I050_I051_I052', 'I200_I250'}
                    switch tableId
                        case 'C050_C051_C052'
                            tableOut = customMergedTablesRowOriented(obj, 'C050', {'C051', 'C052'});
                        case 'I050_I051_I052'
                            tableOut = customMergedTablesRowOriented(obj, 'I050', {'I051', 'I052'});
                        case 'I200_I250'
                            tableOut = customMergedTablesRowOriented(obj, 'I200', {'I250'});
                    end

                    return

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
                        if ~isa(tableOut.([columnsSpec.preffix columnName]), 'double')
                            tableOut.([columnsSpec.preffix columnName]) = str2double(replace(tableOut.([columnsSpec.preffix columnName]), ',', '.'));
                        end
                    case 'datetime'
                        if ~isa(tableOut.([columnsSpec.preffix columnName]), 'datetime')
                            tableOut.([columnsSpec.preffix columnName]) = datetime(tableOut.([columnsSpec.preffix columnName]), 'InputFormat', 'ddMMyyyy');
                        end
                end
            end
        end

        %-----------------------------------------------------------------%
        function addCustomTables(obj, mergedIndexes)
            checkIfScalar(obj)

            if isempty(mergedIndexes)
                % xDESCRIÇÃO
                obj.Table.mDESCRICAO = table( ...
                    'Size', [0, 2], ...
                    'VariableNames', {'COD_CTA', 'DESCRIÇÃO'}, ...
                    'VariableTypes', {'cell', 'cell'} ...
                );

                [accountUniqueIdList, accountUniqueIdFirstIndex] = unique(obj.Table.xI050.("COD_CTA"));
                for ii = 1:numel(accountUniqueIdList)
                    accountId = accountUniqueIdList{ii};
                    accountDescription = strtrim(obj.Table.xI050.("CTA"){accountUniqueIdFirstIndex(ii)});
                    accountNumLevel = str2double(obj.Table.xI050.("NIVEL"){accountUniqueIdFirstIndex(ii)});

                    description = {};
                    currentId   = accountId;

                    for jj = 1:accountNumLevel
                        currentIndex  = find(strcmp(obj.Table.xI050.("COD_CTA"), currentId),  1);
                        currentId     = obj.Table.xI050.("COD_CTA_SUP"){currentIndex};
                        superiorIndex = find(strcmp(obj.Table.xI050.("COD_CTA_SUP"), currentId), 1);

                        superiorDescription = '';
                        if ~isempty(superiorIndex)
                            superiorDescription = strtrim(obj.Table.xI050.("CTA"){superiorIndex});
                        end

                        if jj == 1 && ~isempty(accountDescription) && ~isequal(accountDescription, superiorDescription)
                            description{end+1} = accountDescription;
                        end
                        
                        if ~isempty(superiorDescription)
                            description{end+1} = superiorDescription;
                        end
                    end

                    description  = strjoin(flip(description), '  ↳  ');
                    obj.Table.mDESCRICAO(end+1, :) = {accountId, description};
                end

                % xBALANCETE
                obj.Table.mBALANCETE_GERAL = model.TableGenerator.SummaryByAccount(obj);
                obj.Table.mBALANCETE_RESULTADO = model.TableGenerator.SummaryByAccountType(obj, '04');

                % xCONTAS
                numAccounts = height(obj.Table.mBALANCETE_RESULTADO);
                obj.Table.mCONTAS = table( ...
                    obj.Table.mBALANCETE_RESULTADO.("COD_CTA"), ...
                    repmat(categorical("Não", ["Não", "Sim", "Sim - ICMS"]), numAccounts, 1), ...
                    repmat({''}, numAccounts, 1), ...
                    repmat({''}, numAccounts, 1), ...
                    'VariableNames', {'COD_CTA', 'Apurado?  ✎', 'Observação  ✎', 'Alíquota ICMS  ✎'} ...
                );

                % xAPURAÇÃO
                obj.Table.mAPURACAO  = table( ...
                    'Size', [0, 17], ...
                    'VariableNames', {'Tipo', 'COD_CTA', 'CTA', 'Alíquota ICMS', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                    'VariableTypes', {'cell', 'cell', 'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
                );
            else
                % ToDo:
                % Concatenar Plano de Contas e Balencete.
            end
        end
    end
end