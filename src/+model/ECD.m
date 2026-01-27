classdef ECD < handle

    % SINTAXE:
    % >> ecdObj = model.ECD.empty;
    % >> ecdObj = addFiles(ecdObj, {'Filename1.txt', 'Filename2.txt'});

    properties
        %-----------------------------------------------------------------%
        FileName
        FileFullName

        Size
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
            'icmsDefaultRate', struct( ...
                'type', 'auto', ...
                'rate', [] ...
            ), ...
            'tableView', struct( ...
                'id', {}, ...
                'filter', {}, ...
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
                     obj(idx).Size, ...
                     obj(idx).Encoding, ...
                     obj(idx).EncodingInfo, ...
                     obj(idx).Hash, bigFileWarning] = util.fileread(fileFullName, generalSettings.FILE.encodingList);

                    if numel(obj) > 1 && ismember(obj(idx).Hash, {obj(1:end-1).Hash})
                        error('model:ECD:FileAlreadyRead', 'File content has already been read.')
                    end

                    if ~isempty(bigFileWarning)
                        obj(idx).GUI.warnings{end+1} = jsonencode(bigFileWarning);
                    end

                    % Leitura do registro "I010", identificando o layout do
                    % arquivo. Como essa ficha não mudou ao longo do tempo, 
                    % considera-se que o layout é igual a 9 (mais recente), 
                    % mas depois de lida a ficha, o valor é atualizado.
                    obj(idx).Layout = 9;
                    parseTableAndAddToCache(obj(idx), {'I010'}, generalSettings)

                    if ~isfield(obj(idx).Table, 'xI010') || isempty(obj(idx).Table.('xI010'))
                        error('model:ECD:UnexpectedEmptyTable', 'Unexpected empty table "I010".');
                    end
                    obj(idx).Layout = obj(idx).Table.xI010.COD_VER_LC(1);

                    % Leitura do registro "9900", , o qual registra o número
                    % de linhas de cada registro, o que possibilita validação 
                    % do processo de leitura. No caso de um registro mesclado,
                    % o registro "9900" deve ser agrupado.
                    parseTableAndAddToCache(obj(idx), {'9900'}, generalSettings)

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
                    % ("0000" e "I030") e plano de contas ("I050").
                    parseTableAndAddToCache(obj(idx), [{'0000', 'I030', 'I050'}, generalSettings.ECD.customTables.autoload'], generalSettings)

                    if isfield(obj(idx).Table, 'x0000') && ~isempty(obj(idx).Table.x0000)
                        obj(idx).CompanyName    = upper(strtrim(obj(idx).Table.x0000.NOME{1}));
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
                            [periodRate(periodMonth), msgError] = calculateInssRate(projectData, obj(idx).CompanyInfo.UF, datetime([periodYear, periodMonth, 1]), 'mean', 3);
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
                        checkFileStatus(obj(idx), receitaFederalObj, generalSettings.FILE.encodingList);
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
        function [obj, msg] = mergeFiles(obj, projectData, generalSettings, indexes, tempPath)
            try
                content  = strjoin({obj(indexes).Content}, char(obj(indexes(1)).TERMINATOR));
                tempFile = [appEngine.util.DefaultFileName(tempPath, 'monitorSPED') '.txt'];
                writematrix(content, tempFile, "FileType", "text", "QuoteStrings", "none", "Encoding", obj(indexes(1)).Encoding);
    
                [obj, msg] = addFiles(obj, projectData, generalSettings, tempFile, indexes);
            catch ME
                msg = ME.message;
            end
        end

        %-----------------------------------------------------------------%
        function parseTableAndAddToCache(obj, tableIdList, generalSettings)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
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
                            obj(ii).GUI.warnings{end+1} = jsonencode(struct('id', tableId, 'expectedRows', expectedRows, 'readRows', readRows));
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
                                                                'Table.NonEssentialFiles';
                                                                'Table.x_CONTAS_ANOTACAO';
                                                                'Table.x_TABELA_APURACAO' })}
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
                            filterIndex = varargin{2};
                            obj.GUI.tableView(filterIndex).id     = tableId;
                            obj.GUI.tableView(filterIndex).filter = tableFiltering;

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'GUI.TableView.Style'
                    switch updateType
                        case 'addStyle'
                            tableId = varargin{1};
                            styleIndex = varargin{2};
                            styleConfig = varargin{3};
                            obj.GUI.tableView(styleIndex).id = tableId;
                            obj.GUI.tableView(styleIndex).style = styleConfig;

                        case 'removeSelectedCellStyle'
                            styleIndex = varargin{1};
                            styleConfig = varargin{2};
                            obj.GUI.tableView(styleIndex).style = styleConfig;

                        case 'removeTableStyle'
                            styleIndex = varargin{1};                            
                            obj.GUI.tableView(styleIndex).style = {};

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'Table.NonEssentialFiles'
                    switch updateType
                        case 'onCacheCleanup'
                            tableIdList = varargin{1};
                            obj.Table = rmfield(obj.Table, strcat('x', tableIdList));

                        otherwise
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'Table.x_CONTAS_ANOTACAO'
                    generalSettings = varargin{1};

                    switch updateType
                        case 'startup'
                            accountList = obj.Table.x_BALANCETE_RESULTADO.('COD_CTA');
                            obj.Table.x_CONTAS_ANOTACAO = model.ECDBase.initializeCustomTable('_CONTAS_ANOTACAO', accountList, generalSettings);

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

                        case 'valueChanged:Apurado?'
                            rowIndex = varargin{2};
                            newValue = varargin{3};

                            obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎')(rowIndex) = newValue;
                            switch newValue
                                case 'Sim'
                                    obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = jsonencode(obj.GUI.icmsDefaultRate);
                                otherwise
                                    obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = '-';
                            end

                        case 'valueChanged:Alíquota ICMS'
                            rowIndex = varargin{2};
                            newValue = varargin{3};

                            obj.Table.x_CONTAS_ANOTACAO.('Alíquota ICMS'){rowIndex} = newValue;

                        case 'valueChanged:Observação'
                            rowIndex = varargin{2};
                            newValue = varargin{3};

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
                            error('model:ECD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                    update(obj, 'Table.x_TABELA_APURACAO', 'accountValueChanged', generalSettings)

                case 'Table.x_TABELA_APURACAO'
                    switch updateType
                        case 'startup'
                            obj.Table.x_TABELA_APURACAO = model.ECDBase.initializeCustomTable('_TABELA_APURACAO');

                        case 'accountValueChanged'
                            generalSettings   = varargin{1};
                            pisDefaultTax     = generalSettings.ECD.taxConfig.PIS;     % 0.0065;
                            cofinsDefaultTax  = generalSettings.ECD.taxConfig.COFINS;  % 0.03;
                            fustDefaultTax    = generalSettings.ECD.taxConfig.FUST;    % 0.01;
                            funttelDefaultTax = generalSettings.ECD.taxConfig.FUNTTEL; % 0.005;
                            
                            robContabilIdx    = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "Sim");
                            icmsContabilIdx   = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "ICMS Telecom");
                            pisContabilIdx    = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "PIS Telecom");
                            cofinsContabilIdx = find(obj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "COFINS Telecom");

                            % ## ROB / ICMS ##
                            monthIds          = {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'};
                            robContabil       = zeros(1, 12);
                            robContabilTable  = innerjoin(obj.Table.x_CONTAS_ANOTACAO(robContabilIdx, {'COD_CTA', 'Alíquota ICMS'}), obj.Table.x_BALANCETE_RESULTADO, "Keys", "COD_CTA", "RightVariables", monthIds);
                            if ~isempty(robContabilTable)
                                robContabil   = sum(robContabilTable{:, monthIds}, 1);
                            end
                            
                            icmsEstimado      = zeros(1, 12);
                            for ii = 1:height(robContabilTable)
                                icmsInfo      = jsondecode(robContabilTable.('Alíquota ICMS'){ii});
                                icmsRate      = icmsInfo.rate';

                                if isscalar(icmsRate)
                                    icmsRate  = icmsRate .* ones(1, 12);
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
                            obj.Table.x_TABELA_APURACAO('ROB TELECOM',                    [monthIds, {'TOTAL'}]) = num2cell(round([robContabil,            sum(robContabil)],            2));
                            obj.Table.x_TABELA_APURACAO('ICMS TELECOM',                   [monthIds, {'TOTAL'}]) = num2cell(round([icmsEstimado,           sum(icmsEstimado)],           2));
                            obj.Table.x_TABELA_APURACAO('ICMS CONTÁBIL',                  [monthIds, {'TOTAL'}]) = num2cell(round([icmsContabil,           sum(icmsContabil)],           2));
                            obj.Table.x_TABELA_APURACAO('BÁSE DE CÁLCULO (PIS/COFINS)',   [monthIds, {'TOTAL'}]) = num2cell(round([baseCalculoPisCofins,   sum(baseCalculoPisCofins)],   2));
                            obj.Table.x_TABELA_APURACAO('PIS TELECOM',                    [monthIds, {'TOTAL'}]) = num2cell(round([pisEstimado,            sum(pisEstimado)],            2));
                            obj.Table.x_TABELA_APURACAO('PIS CONTÁBIL',                   [monthIds, {'TOTAL'}]) = num2cell(round([pisContabil,            sum(pisContabil)],            2));
                            obj.Table.x_TABELA_APURACAO('COFINS TELECOM',                 [monthIds, {'TOTAL'}]) = num2cell(round([cofinsEstimado,         sum(cofinsEstimado)],         2));
                            obj.Table.x_TABELA_APURACAO('COFINS CONTÁBIL',                [monthIds, {'TOTAL'}]) = num2cell(round([cofinsContabil,         sum(cofinsContabil)],         2));
                            obj.Table.x_TABELA_APURACAO('BÁSE DE CÁLCULO (FUST/FUNTTEL)', [monthIds, {'TOTAL'}]) = num2cell(round([baseCalculoFustFunttel, sum(baseCalculoFustFunttel)], 2));
                            obj.Table.x_TABELA_APURACAO('VALOR APURADO FUST',             [monthIds, {'TOTAL'}]) = num2cell(round([fustApurado,            sum(fustApurado)],            2));
                            obj.Table.x_TABELA_APURACAO('VALOR APURADO FUNTTEL',          [monthIds, {'TOTAL'}]) = num2cell(round([funttelApurado,         sum(funttelApurado)],         2));

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

                    if validationStatus == 1
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

            if isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
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
        function hist = getAccountHistoric(obj, accountName, generalSettings)
            isTableRead(obj, {'I075', 'I200_I250'}, generalSettings);

            hist  = {'(não identificado)'};
            index = find(strcmp(obj.Table.xI200_I250.("COD_CTA"), accountName));

            if ~isempty(index)
                relatedTable = outerjoin( ...
                    obj.Table.xI200_I250(index, :), ...
                    obj.Table.xI075, ...
                    "LeftKeys", "COD_HIST_PAD", ...
                    "RightKeys", "COD_HIST", ...
                    "LeftVariables", {'COD_CTA', 'HIST'}, ...
                    "RightVariables", {'DESCR_HIST'}, ...
                    "Type", "left" ...
                );

                tmpHist = strcat(relatedTable.("DESCR_HIST"), {' ↳ '}, relatedTable.("HIST"));
                
                indexEqualHist = cellfun(@isempty, relatedTable.("DESCR_HIST")) | strcmp(relatedTable.("DESCR_HIST"), relatedTable.("HIST"));
                if any(indexEqualHist)
                    tmpHist(indexEqualHist) = relatedTable.("HIST")(indexEqualHist);
                end

                hist = unique(tmpHist, 'stable');
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
                    obj.Table.x_BALANCETE_GERAL = createTrialBalanceTable(obj, generalSettings);

                case '_BALANCETE_RESULTADO'
                    if ~isfield(obj.Table, 'x_BALANCETE_GERAL')
                        parseTable(obj, '_BALANCETE_GERAL', generalSettings)
                    end
                    obj.Table.x_BALANCETE_RESULTADO = filterTrialBalanceByAccountType(obj, '04');

                case '_CONTAS_ANOTACAO'
                    if ~isfield(obj.Table, 'x_BALANCETE_RESULTADO')
                        parseTable(obj, '_BALANCETE_RESULTADO', generalSettings)
                    end

                    if ~isfield(obj.Table, '_TABELA_APURACAO')
                        parseTable(obj, '_TABELA_APURACAO', generalSettings)
                    end

                    update(obj, 'Table.x_CONTAS_ANOTACAO', 'startup', generalSettings)

                case '_CONTAS_DESCRICAO'        
                    % Esse reordenamento é essencial quando se trata de registros
                    % mesclados, tendo em vista que os planos de contas estão
                    % replicados. Ao reordenar, registra-se o última estado de
                    % cada conta.
                    xI050 = flip(obj.Table.xI050(:, {'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}));

                    [accountIds, accountIdxs] = unique(xI050.("COD_CTA"), "sorted");
                    numAccounts = numel(accountIds);

                    % Prealoca, viabilizando operação em modo paralelo...
                    x_CONTAS_DESCRICAO = model.ECDBase.initializeCustomTable('_CONTAS_DESCRICAO', numAccounts);

                    parpoolCheck()
                    parfor ii = 1:numAccounts
                        accountId = accountIds{ii};
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

                case '_TABELA_APURACAO'
                    update(obj, 'Table.x_TABELA_APURACAO', 'startup')

                case {'C050_C051_C052', 'I050_I051_I052', 'I200_I250'}
                    switch tableId
                        case 'C050_C051_C052'
                            obj.Table.xC050_C051_C052 = mergeTables(obj, 'C050', {'C051', 'C052'}, generalSettings);
                        
                        case 'I050_I051_I052'
                            obj.Table.xI050_I051_I052 = mergeTables(obj, 'I050', {'I051', 'I052'}, generalSettings);

                        case 'I200_I250'
                            MIN_ROW_COUNT = generalSettings.FILE.largeTable.minRowCount; % 100000
                            expectedRows = expectedRowsByTableId(obj, 'I250');

                            mainTableColumns = {}; 
                            secondaryTableColumns = {};

                            if ~isempty(expectedRows) && expectedRows > MIN_ROW_COUNT
                                if isfield(generalSettings.FILE.largeTable.cacheColumns, 'I200')
                                    mainTableColumns = generalSettings.FILE.largeTable.cacheColumns.('I200');
                                end

                                if isfield(generalSettings.FILE.largeTable.cacheColumns, 'I250')
                                    secondaryTableColumns = generalSettings.FILE.largeTable.cacheColumns.('I250');
                                end
                            end

                            obj.Table.xI200_I250 = mergeTables(obj, 'I200', {'I250'}, generalSettings, mainTableColumns, secondaryTableColumns);
                    end

                    if ~generalSettings.FILE.largeTable.cacheEnabled
                        tablesToDeleteFromCache = setdiff(strsplit(tableId, '_'), generalSettings.ECD.cacheTables);
                        update(obj, 'Table.NonEssentialFiles', 'onCacheCleanup', tablesToDeleteFromCache)
                    end

                case {'J800', 'J801'}
                    ordinaryId   = true;
                    regexMatches = extractBetween(obj.Content, ['|' tableId '|'], ['|' tableId 'FIM|'], 'Boundaries', 'inclusive');

                otherwise
                    ordinaryId   = true;
                    regexPattern = ['^\|' tableId '\|.*'];
                    regexMatches = regexp(obj.Content, regexPattern, 'match', 'lineanchors', 'dotexceptnewline')';
                    regexMatches = strrep(regexMatches, sprintf('\r'), '');
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

            % if generalSettings.ui.accountDescriptionScope
            %     variableNames = obj.Table.(['x' tableId]).Properties.VariableNames;
            %     if ismember('COD_CTA', variableNames) && ~ismember('CTA', variableNames)
            %         obj.Table.(['x' tableId]) = addAccountDescription(obj, obj.Table.(['x' tableId]), variableNames, 'CTA');
            %     end
            % end
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

            MIN_ROW_COUNT = generalSettings.FILE.largeTable.minRowCount; % 100000
            expectedRows  = expectedRowsByTableId(obj, columnsSpec.id);

            if ~isempty(expectedRows) && expectedRows > MIN_ROW_COUNT
                if isfield(generalSettings.FILE.largeTable.cacheColumns, columnsSpec.id)
                    variableNames = generalSettings.FILE.largeTable.cacheColumns.(columnsSpec.id);
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
                    tableOut(tableStartIndex:tableEndIndex, :) = tableTempOut(:, variableNames);
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
        function mergedTable = mergeTables(obj, mainId, secundaryIds, generalSettings, mainTableColumns, secundaryTableColumns)
            arguments
                obj
                mainId          (1,:) char {mustBeMember(mainId, {'I050', 'I200', 'C050'})}
                secundaryIds    (1,:) cell % {'I051', 'I052'} | {'I250'} | {'C051', 'C052'}
                generalSettings
                mainTableColumns      cell = {}
                secundaryTableColumns cell = {}
            end

            checkIfScalar(obj)

            % Verifica se os registros ordinários foram lidos.
            tableIdList = [mainId, secundaryIds];
            
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
            % registros sob análise - "mainId" e "secundaryIds".
            splitContent = splitlines(obj.Content);
            fileIndexes  = cellfun(@(x) find(startsWith(splitContent, x)), strcat('|', tableIdList, '|'), 'UniformOutput', false);

            mainTableHeight = height(mainTable);
            mainTable.("_TEMP_KEY") = (1:mainTableHeight)';
            
            % Em relação às tabelas auxiliares:            
            edges = [fileIndexes{1}; inf];
            tempIdColumn = {};            
            for ii = 1:numel(secundaryIds)
                tempIdColumn{ii} = discretize(fileIndexes{ii+1}, edges);
            end
            secundaryTables = cellfun(@(x,y) addvars(x, y, 'NewVariableName', '_TEMP_KEY'), cellfun(@(x) obj.Table.(['x' x]), secundaryIds, "UniformOutput", false), tempIdColumn, 'UniformOutput', false);

            if isscalar(secundaryTables)
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

            % Abrindo caminho p/ diminuir informação resultado da mesclagem
            % de tabelas, deixando apenas o essencial.
            if isempty(mainTableColumns)
                mainTableColumns = mainTable.Properties.VariableNames;
            end

            if isempty(secundaryTableColumns)
                secundaryTableColumns = setdiff(secundaryTable.Properties.VariableNames, mainTable.Properties.VariableNames);
            end

            mergedTable = outerjoin( ...
                mainTable, ...
                secundaryTable, ...
                'Keys', '_TEMP_KEY', ...
                'MergeKeys', true, ...
                'Type', 'left', ...
                'LeftVariables', mainTableColumns, ...
                'RightVariables', setdiff(secundaryTableColumns, mainTableColumns) ...
            );
            
            if ismember('_TEMP_KEY', mergedTable.Properties.VariableNames)
                mergedTable = removevars(mergedTable, '_TEMP_KEY');
            end
            mergedTable.("REG")(:) = {strjoin(tableIdList, '_')};
        end

        %-----------------------------------------------------------------%
        function trialBalance = createTrialBalanceTable(obj, generalSettings)
            checkIfScalar(obj)
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
            trialBalance = model.ECDBase.initializeCustomTable('_BALANCETE_GERAL', numAccounts);

           %parpoolCheck()
           %parfor ii = 1:numAccounts
            for ii = 1:numAccounts
                accountId      = accountUniqueIdList{ii};
                accountIndexes = strcmp(mergedTable_I200_I250.("COD_CTA"), accountId);
                accountTable   = mergedTable_I200_I250(accountIndexes, :);
                
                % Sumariza-se mensalmente os fatos contábeis para cada conta.
                accountBalanceByMonth = zeros(1, 12);
                for jj = 1:12
                    monthIndexes = month(accountTable.("DT_LCTO")) == jj;
                    accountBalanceByMonth(jj) = sum(accountTable.("VL_DC_COM_SINAL")(monthIndexes));
                end

                trialBalance(ii, :) = [{'', accountId}, num2cell([accountBalanceByMonth, sum(accountBalanceByMonth)])];
            end

            % Valida-se se o valor total de transações entre as contas por 
            % mês é igual a zero.
            FLOAT_DIFF_TOLERANCE = 1e-5;
            if any(cellfun(@(x) sum(trialBalance.(x)) > FLOAT_DIFF_TOLERANCE, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}))
                obj.GUI.warnings{end+1} = jsonencode(struct('id', 'mBALANCETE_GERAL', 'message', 'Ao menos um dos meses apresentou um balanço diferente de zero, o que evidencia erro no arquivo contábil ou na análise dos seus dados.'));
            end
            
            trialBalance = addAccountDescription(obj, trialBalance, setdiff(trialBalance.Properties.VariableNames, 'COD_NAT', 'stable'), 'COD_NAT');
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

            expectedI200Rows = expectedRowsByTableId(obj, 'I200');
            hasTransactions = false;

            if ~isempty(expectedI200Rows) && expectedI200Rows > 0 && isfield(obj.Table, 'xI050') && any(strcmp(obj.Table.xI050.('COD_NAT'), '04'))
                hasTransactions = true;
            end
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

end