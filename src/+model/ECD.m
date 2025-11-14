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

        Hash        
        Encoding
        EncodingInfo

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
            'icmsDefaultRate', struct( ...
                'type', 'auto', ...
                'rate', [] ...
            ), ...
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
        TERMINATOR (1,2) uint8 = [13, 10]
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        % MÉTODOS RELACIONADOS AO OBJETO VISTO COMO UM ARRAY
        % (ESCALAR, OU NÃO)
        %-----------------------------------------------------------------%
        function [obj, msg] = addFiles(obj, projectData, generalSettings, fileNameList, mergedIndexes, receitaFederalObj)
            arguments
                obj
                projectData
                generalSettings
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
                    
                    [obj(idx).Content, ...
                     obj(idx).Encoding, ...
                     obj(idx).EncodingInfo, ...
                     obj(idx).Hash] = util.fileread(fileFullName, generalSettings.File.encodingList);

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
                    % contábeis ("I200").
                    parseTableAndAddToCache(obj(idx), [{'0000', 'I030', 'I050', 'I200'}, generalSettings.ECD.customTables.autoload'], generalSettings)

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

                        periodYear = year(obj(idx).Table.x0000.("DT_INI")(1));
                        periodRate = zeros(1, 12);
                        rateErrorMsg = {};
                        for periodMonth = 1:12
                            [periodRate(periodMonth), msgError] = calculateINSSRate(projectData, obj(idx).CompanyInfo.UF, datetime([periodYear, periodMonth, 1]), 'mean', 3);
                            if ~isempty(msgError)
                                rateErrorMsg{end+1} = msgError;
                            end
                        end

                        if isscalar(unique(periodRate))
                            periodRate = periodRate(1);
                        end

                        if ~isempty(rateErrorMsg)
                            obj(idx).GUI.warnings{end+1} = jsonencode(strjoin(rateErrorMsg, '<br>'));
                        end

                        obj(idx).GUI.icmsDefaultRate.rate = periodRate;
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

                catch ME
                    delete(obj(idx))
                    obj(idx) = [];
                    msg{end+1} = ME.message;
                end
            end

            msg = strjoin(msg, '\n');
        end

        %-----------------------------------------------------------------%
        function parseTableAndAddToCache(obj, tableIdList, generalSettings)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText} = {'all'}
                generalSettings = []
            end

            if isequal(tableIdList, {'all'})
                isRead = true;
                tableIdList = model.ECDBase.checkImplementedTables();
            end

            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};
                    tableIdField = ['x' tableId];
                    
                    if isfield(obj(ii).Table, tableIdField)
                        continue
                    end

                    parseTable(obj(ii), tableId, generalSettings);

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
        function [obj, msg] = mergeFiles(obj, projectData, generalSettings, indexes, tempPath)
            try
                content  = strjoin({obj(indexes).Content}, char(obj(indexes(1)).TERMINATOR));
                tempFile = [appUtil.DefaultFileName(tempPath, 'monitorSPED') '.txt'];
                writematrix(content, tempFile, "FileType", "text", "QuoteStrings", "none", "Encoding", obj(indexes(1)).Encoding);
    
                [obj, msg] = addFiles(obj, projectData, generalSettings, tempFile, indexes);
            catch ME
                msg = ME.message;
            end
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
            isTableRead(obj, tableIdList);

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
            edges = [fileIndexes{1}; inf];
            tempIdColumn = {};            
            for jj = 1:numel(secundaryIds)
                tempIdColumn{jj} = discretize(fileIndexes{jj+1}, edges);
            end
            secundaryTables = cellfun(@(x,y) addvars(x, y, 'NewVariableName', '_TEMP_KEY'), cellfun(@(x) obj.Table.(['x' x]), secundaryIds, "UniformOutput", false), tempIdColumn, 'UniformOutput', false);

            secundarySpec = getColumnSpecifications(obj, secundaryIds, 'index');
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
        function status = isTableRead(obj, tableIdList, generalSettings)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
                generalSettings = []
            end

            status = false;
            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};

                    tableIdFields = {['x' tableId], ['m', tableId]};
                    tableIdStatus = any(isfield(obj(ii).Table, tableIdFields));

                    if ~tableIdStatus
                        status = true;
                        parseTableAndAddToCache(obj(ii), {tableId}, generalSettings)
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
                            case obj(ii).Encoding
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
            if isfield(obj.Table, 'xI050') && any(strcmp(obj.Table.xI050.('COD_NAT'), '04')) && isfield(obj.Table, 'xI200') && ~isempty(obj.Table.xI200)
                hasTransactions = true;
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
        function [ordinaryIds, customIds, readIds] = getTableIds(obj)
            checkIfScalar(obj)

            if isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                ordinaryIds = unique(obj.Table.x9900.("REG_BLC")(obj.Table.x9900.("QTD_REG_BLC") > 0));
            else
                ordinaryIds = {'-1'};
            end
            
            tableNames = sort(fieldnames(obj.Table));
            customIds  = extractAfter(tableNames(contains(tableNames, '_')), 'x');

            % A exclusão das tabelas vazias ocorre apenas após a obtenção
            % da lista de tabelas customizadas - iniciadas por "m" - pois
            % essas somente serão lidas sob demanda, mas devem consta na 
            % lista de opções.
            tableNames(cellfun(@(x) isempty(obj.Table.(x)), tableNames)) = [];
            readIds    = cellfun(@(x) x(2:end), tableNames, 'UniformOutput', false);
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
        function parseTable(obj, tableId, generalSettings)
            arguments
                obj
                tableId (1,:) char
                generalSettings = []
            end

            checkIfScalar(obj)
            ordinaryId = false;

            switch tableId
                case '_BALANCETE_GERAL'
                    obj.Table.x_BALANCETE_GERAL = model.TableGenerator.SummaryByAccount(obj);

                case '_BALANCETE_RESULTADO'
                    if ~isfield(obj.Table, 'x_BALANCETE_GERAL')
                        parseTable(obj, '_BALANCETE_GERAL')
                    end
                    obj.Table.x_BALANCETE_RESULTADO = model.TableGenerator.SummaryByAccountType(obj, '04');

                case '_CONTAS_ANOTACAO'
                    if ~isfield(obj.Table, 'x_BALANCETE_RESULTADO')
                        parseTable(obj, '_BALANCETE_RESULTADO')
                    end

                    if ~isfield(obj.Table, '_TABELA_APURACAO')
                        parseTable(obj, '_TABELA_APURACAO')
                    end

                    update(obj, 'Table.x_CONTAS_ANOTACAO', 'startup', generalSettings)

                case '_CONTAS_DESCRICAO'
                    obj.Table.x_CONTAS_DESCRICAO = table( ...
                        'Size', [0, 2], ...
                        'VariableNames', {'COD_CTA', 'DESCRIÇÃO'}, ...
                        'VariableTypes', {'cell', 'cell'} ...
                    );
        
                    % Esse reordenamento é essencial quando se trata de registros
                    % mesclados, tendo em vista que os planos de contas estão
                    % replicados. Ao reordenar, registra-se o última estado de
                    % cada conta.
                    xI050 = flip(obj.Table.xI050);
                    [accountUniqueIdList, accountUniqueIdFirstIndex] = unique(xI050.("COD_CTA"), "sorted");
                    
                    for ii = 1:numel(accountUniqueIdList)
                        accountId = accountUniqueIdList{ii};
                        accountDescription = strtrim(xI050.("CTA"){accountUniqueIdFirstIndex(ii)});
                        accountNumLevel = str2double(xI050.("NIVEL"){accountUniqueIdFirstIndex(ii)});
        
                        description = {};
                        currentId   = accountId;
        
                        for jj = 1:accountNumLevel
                            currentIndex  = find(strcmp(xI050.("COD_CTA"), currentId),  1);
                            currentId     = xI050.("COD_CTA_SUP"){currentIndex};
                            superiorIndex = find(strcmp(xI050.("COD_CTA_SUP"), currentId), 1);
        
                            superiorDescription = '';
                            if ~isempty(superiorIndex)
                                superiorDescription = strtrim(xI050.("CTA"){superiorIndex});
                            end
        
                            if jj == 1 && ~isempty(accountDescription) && ~isequal(accountDescription, superiorDescription)
                                description{end+1}  = accountDescription;
                            end
                            
                            if ~isempty(superiorDescription)
                                description{end+1}  = superiorDescription;
                            end
                        end
        
                        description  = strjoin(flip(description), '  ↳  ');
                        obj.Table.x_CONTAS_DESCRICAO(end+1, :) = {accountId, description};
                    end

                case '_TABELA_APURACAO'
                    update(obj, 'Table.x_TABELA_APURACAO', 'startup')

                case {'C050_C051_C052', 'I050_I051_I052', 'I200_I250'}
                    switch tableId
                        case 'C050_C051_C052'
                            obj.Table.xC050_C051_C052 = customMergedTablesRowOriented(obj, 'C050', {'C051', 'C052'});
                        case 'I050_I051_I052'
                            obj.Table.xI050_I051_I052 = customMergedTablesRowOriented(obj, 'I050', {'I051', 'I052'});
                        case 'I200_I250'
                            obj.Table.xI200_I250      = customMergedTablesRowOriented(obj, 'I200', {'I250'});
                    end

                case {'J800', 'J801'}
                    ordinaryId   = true;
                    regexMatches = extractBetween(obj.Content, ['|' tableId '|'], ['|' tableId 'FIM|'], 'Boundaries', 'inclusive');

                otherwise
                    ordinaryId   = true;
                    regexPattern = ['^\|' tableId '\|[^\r\n]*'];
                    regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors')';
            end

            if ordinaryId
                columnsSpec = getColumnSpecifications(obj, {tableId});
    
                if isempty(regexMatches)
                    columnTypes = cellfun(@(x) obj.(x).DataType, columnsSpec.complete, 'UniformOutput', false);
                    tableOut = table('Size', [0, numel(columnsSpec.complete)], 'VariableNames', columnsSpec.complete, 'VariableTypes', columnTypes);
                else
                    tableOut = parseFileBlock(obj, regexMatches, columnsSpec, false);
                end

                obj.Table.(['x' tableId]) = tableOut;
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
        % ToDo: 
        % - Migrar toda e qualquer atualização do objeto model.ECD para esse 
        %   método.
        %-----------------------------------------------------------------%
        function update(obj, propertyName, updateType, varargin)
            arguments
                obj
                propertyName char {mustBeMember(propertyName, {'Table.x_CONTAS_ANOTACAO', 'Table.x_TABELA_APURACAO'})}
                updateType
            end

            arguments (Repeating)
                varargin
            end

            checkIfScalar(obj)

            switch propertyName
                case 'Table.x_CONTAS_ANOTACAO'
                    switch updateType
                        case 'startup'
                            generalSettings = varargin{1};
                            numAccounts = height(obj.Table.x_BALANCETE_RESULTADO);

                            obj.Table.x_CONTAS_ANOTACAO = table( ...
                                obj.Table.x_BALANCETE_RESULTADO.("COD_CTA"), ...
                                repmat(categorical("-", generalSettings.ECD.accountOptions), numAccounts, 1), ...
                                repmat({'-'}, numAccounts, 1), ...
                                repmat({''}, numAccounts, 1), ...
                                'VariableNames', {'COD_CTA', 'Apurado?  ✎', 'Alíquota ICMS', 'Observação  ✎'} ...
                            );
                            return

                        case 'valueChanged'
                            rowIndex = varargin{1};
                            colIndex = varargin{2};
                            colName  = varargin{3};
                            newValue = varargin{4};

                            if isnumeric(obj.Table.x_CONTAS_ANOTACAO{rowIndex, colIndex})
                                if ~isnumeric(newValue)
                                    newValue = str2double(string(newValue));
                                end
                            elseif iscategorical(obj.Table.x_CONTAS_ANOTACAO{rowIndex, colIndex})
                                if ~iscategorical(newValue)
                                    newValue = categorical(string(newValue));
                                end
                            elseif iscellstr(obj.Table.x_CONTAS_ANOTACAO{rowIndex, colIndex})
                                if ~iscellstr(newValue)
                                    newValue = cellstr(string(newValue));
                                end
                            end

                            obj.Table.x_CONTAS_ANOTACAO{rowIndex, colIndex} = newValue;

                            if strcmp(colName, 'Apurado?  ✎')
                                update(obj, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Apurado?', rowIndex, newValue)
                            end

                        case 'valueChanged:Apurado?'
                            rowIndex = varargin{1};
                            newValue = varargin{2};

                            obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(rowIndex) = newValue;
                            switch newValue
                                case 'Sim'
                                    obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = jsonencode(obj.GUI.icmsDefaultRate);
                                otherwise
                                    obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = '-';
                            end

                        case 'valueChanged:Alíquota ICMS'
                            rowIndex = varargin{1};
                            newValue = varargin{2};

                            obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = newValue;

                        case 'valueChanged:Observação'
                            rowIndex = varargin{1};
                            newValue = varargin{2};

                            obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'){rowIndex} = newValue;

                        case 'autoFill'
                            % Edição automática limita aos registros que ainda 
                            % não foram editados e, por isso, possuem valor '-'.

                            accountTable = innerjoin(obj.Table.x_CONTAS_ANOTACAO, obj.Table.x_BALANCETE_RESULTADO, 'Keys', 'COD_CTA', 'RightVariables', 'TOTAL');
                            accountTable = innerjoin(accountTable,                obj.Table.x_CONTAS_DESCRICAO,    'Keys', 'COD_CTA', 'RightVariables', 'DESCRIÇÃO');

                            for ii = 1:height(accountTable)
                                if accountTable.('Apurado?  ✎')(ii) ~= "-"
                                    continue
                                end

                                accountDescription = lower(replace(accountTable.('DESCRIÇÃO'){ii}, textAnalysis.specialPont, ''));
                                accountTotal       = accountTable.('TOTAL')(ii);

                                % Identifica qual das descrições possuem as palavras 
                                % "ICMS", "PIS" ou "COFINS", e qual delas aparece no 
                                % final da descrição (e mais próxima da descrição da 
                                % conta analítica sob análise).
                                taxOptions    = {'icms', 'pis', 'cofins'};
                                taxValidation = repmat({[]}, 1, 3);
                                
                                for jj = 1:numel(taxOptions)
                                    taxTempValidation = strfind(accountDescription, taxOptions{jj});
                                    if ~isempty(taxTempValidation)
                                        taxValidation{jj} = taxTempValidation(end);
                                    end
                                end
                                
                                if ~isempty(cell2mat(taxValidation))
                                    taxValidationMax = max(cell2mat(taxValidation));
                                    taxValidationMaxIndex = find(cellfun(@(x) isequal(taxValidationMax, x), taxValidation), 1);

                                    switch taxValidationMaxIndex
                                        case 1 % ICMS
                                            obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(ii)   = "ICMS Telecom";
                                            obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'){ii} = '[auto] Descrição inclui termo "ICMS"';
                                        case 2 % PIS
                                            obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(ii)   = "PIS Telecom";
                                            obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'){ii} = '[auto] Descrição inclui termo "PIS"';
                                        case 3 % COFINS
                                            obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(ii)   = "COFINS Telecom";
                                            obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'){ii} = '[auto] Descrição inclui termo "COFINS"';
                                    end

                                elseif accountTotal > 0                                    
                                    obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(ii)   = "Sim";
                                    obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){ii}  = jsonencode(obj.GUI.icmsDefaultRate);
                                    obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'){ii} = '[auto] Saldo anual positivo';
                                end
                            end

                        otherwise
                            error('UnexpectedCall')
                    end

                    update(obj, 'Table.x_TABELA_APURACAO', 'accountValueChanged')

                case 'Table.x_TABELA_APURACAO'
                    monthIds = {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'};

                    switch updateType
                        case 'startup'
                            obj.Table.x_TABELA_APURACAO = table( ...
                                'Size', [11, 13], ...
                                'VariableNames', {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                                'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                                'RowNames', {'ROB TELECOM', 'ICMS TELECOM', 'ICMS CONTÁBIL', 'BÁSE DE CÁLCULO (PIS/COFINS)', 'PIS TELECOM', 'PIS CONTÁBIL', 'COFINS TELECOM', 'COFINS CONTÁBIL', 'BÁSE DE CÁLCULO (FUST/FUNTTEL)', 'VALOR APURADO FUST', 'VALOR APURADO FUNTTEL'} ...
                            );

                        case 'accountValueChanged'
                            pisDefaultTax     = 0.0065;
                            cofinsDefaultTax  = 0.03;
                            fustDefaultTax    = 0.01;
                            funttelDefaultTax = 0.005;

                            robContabilIdx    = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "Sim");
                            icmsContabilIdx   = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "ICMS Telecom");
                            pisContabilIdx    = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "PIS Telecom");
                            cofinsContabilIdx = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "COFINS Telecom");


                            % ## ROB / ICMS ##
                            robContabil       = zeros(1, 12);
                            robContabilTable  = innerjoin(obj.Table.x_CONTAS_ANOTACAO(robContabilIdx, {'COD_CTA', 'Alíquota ICMS'}), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);
                            if ~isempty(robContabilTable)
                                robContabil   = sum(robContabilTable{:, monthIds}, 1);
                            end
                            
                            icmsEstimado       = zeros(1, 12);
                            for ii = 1:height(robContabilTable)
                                icmsInfo       = jsondecode(robContabilTable.('Alíquota ICMS'){ii});
                                icmsRate       = icmsInfo.rate';

                                if isscalar(icmsRate)
                                    icmsRate   = icmsRate .* ones(1, 12);
                                end

                                icmsEstimado  = icmsEstimado - icmsRate .* robContabilTable{ii, monthIds};
                            end
                            
                            icmsContabil      = zeros(1, 12);
                            icmsContabilTable = innerjoin(obj.Table.x_CONTAS_ANOTACAO(icmsContabilIdx, 'COD_CTA'), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);                            
                            if ~isempty(icmsContabilTable)
                                icmsContabil  = sum(icmsContabilTable{:, monthIds}, 1);
                            end

                            if abs(sum(icmsEstimado)) < abs(sum(icmsContabil))
                                icmsEscolhido = icmsEstimado;
                            else
                                icmsEscolhido = icmsContabil;
                            end


                            % ## PIS/COFINS ##
                            baseCalculoPisCofins = robContabil + icmsEscolhido;                            
                            
                            pisEstimado          = - pisDefaultTax    .* baseCalculoPisCofins;
                            pisContabil          = zeros(1, 12);
                            pisContabilTable     = innerjoin(obj.Table.x_CONTAS_ANOTACAO(pisContabilIdx,    'COD_CTA'), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);
                            if ~isempty(pisContabilTable)
                                pisContabil      = sum(pisContabilTable{:, monthIds}, 1);
                            end
                            
                            cofinsEstimado       = - cofinsDefaultTax .* baseCalculoPisCofins;
                            cofinsContabil       = zeros(1, 12);
                            cofinsContabilTable  = innerjoin(obj.Table.x_CONTAS_ANOTACAO(cofinsContabilIdx, 'COD_CTA'), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);
                            if ~isempty(cofinsContabilTable)
                                cofinsContabil   = sum(cofinsContabilTable{:, monthIds}, 1);
                            end
                            
                            if abs(sum(pisEstimado)) < abs(sum(pisContabil))
                                pisEscolhido     = pisEstimado;
                            else
                                pisEscolhido     = pisContabil;
                            end

                            if abs(sum(cofinsEstimado)) < abs(sum(cofinsContabil))
                                cofinsEscolhido  = cofinsEstimado;
                            else
                                cofinsEscolhido  = cofinsContabil;
                            end


                            % ## FUST/FUNTTEL ##
                            baseCalculoFustFunttel = baseCalculoPisCofins + pisEscolhido + cofinsEscolhido;
                            fustApurado            = - fustDefaultTax    .* baseCalculoFustFunttel;
                            funttelApurado         = - funttelDefaultTax .* baseCalculoFustFunttel;


                            % ## ATUALIZA TABELA ##                            
                            obj.Table.x_TABELA_APURACAO('ROB TELECOM',                    [monthIds, {'TOTAL'}]) = num2cell([robContabil,            sum(robContabil)]);
                            obj.Table.x_TABELA_APURACAO('ICMS TELECOM',                   [monthIds, {'TOTAL'}]) = num2cell([icmsEstimado,           sum(icmsEstimado)]);
                            obj.Table.x_TABELA_APURACAO('ICMS CONTÁBIL',                  [monthIds, {'TOTAL'}]) = num2cell([icmsContabil,           sum(icmsContabil)]);
                            obj.Table.x_TABELA_APURACAO('BÁSE DE CÁLCULO (PIS/COFINS)',   [monthIds, {'TOTAL'}]) = num2cell([baseCalculoPisCofins,   sum(baseCalculoPisCofins)]);
                            obj.Table.x_TABELA_APURACAO('PIS TELECOM',                    [monthIds, {'TOTAL'}]) = num2cell([pisEstimado,            sum(pisEstimado)]);
                            obj.Table.x_TABELA_APURACAO('PIS CONTÁBIL',                   [monthIds, {'TOTAL'}]) = num2cell([pisContabil,            sum(pisContabil)]);
                            obj.Table.x_TABELA_APURACAO('COFINS TELECOM',                 [monthIds, {'TOTAL'}]) = num2cell([cofinsEstimado,         sum(cofinsEstimado)]);
                            obj.Table.x_TABELA_APURACAO('COFINS CONTÁBIL',                [monthIds, {'TOTAL'}]) = num2cell([cofinsContabil,         sum(cofinsContabil)]);
                            obj.Table.x_TABELA_APURACAO('BÁSE DE CÁLCULO (FUST/FUNTTEL)', [monthIds, {'TOTAL'}]) = num2cell([baseCalculoFustFunttel, sum(baseCalculoFustFunttel)]);
                            obj.Table.x_TABELA_APURACAO('VALOR APURADO FUST',             [monthIds, {'TOTAL'}]) = num2cell([fustApurado,            sum(fustApurado)]);                            
                            obj.Table.x_TABELA_APURACAO('VALOR APURADO FUNTTEL',          [monthIds, {'TOTAL'}]) = num2cell([funttelApurado,         sum(funttelApurado)]);

                        otherwise
                            error('UnexpectedCall')
                    end

                otherwise
                    error('UnexpectedCall')
            end
        end
    end
end