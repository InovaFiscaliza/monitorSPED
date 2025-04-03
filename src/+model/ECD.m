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


    methods
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
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function tableOut = parseTable(obj, tableId, fileLayout)
            arguments
                obj
                tableId (1,4) char
                fileLayout  = 1
            end

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
                            tableOut.(columnName) = repmat(defaultValue(obj, obj.(columnName).DataType), height(tableOut), 1);
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

        %-----------------------------------------------------------------%
        function value = defaultValue(obj, dataType)
            switch dataType
                case 'cell'
                    value = {''};
                case 'datetime'
                    value = datetime([0,0,0,0,0,0]);                                
                case 'double'
                    value = -1;
                otherwise
                    error('UnexpectedValue')
            end
        end

        %-----------------------------------------------------------------%
        function saveFile(obj, fileFolder, dataTable)
            arguments
                obj
                fileFolder {mustBeFolder}
                dataTable table
            end

            fileName   = sprintf('~ECD_%s.xlsx', datestr(now, 'yyyy.mm.dd_THH.MM.SS'));    
            writetable(dataTable, fullfile(fileFolder, fileName));
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
    end


    methods
        %-----------------------------------------------------------------%
        % TABELAS DE ANÁLISE
        %-----------------------------------------------------------------%
        function pivotTable = pivotTable(obj, tableID, Columns, Rows, DataVariable, IncludeTotals)
            arguments
                obj
                tableID char
                Columns
                Rows
                DataVariable
                IncludeTotals (1,1) logical = true
            end

            if ~isscalar(obj)
                error('ObjectMustBeScalar')
            end

            if ~isfield(obj.Table, tableID)
                switch tableID
                    case 'merged_C050_C051_C052'
                        PlanoDeContas(obj, 'C')
                    case 'merged_I050_I051_I052'
                        PlanoDeContas(obj, 'I')
                    case 'merged_I155_I150_I350_I355'
                        SaldoPeriodico(obj)
                    otherwise
                        isTableRead(obj, {tableID})
                end
            end

            pivotTable = pivot(obj.Table.(tableID), 'Columns', Columns, 'Rows', Rows, 'DataVariable', DataVariable, 'IncludeTotals', IncludeTotals);
        end

        %-----------------------------------------------------------------%
        function PlanoDeContas(obj, PlanoDeContasID) % I050 e C050
            arguments
                obj
                PlanoDeContasID (1,1) char {mustBeMember(PlanoDeContasID, {'C', 'I'})}
            end

            switch PlanoDeContasID
                case 'C'
                    tableID = 'merged_C050_C051_C052';
                    isTableRead(obj, {'C050', 'C051', 'C052'})
                case 'I'
                    tableID = 'merged_I050_I051_I052';
                    isTableRead(obj, {'I050', 'I051', 'I052'})
            end

            for ii = 1:numel(obj)
                if isfield(obj(ii).Table, tableID)
                    continue
                end

                mainTable         = eval(sprintf('obj(ii).Table.x%s050;', PlanoDeContasID));
                secundaryTable1   = eval(sprintf('obj(ii).Table.x%s051;', PlanoDeContasID));
                secundaryTable2   = eval(sprintf('obj(ii).Table.x%s052;', PlanoDeContasID));

                % Identifica os índices das contas analíticas, validando com
                % as informações constantes nas tabelas secundárias.
                idxAnalytical     = find(strcmp(mainTable.IND_CTA, 'A'));
                heightSecTables   = min([height(secundaryTable1), height(secundaryTable2)]);

                if numel(idxAnalytical) < heightSecTables
                    error('UnexpectedTableHeight')
                end
                idxAnalytical     = idxAnalytical(1:heightSecTables);
                idxSyntetical     = setdiff((1:height(mainTable))', idxAnalytical);
                
                % Insere à tabela principal as colunas "COD_CTA_REF" e "COD_AGL".
                mainTable.("COD_CTA_REF")(idxAnalytical) = secundaryTable1.("COD_CTA_REF")(1:heightSecTables);
                mainTable.("COD_CTA_REF")(idxSyntetical) = {''};

                mainTable.("COD_AGL")(idxAnalytical)     = secundaryTable2.("COD_AGL")(1:heightSecTables);
                mainTable.("COD_AGL")(idxSyntetical)     = {''};

                obj(ii).Table.(tableID) = mainTable;
            end
        end

        %-----------------------------------------------------------------%
        function SaldoPeriodico(obj)
            arguments
                obj
            end

            tableID = 'merged_I155_I150_I350_I355';
            isTableRead(obj, {'I150', 'I155', 'I350', 'I355'})

            for ii = 1:numel(obj)
                if isfield(obj(ii).Table, tableID)
                    continue
                end

                % Mescla as fichas "I150" e "I155"
                timeTable1                = obj(ii).Table.xI150;
                mainTable                 = obj(ii).Table.xI155;
                mainTable.("_VL_SLD_FIN") = obj(ii).Table.xI155.("VL_CRED") - obj(ii).Table.xI155.("VL_DEB");

                mergeKey1                 = '_COD_MES';

                [timeTable1, mainTable]  = createKeyBetweenTables(obj, timeTable1, 'DT_INI', mainTable, 'COD_CTA', mergeKey1);
                mainTable                = outerjoin(mainTable, timeTable1, 'Keys', mergeKey1, 'MergeKeys', true, 'Type', 'left', 'RightVariables', {'DT_INI', 'DT_FIN'});

                % Mescla fichas "I350" e "I355"
                timeTable2                = obj(ii).Table.xI350;
                dataTable2                = obj(ii).Table.xI355;
                mergeKey2                 = '_COD_MES_RES';

                [timeTable2, dataTable2]  = createKeyBetweenTables(obj, timeTable2, 'DT_RES', dataTable2, 'COD_CTA', mergeKey2);
                dataTable2                = outerjoin(dataTable2, timeTable2, 'Keys', mergeKey2, 'MergeKeys', true, 'Type', 'left', 'RightVariables', 'DT_RES');

                % Cria coluna "_COD_MES_RES"
                for jj = 1:height(timeTable2)
                    if jj == 1
                        idxPeriod = mainTable.('_COD_MES') <= timeTable2.("_COD_MES_RES")(jj);
                    else
                        idxPeriod = mainTable.('_COD_MES') > timeTable2.("_COD_MES_RES")(jj-1) & mainTable.('_COD_MES') <= timeTable2.("_COD_MES_RES")(jj);
                    end
                    
                    mainTable.("_COD_MES_RES")(idxPeriod) = timeTable2.("_COD_MES_RES")(jj);
                end

                % Mescla fichas "I150/I155" com "I350/I355"
                newColumns = setdiff(dataTable2.Properties.VariableNames, mainTable.Properties.VariableNames, 'stable');
                for kk = 1:height(mainTable)
                    idxFind = find(strcmp(mainTable.COD_CTA(kk), dataTable2.COD_CTA) & (mainTable.("_COD_MES")(kk) == dataTable2.("_COD_MES_RES")), 1);
                    
                    if ~isempty(idxFind)
                        mainTable(kk, newColumns) = dataTable2(idxFind, newColumns);
                    end
                end

                obj(ii).Table.(tableID) = mainTable;
            end
        end
    end
end