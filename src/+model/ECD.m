classdef ECD < handle

    % SINTAXE:
    % >> ecdObj = model.ECD.empty;
    % >> ecdObj = addFiles(ecdObj, {'Filename1.txt', 'Filename2.txt'});

    properties
        %-----------------------------------------------------------------%
        FileName = ''
        FileFullName = ''

        Size
        Hash = ''
        Encoding = ''
        EncodingInfo = ''

        Content = ''
        Layout = 1
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
            'icmsRate', struct( ...
                'source', 'default', ... % 'default' | 'manual'
                'default', struct('mode', 'auto', 'rate', []), ...
                'current', struct('mode', 'auto', 'rate', []) ...
            ), ...
            'tableView', struct( ...
                'id', {}, ...
                'filter', {}, ...
                'style', {}, ...
                'sort', {}, ...
                'width', {} ...
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
                    obj(idx).PeriodMerged = ~isempty(mergedIndexes);
                    
                    % Leitura do arquivo, identificando o encoding e lendo os
                    % principais registros ("0000", "I030", "I050" etc).
                    util.fileread(obj(idx), fileFullName, generalSettings);

                    if numel(obj) > 1 && ismember(obj(idx).Hash, {obj(1:end-1).Hash})
                        error('model:ECD:FileAlreadyRead', 'File content has already been read.')
                    end

                    % A mesclagem da informação contábil ocorre nos casos em 
                    % que a declaração não é anual, mas mensal, trimestral etc.
                    % Nesse caso, cria-se um arquivo temporário, formado pela
                    % concatenação de todos os arquivos brutos, e depois é
                    % feita a leitura desse arquivo temporário. O mapeamento
                    % com os arquivos brutos se mantém na propriedade "Sources".
                    if obj(idx).PeriodMerged
                        obj(idx).Sources = [obj(mergedIndexes).Sources];

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

                    % Leitura de outros registros essenciais...
                    parseTableAndAddToCache(obj(idx), generalSettings.context.ECD.customTables.autoload, generalSettings)
                    parseTableAndAddToCache(obj(idx), {'_CONTAS_ANOTACAO'},  generalSettings)
                    parseTableAndAddToCache(obj(idx), {'_CONTAS_HISTORICO'}, generalSettings)

                    initializeCompanyContext(obj(idx), projectData, generalSettings, receitaFederalObj)

                catch ME
                    delete(obj(idx))
                    obj(idx) = [];
                    msg{end+1} = ME.message;
                end
            end

            msg = strjoin(msg, '\n');
        end

        %-----------------------------------------------------------------%
        function [obj, msg] = mergeFiles(obj, projectData, generalSettings, indexes, tempPath)
            msg = '';
            hasAnyLargeFile = any(cellfun(@isempty, {obj(indexes).Content}));

            try
                if ~hasAnyLargeFile
                    content  = strjoin({obj(indexes).Content}, char(obj(indexes(1)).TERMINATOR));
                    tempFile = [appEngine.util.DefaultFileName(tempPath, 'monitorSPED') '.txt'];
                    writematrix(content, tempFile, "FileType", "text", "QuoteStrings", "none", "Encoding", obj(indexes(1)).Encoding);
                    [obj, msg] = addFiles(obj, projectData, generalSettings, tempFile, indexes);

                else
                    idx = numel(obj)+1;
                    obj(idx) = model.ECD;

                    % Inicialmente, ordenam-se os fluxos:
                    periodList = arrayfun(@(x) x.Period(1), obj(indexes));
                    [~, sortedIndexes] = sort(periodList);
                    indexes = indexes(sortedIndexes);

                    obj(idx).PeriodMerged = true;
                    obj(idx).Sources = [obj(indexes).Sources];
                    obj(idx).Size = sum([obj(indexes).Size]);

                    encodingInfo = cellfun(@(x) jsondecode(x), {obj(indexes).EncodingInfo}, 'UniformOutput', false);
                    encodingInfo = struct2table(vertcat(encodingInfo{:}));
                    encodingInfo = groupsummary(encodingInfo, 'Encoding', 'sum', {'SpecialCharsTypeCount', 'SpecialCharsCount'});
                    encodingInfo = renamevars(encodingInfo, {'sum_SpecialCharsTypeCount', 'sum_SpecialCharsCount'}, {'SpecialCharsTypeCount', 'SpecialCharsCount'});
    
                    obj(idx).Encoding = strjoin(unique({obj(indexes).Encoding}, 'stable'), ' & ');
                    obj(idx).EncodingInfo = matlab.jsonencode(encodingInfo);

                    layout = unique([obj(indexes).Layout]);
                    if isscalar(layout)
                        obj(idx).Layout = layout;
                    end

                    registerIds = {'0000', '9900', 'I010', 'I030', 'I050', '_BALANCETE_GERAL', '_CONTAS_DESCRICAO', '_CONTAS_HISTORICO'};
                    for ii = 1:numel(registerIds)
                        id = registerIds{ii};

                        switch id
                            case '_BALANCETE_GERAL'
                                monthMapping = dictionary(1:12, ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"]); 
                                trialBalance = obj(indexes(end)).Table.x_BALANCETE_GERAL;

                                for jj = indexes(1:end-1)
                                    periodMonths = month(obj(jj).Period);
                                    
                                    for kk = 1:height(obj(jj).Table.x_BALANCETE_GERAL)
                                        accountId = obj(jj).Table.x_BALANCETE_GERAL.('COD_CTA'){kk};
                                        [~, accountIdx] = ismember(accountId, trialBalance.('COD_CTA'));

                                        if accountIdx
                                            trialBalance(accountIdx, monthMapping(periodMonths(1):periodMonths(2))) = trialBalance(accountIdx, monthMapping(periodMonths(1):periodMonths(2))) + obj(jj).Table.x_BALANCETE_GERAL(kk, monthMapping(periodMonths(1):periodMonths(2)));
                                        else
                                            trialBalance = [trialBalance; obj(jj).Table.x_BALANCETE_GERAL(kk, :)];
                                        end
                                    end
                                end
                                trialBalance = sortrows(trialBalance, 'COD_CTA');
                                trialBalance.("TOTAL") = sum(trialBalance{:, monthMapping.values}, 2);

                                obj(idx).Table.(['x' id]) = trialBalance;
                            
                            case '_CONTAS_DESCRICAO'
                                if isfield(obj(idx).Table, 'xI050') && ~isempty(obj(idx).Table.xI050)
                                     parseTableAndAddToCache(obj(idx), {'_CONTAS_DESCRICAO'}, generalSettings)
                                else
                                    % O flip garante o uso da descrição mais 
                                    % recente...
                                    mergedTable = flip(arrayfun(@(x) x.Table.(['x' id]), obj(indexes), "UniformOutput", false));
                                    mergedTable = vertcat(mergedTable{:});
                                    [~, uniqueIdxs] = unique(mergedTable.("COD_CTA"));
                                    mergedTable = sortrows(mergedTable(uniqueIdxs, :), 'COD_CTA');
                                    
                                    obj(idx).Table.(['x' id]) = mergedTable;
                                end

                            case '_CONTAS_HISTORICO'
                                mergedTable = arrayfun(@(x) x.Table.(['x' id]), obj(indexes), "UniformOutput", false);
                                mergedTable = vertcat(mergedTable{:});

                                [accountList, ~, accountListIdxs] = unique(mergedTable.("COD_CTA"));
                                numAccounts = numel(accountList);
                                
                                x_CONTAS_HISTORICO = model.ECDBase.initializeCustomTable('_CONTAS_HISTORICO', numAccounts);

                                for jj = 1:numel(accountList)
                                    accountId = accountList{jj};
                                    accountIdxs = jj == accountListIdxs;

                                    tmpHist = mergedTable.('LANÇAMENTOS NORMALIZADOS DEDUPLICADOS')(accountIdxs);
                                    tmpHist = vertcat(tmpHist{:});
                                    [hist, totalCount] = util.deduplicateAccountEntryHistory('aggregated', tmpHist);

                                    x_CONTAS_HISTORICO(jj, :) = {accountId, totalCount, hist};
                                end

                                obj(idx).Table.(['x' id]) = x_CONTAS_HISTORICO;

                            otherwise
                                mergedTable = arrayfun(@(x) x.Table.(['x' id]), obj(indexes), "UniformOutput", false);
                                mergedTable = vertcat(mergedTable{:});

                                if strcmp(id, '9900')
                                    mergedTable = groupsummary(mergedTable, "REG_BLC", "sum", "QTD_REG_BLC");
                                    mergedTable = renamevars(mergedTable, "sum_QTD_REG_BLC", "QTD_REG_BLC");
                                    mergedTable = removevars(mergedTable, 'GroupCount');
                                    mergedTable.REG(:) = {'9900'};
                                    mergedTable = movevars(mergedTable, 'REG', 'Before', 1);

                                    x9900Index = find(strcmp(mergedTable.("REG_BLC"), '9900'), 1);
                                    if ~isempty(x9900Index)
                                        mergedTable.("QTD_REG_BLC")(x9900Index) = height(mergedTable);
                                    end
                                end

                                obj(idx).Table.(['x' id]) = mergedTable;
                        end
                    end

                    parseTableAndAddToCache(obj(idx), setdiff(generalSettings.context.ECD.customTables.autoload, extractAfter(fieldnames(obj(idx).Table), 'x')), generalSettings)
                    initializeCompanyContext(obj(idx), projectData, generalSettings)
                end

            catch ME
                msg = ME.message;
            end
        end

        %-----------------------------------------------------------------%
        function parseTableAndAddToCache(obj, tableIdList, generalSettings)
            arguments
                obj
                tableIdList cell {mustBeText}
                generalSettings
            end

            if isequal(tableIdList, {'all'})
                isRead = true;
                tableIdList = model.ECDBase.getImplementedTableIds();
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
                    expectedRows = expectedRowsByTableId(obj, tableId);
                    if ~isempty(expectedRows) && expectedRows > 0
                        readRows = height(obj(ii).Table.(['x' tableId]));                            
                        if expectedRows ~= readRows
                            obj(ii).GUI.warnings{end+1} = matlab.jsonencode(struct( ...
                                'id', tableId, ...
                                'message', sprintf('expectedRows: %d, readRows: %d', expectedRows, readRows) ...
                            ));
                        end
                    end
                end

                if exist('isRead', 'var')
                    obj(ii).GUI.isRead = isRead;
                end
            end
        end

        %-----------------------------------------------------------------%
        function update(obj, propertyName, updateType, varargin)
            arguments
                obj
                propertyName char {mustBeMember(propertyName, { 'GUI.TableView.Filter';
                                                                'GUI.TableView.Style';
                                                                'GUI.TableView.Sort';
                                                                'GUI.TableView.Width';
                                                                'GUI.IcmsRate';
                                                                'Table.NonEssentialFiles';
                                                                'Table.x_CONTAS_ANOTACAO';
                                                                'Table.x_APURACAO_GERAL'; ...
                                                                'Table.x_CONCILIACAO' })}
                updateType
            end

            arguments (Repeating)
                varargin
            end

            checkIfScalar(obj)

            switch propertyName
                case 'GUI.TableView.Filter'
                    switch updateType
                        case 'createFilteringObject'
                            tableId = varargin{1};
                            filterIdx = varargin{2};
                            obj.GUI.tableView(filterIdx).id     = tableId;
                            obj.GUI.tableView(filterIdx).filter = tableFiltering;

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'GUI.TableView.Style'
                    switch updateType
                        case 'addStyle'
                            tableId = varargin{1};
                            styleIdx = varargin{2};
                            styleConfig = varargin{3};
                            obj.GUI.tableView(styleIdx).id = tableId;
                            obj.GUI.tableView(styleIdx).style = styleConfig;

                        case 'removeSelectedCellStyle'
                            styleIdx = varargin{1};
                            styleConfig = varargin{2};
                            obj.GUI.tableView(styleIdx).style = styleConfig;

                        case 'removeTableStyle'
                            styleIdx = varargin{1};                            
                            obj.GUI.tableView(styleIdx).style = {};

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'GUI.TableView.Sort'
                    tableId = varargin{1};
                    [~, displayIdx] = ismember(tableId, {obj.GUI.tableView.id});

                    switch updateType
                        case 'applySort'
                            if ~displayIdx
                                displayIdx = numel(obj.GUI.tableView) + 1;
                            end

                            columnName = varargin{2};
                            dataIdxs = varargin{3};

                            obj.GUI.tableView(displayIdx).id   = tableId;
                            obj.GUI.tableView(displayIdx).sort = struct( ...
                                'columnName', columnName, ...
                                'dataIdxs', dataIdxs ...
                            );

                        case 'clearSort'
                            if displayIdx
                                obj.GUI.tableView(displayIdx).sort = [];
                            end

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'GUI.TableView.Width'
                    tableId = varargin{1};
                    [~, widthIdx] = ismember(tableId, {obj.GUI.tableView.id});

                    switch updateType
                        case 'updateColumnWidths'
                            displayedColumnCount = varargin{2};
                            columnWidthUpdates = varargin{3};

                            if widthIdx && isfield(obj.GUI.tableView(widthIdx), 'width') && ~isempty(obj.GUI.tableView(widthIdx).width)
                                widthCells = obj.GUI.tableView(widthIdx).width;
                                if numel(widthCells) ~= displayedColumnCount
                                    widthCells = repmat({'auto'}, 1, displayedColumnCount);
                                end

                            else
                                widthIdx = numel(obj.GUI.tableView) + 1;
                                widthCells = repmat({'auto'}, 1, displayedColumnCount);
                            end

                            widths = str2double(extractBefore({columnWidthUpdates.width}, 'px'));
                            widthCells([columnWidthUpdates.idx]) = num2cell(widths);

                            widthCells(cellfun(@(x) isequal(x, 10), widthCells)) = {'1x'};
                            widthCells(cellfun(@(x) isequal(x, 75), widthCells)) = {'auto'};

                            obj.GUI.tableView(widthIdx).id    = tableId;
                            obj.GUI.tableView(widthIdx).width = widthCells;

                        case 'resetColumnWidths'
                            if widthIdx
                                obj.GUI.tableView(widthIdx).width = [];
                            end

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'GUI.IcmsRate'
                    switch updateType
                        case 'valueChanged'
                            obj.GUI.icmsRate.current = varargin{1};
                            if isequal(obj.GUI.icmsRate.default, obj.GUI.icmsRate.current)
                                obj.GUI.icmsRate.source = 'default';
                            else
                                obj.GUI.icmsRate.source = 'manual';
                            end

                        case 'refresh'
                            obj.GUI.icmsRate.current = obj.GUI.icmsRate.default;
                            obj.GUI.icmsRate.source  = 'default';

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'Table.NonEssentialFiles'
                    switch updateType
                        case 'onCacheCleanup'
                            if isempty(varargin{1})
                                return
                            end

                            tableIdList = strcat({'x'}, varargin{1});
                            tableIdList = tableIdList(isfield(obj.Table, tableIdList));

                            obj.Table = rmfield(obj.Table, tableIdList);

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'Table.x_CONTAS_ANOTACAO'
                    generalSettings = varargin{1};

                    switch updateType
                        case 'startup'
                            accountList = obj.Table.x_BALANCETE_RESULTADO.('COD_CTA');
                            annotationAccountTemplate = innerjoin( ...
                                model.ECDBase.initializeCustomTable('_CONTAS_ANOTACAO', accountList, generalSettings), ...
                                obj.Table.x_CONTAS_DESCRICAO, ...
                                'Keys', 'COD_CTA', 'RightVariables', 'DESCRIÇÃO' ...
                            );
                            
                            obj.Table.x_CONTAS_ANOTACAO = movevars(annotationAccountTemplate, 'DESCRIÇÃO', 'After', 'COD_CTA');
                          % obj.Table.x_CONTAS_ANOTACAO = sortrows(obj.Table.x_CONTAS_ANOTACAO, 'DESCRIÇÃO');

                        case 'valueChanged'
                            rowIndex = varargin{2};
                            colIndex = varargin{3};
                            colName  = varargin{4};
                            newValue = varargin{5};

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
                                update(obj, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Apurado?', generalSettings, rowIndex, newValue)
                            end

                        case 'valueChanged:Declarado?'
                            rowIndex = varargin{2};
                            newValue = varargin{3};

                            obj.Table.x_CONTAS_ANOTACAO.('Declarado?  ✎')(rowIndex) = newValue;

                        case 'valueChanged:Apurado?'
                            rowIndex = varargin{2};
                            newValue = varargin{3};

                            obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(rowIndex) = newValue;
                            switch newValue
                                case 'Sim'
                                    obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = jsonencode(obj.GUI.icmsRate.current);
                                otherwise
                                    obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = '-';
                                    
                                    if ismember(obj.Table.x_CONTAS_ANOTACAO.('Interconexão?  ✎')(rowIndex), ["ITX", "EILD"])
                                        obj.Table.x_CONTAS_ANOTACAO.('Interconexão?  ✎')(rowIndex) = "-";
                                    end
                            end

                        case 'valueChanged:Interconexão?'
                            rowIndex = varargin{2};
                            newValue = varargin{3};

                            obj.Table.x_CONTAS_ANOTACAO.('Interconexão?  ✎')(rowIndex) = newValue;

                        case 'valueChanged:Alíquota ICMS'
                            rowIndex = varargin{2};
                            newValue = varargin{3};

                            obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = newValue;

                        case 'valueChanged:Observação'
                            rowIndex = varargin{2};
                            newValue = varargin{3};

                            obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'){rowIndex} = newValue;
                            return

                        case 'autoFill'
                            % Edição automática limitada aos registros que ainda 
                            % não foram editados e, por isso, possuem valor '-'.

                            accountTable = innerjoin( ...
                                obj.Table.x_CONTAS_ANOTACAO, ...
                                obj.Table.x_BALANCETE_RESULTADO, ...
                                'Keys', 'COD_CTA', ...
                                'RightVariables', {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'} ...
                            );

                            for ii = 1:height(accountTable)
                                if accountTable.('Apurado?  ✎')(ii) ~= "-"
                                    continue
                                end

                                accountDescription = lower(replace(accountTable.('DESCRIÇÃO'){ii}, textAnalysis.specialPont, ''));
                                hasPositiveMonthlyBalance = all(accountTable{ii, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}} >= 0);
                                totalBalance = accountTable.('TOTAL')(ii);

                                % Identifica qual das descrições possuem as palavras 
                                % "ICMS", "PIS" ou "COFINS", e qual delas aparece no 
                                % final da descrição (e mais próxima da descrição da 
                                % conta analítica sob análise).
                                taxOptions    = {'icms', ' pis', 'cofins'};
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

                                else
                                    if totalBalance <= 0
                                        continue
                                    end

                                    keywords = struct( ...
                                        'nonTelecom', {{'nao telecom', ' sva ', 'valor adicionado', 'valor adcionado', ' locacao', 'instalacao'}}, ...
                                        'telecom',    {{'telecom', 'servico', 'receita'}} ...
                                    );

                                    normalizedDescription = textAnalysis.normalizeWords(accountTable.('DESCRIÇÃO'){ii});
                                    nonTelecomMatchMask   = cellfun(@(x) contains(normalizedDescription, x), keywords.nonTelecom);
                                    telecomTermsMatchMask = cellfun(@(x) contains(normalizedDescription, x), keywords.telecom);

                                    if any(nonTelecomMatchMask)
                                        nonTelecomWords = upper(strcat({'"'}, strtrim(keywords.nonTelecom(nonTelecomMatchMask)), {'"'}));
                                        if isscalar(nonTelecomWords)
                                            nonTelecomWords = char(nonTelecomWords);
                                            classificationNote = sprintf('[auto] Descrição inclui termo %s', nonTelecomWords);
                                        else
                                            nonTelecomWords = strjoin({strjoin(nonTelecomWords(1:end-1), ', '), nonTelecomWords{end}}, ' e ');
                                            classificationNote = sprintf('[auto] Descrição inclui termos %s', nonTelecomWords);
                                        end

                                        obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(ii)   = "Não";
                                        obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'){ii} = classificationNote;

                                    elseif sum(telecomTermsMatchMask) >= 2
                                        telecomWords = upper(strcat({'"'}, strtrim(keywords.telecom(telecomTermsMatchMask)), {'"'}));
                                        telecomWords = strjoin({strjoin(telecomWords(1:end-1), ', '), telecomWords{end}}, ' e ');

                                        if hasPositiveMonthlyBalance
                                            classificationNote = sprintf('[auto] Saldos mensais não negativos e descrição inclui termos %s', telecomWords);
                                        else
                                            classificationNote = sprintf('[auto] Saldo anual positivo e descrição inclui termos %s', telecomWords);
                                        end

                                        obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(ii)   = "Sim";
                                        obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){ii}  = jsonencode(obj.GUI.icmsRate.current);
                                        obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'){ii} = classificationNote;
                                    end
                                end
                            end

                        case 'deleteAnnotation'
                            rowIndex = varargin{2};
                            accountList = obj.Table.x_BALANCETE_RESULTADO.('COD_CTA')(rowIndex);
                            
                            annotationAccountTemplate = innerjoin(model.ECDBase.initializeCustomTable('_CONTAS_ANOTACAO', accountList, generalSettings), obj.Table.x_CONTAS_DESCRICAO, 'Keys', 'COD_CTA', 'RightVariables', 'DESCRIÇÃO');
                            obj.Table.x_CONTAS_ANOTACAO(rowIndex, :) = movevars(annotationAccountTemplate, 'DESCRIÇÃO', 'After', 'COD_CTA');

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                    update(obj, 'Table.x_APURACAO_GERAL', 'accountValueChanged', generalSettings)

                case 'Table.x_APURACAO_GERAL'
                    switch updateType
                        case 'startup'
                            obj.Table.x_APURACAO_GERAL        = model.ECDBase.initializeCustomTable('_APURACAO_GERAL');
                            obj.Table.x_APURACAO_INTERCONEXAO = model.ECDBase.initializeCustomTable('_APURACAO_INTERCONEXAO');

                        case 'accountValueChanged'
                            generalSettings   = varargin{1};
                            
                            itxIcmsDefaultTax = generalSettings.context.ECD.taxConfig.ICMS_INTERCONEXAO; % 0;
                            pisDefaultTax     = generalSettings.context.ECD.taxConfig.PIS;               % 0.0065;
                            cofinsDefaultTax  = generalSettings.context.ECD.taxConfig.COFINS;            % 0.03;
                            fustDefaultTax    = generalSettings.context.ECD.taxConfig.FUST;              % 0.01;
                            funttelDefaultTax = generalSettings.context.ECD.taxConfig.FUNTTEL;           % 0.005;
                            monthIds          = {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'};
                            
                            
                            % ## _APURACAO_GERAL ## 
                            robContabilIdx    = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "Sim");
                            icmsContabilIdx   = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "ICMS Telecom");
                            pisContabilIdx    = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "PIS Telecom");
                            cofinsContabilIdx = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "COFINS Telecom");

                            % (a) ROB / ICMS
                            robContabil       = zeros(1, 12);
                            robContabilTable  = innerjoin(obj.Table.x_CONTAS_ANOTACAO(robContabilIdx, {'COD_CTA', 'Alíquota ICMS'}), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);
                            if ~isempty(robContabilTable)
                                robContabil   = sum(robContabilTable{:, monthIds}, 1);
                            end
                            robContabil       = applyReconciliationAdjustment(obj, robContabil, '_CONCILIACAO_GERAL', 'ROB TELECOM');
                            
                            icmsEstimado      = zeros(1, 12);
                            for ii = 1:height(robContabilTable)
                                icmsInfo      = jsondecode(robContabilTable.('Alíquota ICMS'){ii});
                                icmsRate      = icmsInfo.rate';

                                if isscalar(icmsRate)
                                    icmsRate  = icmsRate .* ones(1, 12);
                                end

                                icmsEstimado  = icmsEstimado - icmsRate .* robContabilTable{ii, monthIds};
                            end
                            icmsEstimado      = fix(100 * icmsEstimado) / 100;
                            icmsEstimado       = applyReconciliationAdjustment(obj, icmsEstimado, '_CONCILIACAO_GERAL', 'ICMS ESTIMADO');
                            
                            icmsContabil      = zeros(1, 12);
                            icmsContabilTable = innerjoin(obj.Table.x_CONTAS_ANOTACAO(icmsContabilIdx, 'COD_CTA'), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);                            
                            if ~isempty(icmsContabilTable)
                                icmsContabil  = sum(icmsContabilTable{:, monthIds}, 1);
                            end
                            icmsContabil      = applyReconciliationAdjustment(obj, icmsContabil, '_CONCILIACAO_GERAL', 'ICMS CONTÁBIL');

                            if abs(sum(icmsEstimado)) < abs(sum(icmsContabil))
                                icmsEscolhido = icmsEstimado;
                            else
                                icmsEscolhido = icmsContabil;
                            end

                            % (b) PIS/COFINS
                            baseCalculoPisCofins = robContabil + icmsEscolhido;                            
                            
                            pisEstimado          = - fix(100 * pisDefaultTax .* baseCalculoPisCofins) / 100;
                            pisContabil          = zeros(1, 12);
                            pisContabilTable     = innerjoin(obj.Table.x_CONTAS_ANOTACAO(pisContabilIdx,    'COD_CTA'), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);
                            if ~isempty(pisContabilTable)
                                pisContabil      = sum(pisContabilTable{:, monthIds}, 1);
                            end
                            pisContabil          = applyReconciliationAdjustment(obj, pisContabil, '_CONCILIACAO_GERAL', 'PIS CONTÁBIL');
                            
                            cofinsEstimado       = - fix(100 * cofinsDefaultTax .* baseCalculoPisCofins) / 100;
                            cofinsContabil       = zeros(1, 12);
                            cofinsContabilTable  = innerjoin(obj.Table.x_CONTAS_ANOTACAO(cofinsContabilIdx, 'COD_CTA'), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);
                            if ~isempty(cofinsContabilTable)
                                cofinsContabil   = sum(cofinsContabilTable{:, monthIds}, 1);
                            end
                            cofinsContabil       = applyReconciliationAdjustment(obj, cofinsContabil, '_CONCILIACAO_GERAL', 'COFINS CONTÁBIL');
                            
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

                            % (c) FUST/FUNTTEL
                            baseCalculoFustFunttel = baseCalculoPisCofins + pisEscolhido + cofinsEscolhido;
                            fustApurado            = - fix(100 * fustDefaultTax    .* baseCalculoFustFunttel) / 100;
                            funttelApurado         = - fix(100 * funttelDefaultTax .* baseCalculoFustFunttel) / 100;

                            % (d) ATUALIZA TABELA
                            obj.Table.x_APURACAO_GERAL( 1, [monthIds, {'TOTAL'}]) = num2cell([robContabil,            sum(robContabil)]);
                            obj.Table.x_APURACAO_GERAL( 2, [monthIds, {'TOTAL'}]) = num2cell([icmsEstimado,           sum(icmsEstimado)]);
                            obj.Table.x_APURACAO_GERAL( 3, [monthIds, {'TOTAL'}]) = num2cell([icmsContabil,           sum(icmsContabil)]);
                            obj.Table.x_APURACAO_GERAL( 4, [monthIds, {'TOTAL'}]) = num2cell([baseCalculoPisCofins,   sum(baseCalculoPisCofins)]);
                            obj.Table.x_APURACAO_GERAL( 5, [monthIds, {'TOTAL'}]) = num2cell([pisEstimado,            sum(pisEstimado)]);
                            obj.Table.x_APURACAO_GERAL( 6, [monthIds, {'TOTAL'}]) = num2cell([pisContabil,            sum(pisContabil)]);
                            obj.Table.x_APURACAO_GERAL( 7, [monthIds, {'TOTAL'}]) = num2cell([cofinsEstimado,         sum(cofinsEstimado)]);
                            obj.Table.x_APURACAO_GERAL( 8, [monthIds, {'TOTAL'}]) = num2cell([cofinsContabil,         sum(cofinsContabil)]);
                            obj.Table.x_APURACAO_GERAL( 9, [monthIds, {'TOTAL'}]) = num2cell([baseCalculoFustFunttel, sum(baseCalculoFustFunttel)]);
                            obj.Table.x_APURACAO_GERAL(10, [monthIds, {'TOTAL'}]) = num2cell([fustApurado,            sum(fustApurado)]);
                            obj.Table.x_APURACAO_GERAL(11, [monthIds, {'TOTAL'}]) = num2cell([funttelApurado,         sum(funttelApurado)]);

                            
                            % ## _APURACAO_INTERCONEXÃO ## 
                            itxRobContabilIdx   = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "Sim" & ismember(obj.Table.x_CONTAS_ANOTACAO.('Interconexão?  ✎'), ["ITX", "EILD"]));
                            
                            % (a) ROB / ICMS INTERCONEXÃO
                            itxRobContabil      = zeros(1, 12);
                            itxIcmsEstimado     = zeros(1, 12);

                            itxRobContabilTable = innerjoin(obj.Table.x_CONTAS_ANOTACAO(itxRobContabilIdx, {'COD_CTA', 'Alíquota ICMS'}), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);
                            if ~isempty(itxRobContabilTable)
                                itxRobContabil  = sum(itxRobContabilTable{:, monthIds}, 1);
                                itxRobContabil  = applyReconciliationAdjustment(obj, itxRobContabil,  '_CONCILIACAO_INTERCONEXAO', 'ROB TELECOM');

                                itxIcmsEstimado = - fix(100 * itxIcmsDefaultTax .* itxRobContabil) / 100;
                            end

                            % (b) PIS/COFINS INTERCONEXÃO
                            itxBaseCalculoPisCofins = itxRobContabil + itxIcmsEstimado;

                            itxPisEstimado      = - fix(100 * pisDefaultTax    .* itxBaseCalculoPisCofins) / 100;
                            itxCofinsEstimado   = - fix(100 * cofinsDefaultTax .* itxBaseCalculoPisCofins) / 100;

                            % (c) FUST/FUNTTEL INTERCONEXÃO
                            itxBaseCalculoFustFunttel = itxBaseCalculoPisCofins + itxPisEstimado + itxCofinsEstimado;
                            itxFustApurado      = - fix(100 * fustDefaultTax    .* itxBaseCalculoFustFunttel) / 100;
                            itxFunttelApurado   = - fix(100 * funttelDefaultTax .* itxBaseCalculoFustFunttel) / 100;

                            % (d) ATUALIZA TABELA INTERCONEXÃO
                            obj.Table.x_APURACAO_INTERCONEXAO(1, [monthIds, {'TOTAL'}]) = num2cell([itxRobContabil,            sum(itxRobContabil)]);
                            obj.Table.x_APURACAO_INTERCONEXAO(2, [monthIds, {'TOTAL'}]) = num2cell([itxIcmsEstimado,           sum(itxIcmsEstimado)]);
                            obj.Table.x_APURACAO_INTERCONEXAO(3, [monthIds, {'TOTAL'}]) = num2cell([itxBaseCalculoPisCofins,   sum(itxBaseCalculoPisCofins)]);
                            obj.Table.x_APURACAO_INTERCONEXAO(4, [monthIds, {'TOTAL'}]) = num2cell([itxPisEstimado,            sum(itxPisEstimado)]);
                            obj.Table.x_APURACAO_INTERCONEXAO(5, [monthIds, {'TOTAL'}]) = num2cell([itxCofinsEstimado,         sum(itxCofinsEstimado)]);
                            obj.Table.x_APURACAO_INTERCONEXAO(6, [monthIds, {'TOTAL'}]) = num2cell([itxBaseCalculoFustFunttel, sum(itxBaseCalculoFustFunttel)]);
                            obj.Table.x_APURACAO_INTERCONEXAO(7, [monthIds, {'TOTAL'}]) = num2cell([itxFustApurado,            sum(itxFustApurado)]);
                            obj.Table.x_APURACAO_INTERCONEXAO(8, [monthIds, {'TOTAL'}]) = num2cell([itxFunttelApurado,         sum(itxFunttelApurado)]);

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'Table.x_CONCILIACAO'
                    switch updateType
                        case 'startup'
                            obj.Table.x_CONCILIACAO_GERAL        = model.ECDBase.initializeCustomTable('_CONCILIACAO_GERAL');
                            obj.Table.x_CONCILIACAO_INTERCONEXAO = model.ECDBase.initializeCustomTable('_CONCILIACAO_INTERCONEXAO');

                        case 'importFile'
                            fileName = varargin{1};
                            generalSettings = varargin{2};
                            
                            x_CONCILIACAO_GERAL_TEMPLATE        = model.ECDBase.initializeCustomTable('_CONCILIACAO_GERAL');
                            x_CONCILIACAO_INTERCONEXAO_TEMPLATE = model.ECDBase.initializeCustomTable('_CONCILIACAO_INTERCONEXAO');

                            x_CONCILIACAO_GERAL        = readtable(fileName, 'Sheet', 'CONCILIAÇÃO', 'Range', 'B6:O11',  'VariableNamingRule', 'preserve', 'UseExcel', false);
                            x_CONCILIACAO_INTERCONEXAO = readtable(fileName, 'Sheet', 'CONCILIAÇÃO', 'Range', 'B15:O16', 'VariableNamingRule', 'preserve', 'UseExcel', false);

                            % Substitui "NaN" (célula Excel vazia) por 0, caso
                            % aplicável.
                            monthIds = {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'};
                            x_CONCILIACAO_GERAL{:, monthIds}(isnan(x_CONCILIACAO_GERAL{:, monthIds})) = 0;
                            x_CONCILIACAO_INTERCONEXAO{:, monthIds}(isnan(x_CONCILIACAO_INTERCONEXAO{:, monthIds})) = 0;

                            if ~isequal(x_CONCILIACAO_GERAL_TEMPLATE.Properties.VariableNames, x_CONCILIACAO_GERAL.Properties.VariableNames) || ...
                               ~isequal(x_CONCILIACAO_GERAL_TEMPLATE.TIPO, x_CONCILIACAO_GERAL.TIPO) || ...
                               ~isequal(matlab.Compatibility.resolveTableVariableTypes(x_CONCILIACAO_GERAL_TEMPLATE), matlab.Compatibility.resolveTableVariableTypes(x_CONCILIACAO_GERAL))
                                error('model:ECD:UnexpectedTable', 'Unexpected table');
                            end

                            if ~isequal(x_CONCILIACAO_INTERCONEXAO_TEMPLATE.Properties.VariableNames, x_CONCILIACAO_INTERCONEXAO.Properties.VariableNames) || ...
                               ~isequal(x_CONCILIACAO_INTERCONEXAO_TEMPLATE.TIPO, x_CONCILIACAO_INTERCONEXAO.TIPO) || ...
                               ~isequal(matlab.Compatibility.resolveTableVariableTypes(x_CONCILIACAO_INTERCONEXAO_TEMPLATE), matlab.Compatibility.resolveTableVariableTypes(x_CONCILIACAO_INTERCONEXAO))
                                error('model:ECD:UnexpectedTable', 'Unexpected table');
                            end

                            obj.Table.x_CONCILIACAO_GERAL        = x_CONCILIACAO_GERAL;
                            obj.Table.x_CONCILIACAO_INTERCONEXAO = x_CONCILIACAO_INTERCONEXAO;

                            update(obj, 'Table.x_APURACAO_GERAL', 'accountValueChanged', generalSettings)

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                otherwise
                    error('model:ECD:UnexpectedPropertyName', 'Unexpected property name "%s".', propertyName);
            end
        end

        %-----------------------------------------------------------------%
        function checkFileFlag = checkFileStatus(obj, receitaFederalObj, encodingList, checkType)
            arguments
                obj
                receitaFederalObj ws.ReceitaFederal
                encodingList
                checkType char {mustBeMember(checkType, {'OnlyCache', 'Cache+RealTime', 'RealTime'})} = 'Cache+RealTime'                
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

                encodingList = union(obj(ii).Encoding, setdiff(encodingList, obj(ii).Encoding, 'stable'), 'stable');
                for jj = 1:numel(encodingList) 
                    encoding = encodingList{jj};
                    index = find(strcmp({obj(ii).Sources.encoding}, encoding), 1);

                    if ~isempty(index)
                        fileHash = obj(ii).Sources(index).hash;
                    else
                        index = numel(obj(ii).Sources)+1;
                        obj(ii).Sources(index).file       = obj(ii).FileName;
                        obj(ii).Sources(index).period     = obj(ii).Period;
                        obj(ii).Sources(index).encoding   = encoding;
                        obj(ii).Sources(index).terminator = obj(ii).TERMINATOR;

                        fileHash = obj(ii).Hash;
                        if ~strcmp(encoding, obj(ii).Encoding)
                            try
                                fileContent = fileread(obj(ii).FileFullName, 'Encoding', encoding);
                                fileHash = util.calculateFileHash(fileContent, encoding, obj(ii).TERMINATOR);
                            catch
                            end
                        end
                        obj(ii).Sources(index).hash = fileHash;
                    end

                    [validationMessage, validationStatus]    = Get(receitaFederalObj, checkType, 'ECD', fileHash);
                    obj(ii).Sources(index).validationMessage = validationMessage;
                    obj(ii).Sources(index).validationStatus  = validationStatus;

                    if validationStatus == 1 || contains(obj(ii).FileName, fileHash, "IgnoreCase", true)
                        break;
                    end
                end
                
                checkFileFlag = true;
            end
        end

        %-----------------------------------------------------------------%
        function status = isTableRead(obj, tableIdList, generalSettings)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
                generalSettings
            end

            status = false;
            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};
                    tableIdStatus = isfield(obj(ii).Table, ['x' tableId]);

                    if ~tableIdStatus
                        status = true;
                        parseTableAndAddToCache(obj(ii), {tableId}, generalSettings)
                    end
                end
            end
        end

        %-----------------------------------------------------------------%
        function [ordinaryIds, customIds, readIds] = getTableIds(obj)
            checkIfScalar(obj)

            if (~isempty(obj.Content) || ~obj.PeriodMerged) && isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                ordinaryIds = unique(obj.Table.x9900.("REG_BLC")(obj.Table.x9900.("QTD_REG_BLC") > 0));
            else
                ordinaryIds = extractAfter(fieldnames(obj.Table), 'x');
                ordinaryIds(startsWith(ordinaryIds, '_')) = [];
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
        function columnsSpec = getColumnSpecifications(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
            end

            checkIfScalar(obj)

            for ii = 1:numel(tableIdList)
                tableId = tableIdList{ii};
                layoutIdx = find(cellfun(@(x) ismember(obj.Layout, x), model.ECDBase.(['x' tableId])(:,1)), 1);
                required = model.ECDBase.(['x' tableId]){layoutIdx, 2};
                optional = model.ECDBase.(['x' tableId]){layoutIdx, 3};
                complete = [required, optional];

                columnsSpec(ii) = struct( ...
                    'id', tableId, ...
                    'required', {required}, ...
                    'optional', {optional}, ...
                    'complete', {complete} ...
                );
            end
        end

        %-----------------------------------------------------------------%
        function [entryHistoryCount, entryHistoryUniqueValues] = getAccountHistoric(obj, accountName, generalSettings)
            isTableRead(obj, {'_CONTAS_HISTORICO'}, generalSettings);

            entryHistoryCount = [];
            entryHistoryUniqueValues = {};
            
            if ~isempty(obj.Table.x_CONTAS_HISTORICO)
                index = find(strcmp(obj.Table.x_CONTAS_HISTORICO.("COD_CTA"), accountName), 1);

                entryHistoryCount = obj.Table.x_CONTAS_HISTORICO.('TOTAL DE LANÇAMENTOS')(index);
                entryHistoryUniqueValues = obj.Table.x_CONTAS_HISTORICO.('LANÇAMENTOS NORMALIZADOS DEDUPLICADOS'){index};
            end
        end

        %-----------------------------------------------------------------%
        function checkIfScalar(obj)
            if ~isscalar(obj)
                error('model:ECD:ScalarObjectRequired', 'This method requires a scalar object.');
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
        function outputTable = addAccountDescription(obj, mainTable, mainColumns, accountColumn, referenceTableId)
            arguments
                obj
                mainTable        table
                mainColumns      cell
                accountColumn    char {mustBeMember(accountColumn, {'COD_NAT', 'CTA', 'DESCRIÇÃO'})} = 'CTA'
                referenceTableId char = 'xI050'
            end

            if ~ismember('COD_CTA', mainTable.Properties.VariableNames)
                outputTable = mainTable;
                return
            end
            
            checkIfScalar(obj)
        
            % Plano de contas (registro "I050") validado, de forma que cada
            % conta apareça uma única vez.
            planTable = obj.Table.(referenceTableId);
            [~, uniqueAccountIdxs] = unique(planTable.('COD_CTA'));
            planTable = planTable(uniqueAccountIdxs, :);

            % Inclusão de coluna à "mainTable".
            outputTable = join( ...
                mainTable, ...
                planTable, ...
                'Keys', 'COD_CTA', ...
                'LeftVariables', mainColumns, ...
                'RightVariables', accountColumn ...
            );
        
            outputTable = movevars(outputTable, accountColumn, 'After', 'COD_CTA');
        end

        %-----------------------------------------------------------------%
        function [status, msg] = validateReportGenerationRequirements(obj)
            checkIfScalar(obj)
        
            status = true;
            msg = {};
        
            cacheTableIds = {
                'x_APURACAO_GERAL';
                'x_APURACAO_INTERCONEXAO';
                'x_BALANCETE_RESULTADO';
                'x_CONTAS_ANOTACAO'
            };
        
            % Confirma que tabelas foram criadas e estão em cache...
            for ii = 1:numel(cacheTableIds)
                if ~isfield(obj.Table, cacheTableIds{ii})
                    status = false;
                    msg{end+1} = sprintf('• Tabela %s não está disponível em cache.', cacheTableIds{ii});
                end
            end
        
            % Verifica coerência entre ROB e ITX/EILD...
            if isfield(obj.Table, 'x_CONTAS_ANOTACAO')
                declaredMask           = obj.Table.x_CONTAS_ANOTACAO.('Declarado?  ✎') ~= "-";
                declaredIrregularMask  = obj.Table.x_CONTAS_ANOTACAO.('Declarado?  ✎') == "Não informado";
                declaredAsTelecomMask  = ismember(obj.Table.x_CONTAS_ANOTACAO.('Declarado?  ✎'), ["Sim-parcial", "Sim-total"]);
                accountedMask          = obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "Sim";
                nonAccountedMask       = ismember(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎'), ["Não", "-"]);
                interconnectionMask    = ismember(obj.Table.x_CONTAS_ANOTACAO.('Interconexão?  ✎'), ["ITX", "EILD"]);
                missingObservationMask = cellfun(@isempty, obj.Table.x_CONTAS_ANOTACAO.('Observação  ✎'));

                missingDeclaration = accountedMask & ~declaredMask;
                if any(missingDeclaration)
                    status = false;
                    msg{end+1} = '• Toda conta marcada como "Sim" na coluna "Apurado?" deve possuir informação na coluna "Declarado?".';
                end

                irregularDeclaration = declaredIrregularMask & missingObservationMask;
                if any(irregularDeclaration)
                    status = false;
                    msg{end+1} = '• Contas marcadas como "Não informado" na coluna "Declarado?" devem possuir justificativa na coluna "Observação".';
                end

                missingObservation = declaredAsTelecomMask & nonAccountedMask & missingObservationMask;
                if any(missingObservation)
                    status = false;
                    msg{end+1} = '• Contas marcadas como "Sim-parcial" ou "Sim-total" na coluna "Declarado?" e "Não" ou "-" na coluna "Apurado?" devem possuir justificativa na coluna "Observação".';
                end
            
                invalidInterconnection = interconnectionMask & ~accountedMask;
                if any(invalidInterconnection)
                    status = false;
                    msg{end+1} = '• Contas classificadas como ITX ou EILD na coluna "Interconexão?" devem estar marcadas como "Sim" na coluna "Apurado?".';
                end
            end

            msg = strjoin(msg, '<br>');
        end

        %-----------------------------------------------------------------%
        function expectedRows = expectedRowsByTableId(obj, tableId)
            checkIfScalar(obj)
            
            expectedRows = [];
            if isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                tableIdIndex = find(strcmp(obj.Table.x9900.("REG_BLC"), tableId));

                if ~isempty(tableIdIndex)
                    expectedRows = sum(obj.Table.x9900.("QTD_REG_BLC")(tableIdIndex));
                end
            end
        end
    end


    methods (Access = protected)
        %-----------------------------------------------------------------%
        function parseTable(obj, tableId, generalSettings)
            arguments
                obj
                tableId (1,:) char
                generalSettings
            end

            checkIfScalar(obj)
            ordinaryId = false;

            switch tableId
                case '_BALANCETE_GERAL'
                    obj.Table.x_BALANCETE_GERAL = createTrialBalanceTable(obj, 'I155+I355', generalSettings);

                case '_BALANCETE_RESULTADO'
                    isTableRead(obj, {'_BALANCETE_GERAL'}, generalSettings);
                    obj.Table.x_BALANCETE_RESULTADO = filterTrialBalanceByAccountType(obj, '04');

                case '_CONTAS_ANOTACAO'
                    isTableRead(obj, {'_BALANCETE_RESULTADO',  '_APURACAO_GERAL'}, generalSettings);
                    update(obj, 'Table.x_CONTAS_ANOTACAO', 'startup', generalSettings)

                case '_CONTAS_DESCRICAO'
                    % Esse reordenamento é essencial quando se trata de registros
                    % mesclados, tendo em vista que os planos de contas estão
                    % replicados. Ao reordenar, registra-se o última estado de
                    % cada conta.
                    xI050 = flip(obj.Table.xI050(:, {'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}));

                    [accountList, accountIdxs] = unique(xI050.("COD_CTA"), "sorted");
                    numAccounts = numel(accountList);

                    % Prealoca, viabilizando operação em modo paralelo...
                    x_CONTAS_DESCRICAO = model.ECDBase.initializeCustomTable('_CONTAS_DESCRICAO', numAccounts);

                    parpoolCheck()
                    parfor ii = 1:numAccounts
                        accountId = accountList{ii};
                        accountDescription = strtrim(xI050.("CTA"){accountIdxs(ii)});
                        accountNumLevel = str2double(xI050.("NIVEL"){accountIdxs(ii)});
        
                        description = {};
                        currentId = accountId;
        
                        for jj = 1:accountNumLevel
                            currentIndex = find(strcmp(xI050.("COD_CTA"), currentId),  1);
                            currentId = xI050.("COD_CTA_SUP"){currentIndex};
                            
                            superiorDescription = '';
                            if ~isempty(currentId)
                                superiorIndex = find(strcmp(xI050.("COD_CTA"), currentId), 1);
                                if ~isempty(superiorIndex)
                                    superiorDescription = strtrim(xI050.("CTA"){superiorIndex});
                                end
                            end
        
                            if jj == 1 && ~isempty(accountDescription) && ~isequal(accountDescription, superiorDescription)
                                description{end+1}  = accountDescription;
                            end
                            
                            if ~isempty(superiorDescription)
                                description{end+1}  = superiorDescription;
                            end
                        end
        
                        description  = strjoin(flip(description), '  ↳  ');
                        x_CONTAS_DESCRICAO(ii, :) = {accountId, description};
                    end

                    obj.Table.x_CONTAS_DESCRICAO = x_CONTAS_DESCRICAO;

                case '_CONTAS_HISTORICO'
                    isTableRead(obj, {'_BALANCETE_RESULTADO'}, generalSettings);

                    accountList = obj.Table.x_BALANCETE_RESULTADO.('COD_CTA');
                    numAccounts = numel(accountList);

                    refTable = [];
                    if isfield(obj.Table, 'xI200_I250') && ~isempty(obj.Table.xI200_I250)
                        refTable = obj.Table.xI200_I250(:, {'COD_CTA', 'COD_HIST_PAD', 'HIST'});
                    else
                        isTableRead(obj, {'I250'}, generalSettings);

                        if isfield(obj.Table, 'xI250') && ~isempty(obj.Table.xI250)
                            refTable = obj.Table.xI250(:, {'COD_CTA', 'COD_HIST_PAD', 'HIST'});
                            onCacheCleanup('I250')
                        end
                    end

                    if isempty(accountList) || isempty(refTable)
                        obj.Table.x_CONTAS_HISTORICO = model.ECDBase.initializeCustomTable('_CONTAS_HISTORICO', 0);
                        return
                    end

                    isTableRead(obj, {'I075'}, generalSettings);

                    % Identifica apenas registros relacionados às contas de
                    % resultado.
                    xI250_I075 = outerjoin( ...
                        refTable, ...
                        obj.Table.xI075, ...
                        "LeftKeys", "COD_HIST_PAD", ...
                        "RightKeys", "COD_HIST", ...
                        "LeftVariables", {'COD_CTA', 'HIST'}, ...
                        "RightVariables", {'DESCR_HIST'}, ...
                        "Type", "left" ...
                    );
                    
                    [~, accountIdxs] = ismember(xI250_I075.("COD_CTA"), accountList);
                    xI250_I075(~accountIdxs, :) = [];

                    % Prealoca, viabilizando operação em modo paralelo...
                    x_CONTAS_HISTORICO = model.ECDBase.initializeCustomTable('_CONTAS_HISTORICO', numAccounts);

                    for ii = 1:numAccounts
                        accountId = accountList{ii};
                        index = strcmp(xI250_I075.("COD_CTA"), accountId);
            
                        if any(index)
                            tmpHist = xI250_I075.("HIST")(index);
                            description = xI250_I075.("DESCR_HIST")(index);
            
                            mergeIdxs = ~cellfun(@isempty, description) & ~strcmp(description, tmpHist);
                            if any(mergeIdxs)
                                tmpHist(mergeIdxs) = strcat(description(mergeIdxs), {' ↳ '}, tmpHist(mergeIdxs));
                            end

                            hist = util.deduplicateAccountEntryHistory('rawI250', tmpHist);
                        else
                            hist = {'-'};
                        end

                        if isscalar(hist)
                            hist = {hist};
                        end

                        x_CONTAS_HISTORICO(ii, :) = {accountId, sum(index), hist};
                    end

                    obj.Table.x_CONTAS_HISTORICO = x_CONTAS_HISTORICO;

                case {'_APURACAO_GERAL', '_APURACAO_INTERCONEXAO'}
                    update(obj, 'Table.x_APURACAO_GERAL', 'startup')

                case {'_CONCILIACAO_GERAL', '_CONCILIACAO_INTERCONEXAO'}
                    update(obj, 'Table.x_CONCILIACAO', 'startup')

                case {'C050_C051_C052', 'I050_I051_I052', 'I150_I155', 'I350_I355', 'I200_I250'}
                    switch tableId
                        case 'C050_C051_C052'
                            obj.Table.xC050_C051_C052 = mergeTables(obj, 'C050', {'C051', 'C052'}, generalSettings);                        
                        case 'I050_I051_I052'
                            obj.Table.xI050_I051_I052 = mergeTables(obj, 'I050', {'I051', 'I052'}, generalSettings);
                        case 'I150_I155'
                            obj.Table.xI150_I155      = mergeTables(obj, 'I150', {'I155'},         generalSettings);
                        case 'I350_I355'
                            obj.Table.xI350_I355      = mergeTables(obj, 'I350', {'I355'},         generalSettings);
                        case 'I200_I250'
                            MIN_ROW_COUNT = generalSettings.context.FILE.largeTable.minRowCount; % 100000
                            expectedRows = expectedRowsByTableId(obj, 'I250');

                            mainTableColumns = {}; 
                            secondaryTableColumns = {};

                            if ~isempty(expectedRows) && expectedRows > MIN_ROW_COUNT
                                if isfield(generalSettings.context.FILE.largeTable.cacheColumns, 'I200')
                                    mainTableColumns = generalSettings.context.FILE.largeTable.cacheColumns.('I200');
                                end

                                if isfield(generalSettings.context.FILE.largeTable.cacheColumns, 'I250')
                                    secondaryTableColumns = generalSettings.context.FILE.largeTable.cacheColumns.('I250');
                                end
                            end

                            obj.Table.xI200_I250 = mergeTables(obj, 'I200', {'I250'}, generalSettings, mainTableColumns, secondaryTableColumns);
                    end
                    onCacheCleanup(tableId)

                case {'J800', 'J801'}
                    if ~isempty(obj.Content)
                        ordinaryId   = true;
                        regexMatches = extractBetween(obj.Content, ['|' tableId '|'], ['|' tableId 'FIM|'], 'Boundaries', 'inclusive');
                    else
                        util.fileread(obj, obj.FileFullName, generalSettings, false, {'J800', 'J801'});
                    end

                otherwise
                    if ~isempty(obj.Content)
                        ordinaryId   = true;
                        regexPattern = ['^\|' tableId '\|.*'];
                        regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors', 'dotexceptnewline')';
                        regexMatches = strrep(regexMatches, sprintf('\r'), '');
                    else
                        util.fileread(obj, obj.FileFullName, generalSettings, false, {tableId});
                    end
            end

            if ordinaryId
                columnsSpec = getColumnSpecifications(obj, {tableId});
    
                if isempty(regexMatches)
                    columnTypes = model.ECDBase.getFieldSpecification(columnsSpec.complete, 'DataType');
                    tableOut = table('Size', [0, numel(columnsSpec.complete)], 'VariableNames', columnsSpec.complete, 'VariableTypes', columnTypes);
                else
                    tableOut = parseFileBlock(obj, regexMatches, columnsSpec, generalSettings);
                end

                obj.Table.(['x' tableId]) = tableOut;
            end

            function onCacheCleanup(id)
                if ~generalSettings.context.FILE.largeTable.cacheEnabled
                    tablesToDeleteFromCache = setdiff(strsplit(id, '_'), generalSettings.context.ECD.cacheTables);
                    update(obj, 'Table.NonEssentialFiles', 'onCacheCleanup', tablesToDeleteFromCache)
                end
            end
        end

        %-----------------------------------------------------------------%
        function tableOut = parseFileBlock(obj, fileBlock, columnsSpec, generalSettings)
            arguments
                obj
                fileBlock
                columnsSpec % struct('id', {}, 'requiredCol', {}, 'optionalCol', {}, 'completeCol', {})
                generalSettings
            end

            checkIfScalar(obj)

            MIN_ROW_COUNT = generalSettings.context.FILE.largeTable.minRowCount; % 100000
            expectedRows  = expectedRowsByTableId(obj, columnsSpec.id);

            if ~isempty(expectedRows) && expectedRows > MIN_ROW_COUNT
                if isfield(generalSettings.context.FILE.largeTable.cacheColumns, columnsSpec.id)
                    variableNames = generalSettings.context.FILE.largeTable.cacheColumns.(columnsSpec.id);
                else
                    variableNames = columnsSpec.complete;
                end
                numVariableNames = numel(variableNames);

                tableTemplate      = cell(expectedRows, numVariableNames);
                tableTemplate(:,1) = {columnsSpec.id};
                if numVariableNames > 1
                    tableTemplate(:, 2:end) = {''};
                end
                tableOut = cell2table(tableTemplate, 'VariableNames', variableNames);
    
                fileBlockLengths = strlength(fileBlock) - 1;
                numLoops = 0;

                while ~isempty(fileBlock)
                    numLoops = numLoops + 1;
                    numRows  = min(height(fileBlock), MIN_ROW_COUNT);
                    mergedFileBlock = split(extractBetween(fileBlock(1:numRows), 2, fileBlockLengths(1:numRows)), '|', 2);
                    tableTempOut = model.ECDBase.cellToTable(mergedFileBlock, columnsSpec);

                    fileBlock(1:numRows) = [];
                    fileBlockLengths(1:numRows) = [];

                    tableStartIndex = (numLoops-1)*MIN_ROW_COUNT + 1;
                    tableEndIndex   = tableStartIndex + numRows - 1;
                    tableOut(tableStartIndex:tableEndIndex, variableNames) = tableTempOut(:, variableNames);
                end

            else
                mergedFileBlock = split(extractBetween(fileBlock, 2, strlength(fileBlock) - 1), '|', 2);
                tableOut = model.ECDBase.cellToTable(mergedFileBlock, columnsSpec);
            end

            % Conversão de unidades...
            for kk = 1:numel(columnsSpec.complete)
                columnName = columnsSpec.complete{kk};

                if ~ismember(columnName, tableOut.Properties.VariableNames)
                    continue
                end

                switch model.ECDBase.getFieldSpecification(columnName, 'DataType')
                    case 'double'
                        if ~isa(tableOut.(columnName), 'double')
                            emptyIndexes = cellfun(@isempty, tableOut.(columnName));
                            if any(emptyIndexes)
                                tableOut.(columnName)(emptyIndexes) = {'0'};
                            end
                            tableOut.(columnName) = sscanf(strjoin(strrep(tableOut.(columnName), ',', '.')), '%f');
                        end

                    case 'datetime'
                        if ~isa(tableOut.(columnName), 'datetime')
                            tableOut.(columnName) = datetime(tableOut.(columnName), 'InputFormat', 'ddMMyyyy');
                        end
                end
            end
        end

        %-----------------------------------------------------------------%
        function mergedTable = mergeTables(obj, mainId, secondaryIds, generalSettings, mainTableColumns, secondaryTableColumns)
            arguments
                obj
                mainId          (1,:) char {mustBeMember(mainId, {'C050', 'I050', 'I150', 'I200', 'I350'})}
                secondaryIds    (1,:) cell
                generalSettings
                mainTableColumns      cell = {}
                secondaryTableColumns cell = {}
            end

            checkIfScalar(obj)

            % Verifica se os registros ordinários foram lidos.
            tableIdList = [mainId, secondaryIds];
            
            % Verifica se a tabela mesclada já foi criada.
            mergedTableId = ['x' strjoin(tableIdList, '_')];
            if isfield(obj.Table, mergedTableId)
                mergedTable = obj.Table.(mergedTableId);
                return
            end

            isTableRead(obj, tableIdList, generalSettings);

            % Cria coluna que servirá como "chave", relacionando as tabelas
            % que são apresentadas em sequência no arquivo. Nome da coluna
            % é "_TEM_KEY".
            mainTable = obj.Table.(['x' mainId]);
            if isempty(mainTable)
                mergedTable = [];
                return
            end

            % Converte conteúdo de arquivo em lista de células, orientada à
            % quebra de linha. Identifica o número da linha de cada um dos
            % registros sob análise - "mainId" e "secondaryIds".
            if ~isempty(obj.Content)
                splitContent = splitlines(obj.Content);
                fileIndexes  = cellfun(@(x) find(startsWith(splitContent, x)), strcat('|', tableIdList, '|'), 'UniformOutput', false);
            else
                fileIndexes  = [{obj.Table.(['x' mainId]).Properties.UserData}, cellfun(@(x) obj.Table.(['x' x]).Properties.UserData, secondaryIds, 'UniformOutput', false)];
            end

            mainTableHeight = height(mainTable);
            mainTable.("_TEMP_KEY") = (1:mainTableHeight)';
            
            % Em relação às tabelas auxiliares:            
            edges = [fileIndexes{1}; inf];
            tempIdColumn = {};            
            for ii = 1:numel(secondaryIds)
                tempIdColumn{ii} = discretize(fileIndexes{ii+1}, edges);
            end
            secondaryTables = cellfun(@(x,y) addvars(x, y, 'NewVariableName', '_TEMP_KEY'), cellfun(@(x) obj.Table.(['x' x]), secondaryIds, "UniformOutput", false), tempIdColumn, 'UniformOutput', false);

            if isscalar(secondaryTables)
                secondaryTable = secondaryTables{1};                
            else
                secondaryTable = outerjoin( ...
                    removevars(secondaryTables{1}, 'REG'), ...
                    removevars(secondaryTables{2}, 'REG'), ...
                    "Keys", '_TEMP_KEY', ...
                    "MergeKeys", true, ...
                    'RightVariables', setdiff(secondaryTables{2}.Properties.VariableNames, secondaryTables{1}.Properties.VariableNames) ...
                );
            end

            % Abrindo caminho p/ diminuir informação resultado da mesclagem
            % de tabelas, deixando apenas o essencial.
            if isempty(mainTableColumns)
                mainTableColumns = mainTable.Properties.VariableNames;
            end

            if isempty(secondaryTableColumns)
                secondaryTableColumns = setdiff(secondaryTable.Properties.VariableNames, mainTable.Properties.VariableNames);
            end

            mergedTable = outerjoin( ...
                mainTable, ...
                secondaryTable, ...
                'Keys', '_TEMP_KEY', ...
                'MergeKeys', true, ...
                'Type', 'left', ...
                'LeftVariables', mainTableColumns, ...
                'RightVariables', setdiff(secondaryTableColumns, mainTableColumns) ...
            );
            
            if ismember('_TEMP_KEY', mergedTable.Properties.VariableNames)
                mergedTable = removevars(mergedTable, '_TEMP_KEY');
            end
            mergedTable.("REG")(:) = {strjoin(tableIdList, '_')};
        end

        %-----------------------------------------------------------------%
        function initializeCompanyContext(obj, projectData, generalSettings, receitaFederalObj)
            arguments
                obj
                projectData
                generalSettings
                receitaFederalObj = []
            end

            checkIfScalar(obj)

            if isfield(obj.Table, 'x0000') && ~isempty(obj.Table.x0000)
                obj.Table.x0000 = sortrows(obj.Table.x0000, 'DT_INI');

                obj.CompanyName = upper(strtrim(obj.Table.x0000.NOME{end}));
                obj.CompanyId = checkCNPJOrCPF(obj.Table.x0000.CNPJ{end}, 'NumberValidation');                
                obj.CompanyInfo(1) = struct( ...
                    'CNPJ', obj.Table.x0000.CNPJ{end}, ...
                    'IE', obj.Table.x0000.IE{end}, ...
                    'IM', obj.Table.x0000.IM{end}, ...
                    'NIRE', '', ...
                    'UF', obj.Table.x0000.UF{end}, ...
                    'City', obj.Table.x0000.COD_MUN{end} ...
                );

                obj.State = obj.CompanyInfo.UF;
                obj.Period = [min(obj.Table.x0000.DT_INI), max(obj.Table.x0000.DT_FIN)];
                obj.Period.Format = 'dd/MM/yyyy';

                periodYear = year(obj.Period(1));
                periodRate = zeros(1, 12);
                rateErrorMsg = {};
                for periodMonth = 1:12
                    [periodRate(periodMonth), msgError] = calculateIcmsRate(projectData, obj.CompanyInfo.UF, datetime([periodYear, periodMonth, 1]), 'mean', 3);
                    if ~isempty(msgError)
                        rateErrorMsg{end+1} = msgError;
                    end
                end

                if isscalar(unique(periodRate))
                    periodRate = periodRate(1);
                end

                if ~isempty(rateErrorMsg)
                    obj.GUI.warnings{end+1} = matlab.jsonencode(struct( ...
                        'id', 'RateError', ...
                        'message', strjoin(rateErrorMsg, '<br>') ...
                    ));
                end

                obj.GUI.icmsRate.default.rate = periodRate;
                obj.GUI.icmsRate.current = obj.GUI.icmsRate.default;
            end

            if isfield(obj.Table, 'xI030') && ~isempty(obj.Table.xI030)
                nire = unique(obj.Table.xI030.NIRE);                
                obj.CompanyInfo(1).NIRE = nire{end};
            end

            if ~isempty(receitaFederalObj)
                checkFileStatus(obj, receitaFederalObj, generalSettings.context.FILE.encodingList);
            end

            obj.GUI.hasTransactions = checkIfHasTransactions(obj);
            obj.GUI.hasValidPeriod  = checkIfValidPeriod(obj);
            obj.GUI.hasValidStatus  = checkIfValidStatus(obj);
        end

        %-----------------------------------------------------------------%
        function trialBalance = createTrialBalanceTable(obj, tableIdSource, generalSettings)
            arguments
                obj 
                tableIdSource {mustBeMember(tableIdSource, {'I155+I355' , 'I200+I250'})}
                generalSettings 
            end

            checkIfScalar(obj)

            switch tableIdSource
                case 'I155+I355'
                    parseTableAndAddToCache(obj, {'I150_I155', 'I350_I355'}, generalSettings)

                    if ~isfield(obj.Table, 'xI150_I155') || isempty(obj.Table.xI150_I155)
                        trialBalance = createTrialBalanceTable(obj, 'I200+I250', generalSettings);
                        return
                    end

                    mergedTable_I150_I155 = obj.Table.xI150_I155;
                    mergedTable_I150_I155.("VL_MOVIMENTACAO")  = obj.Table.xI150_I155.("VL_CRED") - obj.Table.xI150_I155.("VL_DEB");

                    if isfield(obj.Table, 'xI350_I355') && ~isempty(obj.Table.xI350_I355)
                        mergedTable_I350_I355 = obj.Table.xI350_I355;
                        mergedTable_I350_I355.("VL_CTA_COM_SINAL") = mergedTable_I350_I355.("VL_CTA");
                        negativeValueIndexes  = strcmp(mergedTable_I350_I355.("IND_DC"), 'D');
                        mergedTable_I350_I355.("VL_CTA_COM_SINAL")(negativeValueIndexes) = -mergedTable_I350_I355.("VL_CTA_COM_SINAL")(negativeValueIndexes);
                    end

                    accountIdList = unique(obj.Table.xI150_I155.("COD_CTA"));
                    numAccounts   = numel(accountIdList);
                    trialBalance  = prealocateTrialBalance(numAccounts);

                    for ii = 1:numAccounts
                        accountId     = accountIdList{ii};                        
                        accountTable1 = mergedTable_I150_I155(strcmp(mergedTable_I150_I155.("COD_CTA"), accountId), :);
                        accountTable2 = [];
                        if isfield(obj.Table, 'xI350_I355') && ~isempty(obj.Table.xI350_I355)
                            accountTable2 = mergedTable_I350_I355(strcmp(mergedTable_I350_I355.("COD_CTA"), accountId), :);
                        end
                        
                        % Sumariza-se mensalmente os fatos contábeis para cada conta.
                        accountBalanceByMonth = zeros(1, 12);
                        for jj = 1:12
                            monthAccountTable1Idxs = month(accountTable1.("DT_FIN")) == jj;
                            accountBalanceByMonth(jj) = sum(accountTable1.("VL_MOVIMENTACAO")(monthAccountTable1Idxs));

                            if ~isempty(accountTable2)
                                monthAccountTable2Idxs = month(accountTable2.("DT_RES")) == jj;

                                if any(monthAccountTable2Idxs)
                                    accountBalanceByMonth(jj) = accountBalanceByMonth(jj) + sum(accountTable2.("VL_CTA_COM_SINAL")(monthAccountTable2Idxs));
                                end
                            end
                        end
        
                        trialBalance(ii, :) = [{'', accountId}, num2cell([accountBalanceByMonth, sum(accountBalanceByMonth)])];
                    end
                
                case 'I200+I250'
                    parseTableAndAddToCache(obj, {'I200_I250'}, generalSettings)
        
                    if ~isfield(obj.Table, 'xI200_I250') || isempty(obj.Table.xI200_I250)
                        trialBalance = model.ECDBase.initializeCustomTable('_BALANCETE_GERAL', 0);
                        return
                    end
        
                    % Aplica filtros na tabela de fatos contábeis (I200_I250), de forma 
                    % que sejam considerados apenas os lançamentos "NORMAIS". Além
                    % disso, cria-se coluna "VL_DC_COM_SINAL".
                    mergedTable_I200_I250 = obj.Table.xI200_I250;
                    mergedTable_I200_I250.("VL_DC_COM_SINAL") = mergedTable_I200_I250.("VL_DC");
                    negativeValueIndexes  = strcmp(mergedTable_I200_I250.("IND_DC"), 'D');
                    mergedTable_I200_I250.("VL_DC_COM_SINAL")(negativeValueIndexes) = -mergedTable_I200_I250.("VL_DC_COM_SINAL")(negativeValueIndexes);
        
                    unnormalEntryIndexes  = ~strcmp(mergedTable_I200_I250.("IND_LCTO"), 'N');
                    mergedTable_I200_I250(unnormalEntryIndexes, :) = [];
        
                    % Deixando apenas o essencial porque essa tabela poderá ser
                    % passada para cada um dos núcleos de processamento, caso 
                    % habilitado o processamento em paralelo.
                    mergedTable_I200_I250 = mergedTable_I200_I250(:, {'COD_CTA', 'DT_LCTO', 'VL_DC_COM_SINAL'});
                    
                    accountUniqueIdList = unique(obj.Table.xI200_I250.("COD_CTA"));
                    numAccounts  = numel(accountUniqueIdList);
                    trialBalance = prealocateTrialBalance(numAccounts);
        
                    for ii = 1:numAccounts
                        accountId      = accountUniqueIdList{ii};
                        accountIndexes = strcmp(mergedTable_I200_I250.("COD_CTA"), accountId);
                        accountTable   = mergedTable_I200_I250(accountIndexes, :);
                        
                        % Sumariza-se mensalmente os fatos contábeis para cada conta.
                        accountBalanceByMonth = zeros(1, 12);
                        for jj = 1:12
                            monthAccountTableIdxs = month(accountTable.("DT_LCTO")) == jj;
                            accountBalanceByMonth(jj) = sum(accountTable.("VL_DC_COM_SINAL")(monthAccountTableIdxs));
                        end
        
                        trialBalance(ii, :) = [{'', accountId}, num2cell([accountBalanceByMonth, sum(accountBalanceByMonth)])];
                    end
            end

            % Adiciona coluna "COD_NAT", que possibilitará aplicar filtros, 
            % identificando contas de resultados (COD_NAT = 4), por exemplo.
            trialBalance = addAccountDescription(obj, trialBalance, setdiff(trialBalance.Properties.VariableNames, 'COD_NAT', 'stable'), 'COD_NAT');

            function tbl = prealocateTrialBalance(numAccounts)
                tbl = model.ECDBase.initializeCustomTable('_BALANCETE_GERAL', numAccounts);
            end
        end

        %-----------------------------------------------------------------%
        function trialBalance = filterTrialBalanceByAccountType(obj, accountType)
            arguments
                obj
                accountType char {mustBeMember(accountType, {'01', '02', '03', '04', '05', '09'})} = '04'
            end

            checkIfScalar(obj)

            % "Código da Natureza das Contas/Grupos de Contas" classifica a 
            % natureza contábil de cada conta ou grupo de contas - "Contas
            % de Ativo" (01), "Contas de Passivo" (02), "Patrimônio Líquido"
            % (03), "Contas de Resultado" (04), "Contas de Compensação" (05)
            % e "Outras" (09).

            trialBalance = obj.Table.x_BALANCETE_GERAL;
            indexes = strcmp(trialBalance.("COD_NAT"), accountType);
            trialBalance = removevars(trialBalance(indexes, :), 'COD_NAT');
        end

        %-----------------------------------------------------------------%
        function hasTransactions = checkIfHasTransactions(obj)
            checkIfScalar(obj)

            expectedI155Rows = expectedRowsByTableId(obj, 'I155');
            expectedI200Rows = expectedRowsByTableId(obj, 'I200');
            hasTransactions = false;

            if ((~isempty(expectedI155Rows) && expectedI155Rows > 0) || (~isempty(expectedI200Rows) && expectedI200Rows > 0)) && isfield(obj.Table, 'xI050') && any(strcmp(obj.Table.xI050.('COD_NAT'), '04'))
                hasTransactions = true;
            end
        end

        %-----------------------------------------------------------------%
        function updatedMonthlyData = applyReconciliationAdjustment(obj, monthlyData, reconciliationType, accountType)
            arguments
                obj
                monthlyData
                reconciliationType {mustBeMember(reconciliationType, {'_CONCILIACAO_GERAL', '_CONCILIACAO_INTERCONEXAO'})}
                accountType        {mustBeMember(accountType, {'ROB TELECOM', 'ICMS ESTIMADO', 'ICMS CONTÁBIL', 'PIS CONTÁBIL', 'COFINS CONTÁBIL'})}
            end
        
            reconciliationTable = obj.Table.(['x' reconciliationType]);        
            [~, accountTypeIdx] = ismember(accountType, reconciliationTable.TIPO);
        
            if accountTypeIdx
                monthlyAdjustment  = reconciliationTable{accountTypeIdx, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}};        
                updatedMonthlyData = monthlyData + monthlyAdjustment;
            else
                updatedMonthlyData = monthlyData;
            end
        end
    end

end