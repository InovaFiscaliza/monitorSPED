classdef (Abstract) Table

    methods (Static)
        %-----------------------------------------------------------------%
        % TABELAS GERAIS
        %-----------------------------------------------------------------%
        function Table = FileByCompany(reportInfo)
            ecdObj = reportInfo.Object;
            Table  = table('Size',          [0, 7],                                                       ...
                           'VariableTypes', {'double', 'cell', 'cell', 'cell', 'cell', 'double', 'cell'}, ...
                           'VariableNames', {'#', 'CNPJ', 'NIRE', 'Razão Social', 'UF', 'Número de arquivos', 'Período contábil • Arquivo'});

            idsList = {ecdObj.CompanyId};
            ids = unique(idsList);
            
            for ii = 1:numel(ids)
                % Identifica fluxos relacionados a cada CNPJ, ordenando os 
                % fluxos de acordo com a data de fim do seu período fiscal.
                idIndexes   = find(strcmp(idsList, ids{ii}));
                [~, idSort] = sort(arrayfun(@(x) x.Period(2), ecdObj(idIndexes)));
                idIndexes   = idIndexes(idSort);

                nireInfo    = ecdObj(idIndexes(1)).CompanyInfo.NIRE;
                if isempty(nireInfo)
                    nireInfo = '-';
                end


                Table(end+1,:) = {...
                    ii, ...
                    ecdObj(idIndexes(1)).CompanyId, ...
                    nireInfo, ...                                        
                    ecdObj(idIndexes(1)).CompanyName, ...
                    strjoin(unique({ecdObj(idIndexes).State}), '<br>'), ...
                    numel(ecdObj(idIndexes)), ...
                    strjoin(strcat(arrayfun(@(x) sprintf('%s a %s', x.Period(:)), ecdObj(idIndexes), 'UniformOutput', false), '&emsp;&#x2022;&emsp;', {ecdObj(idIndexes).FileName}), '<br>') ...
                };                    
            end
        end

        %-----------------------------------------------------------------%
        function Table = SourceFileStatus(analyzedData)
            ecdObj = analyzedData.InfoSet.ecdObj;
            ecdIdx = analyzedData.Index;
            Table  = table('Size',          [0, 7],                                                   ...
                           'VariableTypes', {'cell', 'cell', 'cell', 'cell', 'cell', 'cell', 'cell'}, ...
                           'VariableNames', {'#', 'Período contábil', 'Arquivo', 'Codificação', 'Hash', 'Resposta webservice', 'Situação'});
        
            kk = 0;
            for ii = 1:numel(ecdObj)
                kk = kk+1;
                numFileSources = numel(ecdObj(ii).Sources);

                for jj = 1:numFileSources
                    zz = '';
                    if numFileSources > 1
                        zz = sprintf('.%d', jj);
                    end

                    id = util.HtmlTextGenerator.generateTextId(ecdObj(ii), 'scalar-period-oriented', jj, 'html');

                    validationMessage = ecdObj(ii).Sources(jj).validationMessage;
                    if all(cellfun(@(x) isfield(validationMessage, x), {'xmlns', 'versao', 'nire', 'hashEsc'}))
                        validationMessage = rmfield(validationMessage, {'xmlns', 'versao', 'nire', 'hashEsc'});
                    end

                    Table(end+1,:) = { ...
                        sprintf('%d.%d%s', ecdIdx, kk, zz), ...
                        sprintf('%s a %s', ecdObj(ii).Sources(jj).period(:)), ...
                        ecdObj(ii).Sources(jj).file, ...
                        ecdObj(ii).Sources(jj).encoding, ...
                        ecdObj(ii).Sources(jj).hash, ...
                        jsonencode(validationMessage), ...
                        id ...
                    };
                end
            end
        end

        %-----------------------------------------------------------------%
        function Table = FileMetadata(analyzedData)
            ecdObj = analyzedData.InfoSet.ecdObj;
            ecdIdx = analyzedData.Index;
            Table  = table('Size',          [0, 5],                                     ...
                           'VariableTypes', {'cell', 'cell', 'cell', 'double', 'cell'}, ...
                           'VariableNames', {'#', 'Arquivo', 'Registros', 'Qtd. arquivos anexos (J800 e J801)', 'LOG'});

            for ii = 1:numel(ecdObj)
                sheetsInfo = '';
                rtfFiles = 0;
                if isfield(ecdObj(ii).Table, 'x9900')
                    sheetsRaw  = ecdObj(ii).Table.x9900;
                    sheetsRaw(sheetsRaw.("QTD_REG_BLC") <= 0, :) = [];
                    sheetsInfo = strjoin(strcat('"', sheetsRaw.("REG_BLC"), '": ', cellstr(string(sheetsRaw.("QTD_REG_BLC")))), ', ');

                    rtfIndexes = find(contains(ecdObj(ii).Table.x9900.REG_BLC, {'J800', 'J801'}));
                    if ~isempty(rtfIndexes)
                        rtfFiles = sum(ecdObj(ii).Table.x9900.("QTD_REG_BLC")(rtfIndexes));
                    end
                end

                logMessage = '-';
                if ~isempty(ecdObj(ii).GUI.warnings)
                    logMessage = strjoin(ecdObj(ii).GUI.warnings, '<br>');
                end

                Table(end+1,:) = { ...
                    sprintf('%d.%d%s', ecdIdx, ii), ...
                    ecdObj(ii).FileName, ...
                    sheetsInfo, ...
                    rtfFiles, ...
                    logMessage ...
                };
            end
        end

        %-----------------------------------------------------------------%
        % TABELAS POR CNPJ
        %-----------------------------------------------------------------%
        function Table = Raw(reportInfo, analyzedData, tableSettings)
            ecdObj = analyzedData.InfoSet.ecdObj;
            generalSettings = reportInfo.Settings;

            parsedSource = strsplit(tableSettings.Source, '+');
            tableSource  = parsedSource{1};
            tableId      = parsedSource{2};

            checkIfScalar(ecdObj)

            isTableRead(ecdObj, {tableId}, generalSettings);
            Table = ecdObj.Table.(['x' tableId]);
        end

        %-----------------------------------------------------------------%
        function [Table, rawTable] = TabelaApuracao(analyzedData, tableType)
            arguments
                analyzedData
                tableType char {mustBeMember(tableType, {'APURAÇÃO GERAL COMPLETA', ...
                                                         'APURAÇÃO GERAL RESUMIDA', ...
                                                         'APURAÇÃO SOMENTE INTERCONEXÃO', ...
                                                         'APURAÇÃO EXCLUINDO INTERCONEXÃO'})}
            end

            ecdObj = analyzedData.InfoSet.ecdObj;
            checkIfScalar(ecdObj)

            switch tableType
                case 'APURAÇÃO GERAL COMPLETA'
                    rawTable = ecdObj.Table.('x_APURACAO_GERAL');
                    rawTable = ensureRowNames(rawTable, 'TIPO');
                    rawTable.Properties.RowNames = replace(rawTable.Properties.RowNames, 'ROB TELECOM', 'ROB TELECOM (GERAL)');

                    numericVariables = getNumericVariables(rawTable);
                    rawTable = formatBrazilianCurrency(rawTable, numericVariables);
                    
                    Table = [table(rawTable.Properties.RowNames, 'VariableName', {'TIPO'}), rawTable];

                case 'APURAÇÃO GERAL RESUMIDA'
                    rawTable = ecdObj.Table.('x_APURACAO_GERAL');
                    rawTable = ensureRowNames(rawTable, 'TIPO');

                    icmsEscolhido   = 'ICMS CONTÁBIL';
                    pisEscolhido    = 'PIS CONTÁBIL';
                    cofinsEscolhido = 'COFINS CONTÁBIL';

                    if abs(rawTable{"ICMS ESTIMADO",   "TOTAL"}) < abs(rawTable{"ICMS CONTÁBIL",   "TOTAL"})
                        icmsEscolhido = 'ICMS ESTIMADO';
                    end

                    if abs(rawTable{"PIS ESTIMADO",    "TOTAL"}) < abs(rawTable{"PIS CONTÁBIL",    "TOTAL"})
                        pisEscolhido = 'PIS ESTIMADO';
                    end

                    if abs(rawTable{"COFINS ESTIMADO", "TOTAL"}) < abs(rawTable{"COFINS CONTÁBIL", "TOTAL"})
                        cofinsEscolhido = 'COFINS ESTIMADO';
                    end

                    rawTable(setdiff(rawTable.Properties.RowNames, {'ROB TELECOM', icmsEscolhido, pisEscolhido, cofinsEscolhido, 'VALOR APURADO FUST', 'VALOR APURADO FUNTTEL'}), :) = [];
                    rawTable.Properties.RowNames = replace(rawTable.Properties.RowNames, {icmsEscolhido, pisEscolhido, cofinsEscolhido}, {'ICMS', 'PIS', 'COFINS'});
                    rawTable = cell2table(table2cell(rawTable)', 'VariableNames', rawTable.Properties.RowNames, 'RowNames', rawTable.Properties.VariableNames);
                    rawTable = multiplyByMinusOne(rawTable, {'ICMS', 'PIS', 'COFINS', 'VALOR APURADO FUST', 'VALOR APURADO FUNTTEL'});

                    numericVariables = getNumericVariables(rawTable);
                    rawTable = formatBrazilianCurrency(rawTable, numericVariables);
                    
                    Table = [table(rawTable.Properties.RowNames, 'VariableName', {'MÊS'}), rawTable];


                case 'APURAÇÃO SOMENTE INTERCONEXÃO'
                    if ~any(ecdObj.Table.x_CONTAS_ANOTACAO.('Apurado?  ✎') == "Sim" & ismember(ecdObj.Table.x_CONTAS_ANOTACAO.('Interconexão?  ✎'), ["ITX", "EILD"]))
                        error('reportLibConnection:Table:EmptyInterconnectionTable', 'Empty interconnection table')
                    end

                    rawTable = ecdObj.Table.('x_APURACAO_INTERCONEXAO');
                    rawTable = ensureRowNames(rawTable, 'TIPO');

                    rawTable(contains(rawTable.Properties.RowNames, 'BÁSE DE CÁLCULO'), :) = [];
                    rawTable.Properties.RowNames = replace(rawTable.Properties.RowNames, {'ICMS ESTIMADO', 'PIS ESTIMADO', 'COFINS ESTIMADO'}, {'ICMS', 'PIS', 'COFINS'});
                    rawTable = cell2table(table2cell(rawTable)', 'VariableNames', rawTable.Properties.RowNames, 'RowNames', rawTable.Properties.VariableNames);
                    rawTable = multiplyByMinusOne(rawTable, {'ICMS', 'PIS', 'COFINS', 'VALOR APURADO FUST', 'VALOR APURADO FUNTTEL'});

                    numericVariables = getNumericVariables(rawTable);
                    rawTable = formatBrazilianCurrency(rawTable, numericVariables);
                    
                    Table = [table(rawTable.Properties.RowNames, 'VariableName', {'MÊS'}), rawTable];

                case 'APURAÇÃO EXCLUINDO INTERCONEXÃO'
                    [~, rawTableGeral] = reportLibConnection.Table.TabelaApuracao(analyzedData, 'APURAÇÃO GERAL RESUMIDA');
                    [~, rawTableItx]   = reportLibConnection.Table.TabelaApuracao(analyzedData, 'APURAÇÃO SOMENTE INTERCONEXÃO');
                    
                    rawTableGeral = ensureRowNames(rawTableGeral, 'TIPO');
                    rawTableItx = ensureRowNames(rawTableItx, 'TIPO');

                    commonVariables = intersect(rawTableGeral.Properties.VariableNames, rawTableItx.Properties.VariableNames);
                    rawTable = rawTableGeral(:, commonVariables) - rawTableItx(:, commonVariables);

                    numericVariables = getNumericVariables(rawTable);
                    rawTable = formatBrazilianCurrency(rawTable, numericVariables);

                    Table = [table(rawTable.Properties.RowNames, 'VariableName', {'MÊS'}), rawTable];
            end

            function tbl = ensureRowNames(tbl, rowNameVariable)
                if isempty(tbl.Properties.RowNames) && ismember(rowNameVariable, tbl.Properties.VariableNames)
                    tbl.Properties.RowNames = tbl.(rowNameVariable);
                    tbl = removevars(tbl, rowNameVariable);
                end
            end

            function tbl = multiplyByMinusOne(tbl, variableNames)
                tbl(:, variableNames) = tbl(:, variableNames) .* -1;
            end

            function numericVariables = getNumericVariables(tbl)
                numericVariableIdxs = find(strcmp(matlab.Compatibility.resolveTableVariableTypes(tbl), 'double'));
                numericVariables = tbl.Properties.VariableNames(numericVariableIdxs);
            end

            function tbl = formatBrazilianCurrency(tbl, variableNames)
                variableNames = string(variableNames);

                for variableName = variableNames
                    values = arrayfun(@(x) util.formatBrazilianCurrency(x), tbl.(variableName), 'UniformOutput', false);
                    tbl.(variableName) = values;
                end
            end
        end

        %-----------------------------------------------------------------%
        function Table = TabelaAnotacao(analyzedData, status)
            arguments
                analyzedData
                status {mustBeMember(status, {'all', 'on', 'on/off'})}
            end

            ecdObj = analyzedData.InfoSet.ecdObj;
            checkIfScalar(ecdObj)

            rawTable = ecdObj.Table.x_CONTAS_ANOTACAO;
            switch status
                case 'on'
                    rawTable = rawTable(~ismember(rawTable.('Apurado?  ✎'), ["-", "Não"]), :);
                case 'on/off'
                    rawTable = rawTable(~ismember(rawTable.('Apurado?  ✎'), ["-"]), :);
            end

            Table = innerjoin(rawTable, ecdObj.Table.x_BALANCETE_RESULTADO, 'Keys', 'COD_CTA', 'RightVariables', {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'});

            % Eliminando caracteres especiais não renderizados no editor de
            % texto do SEI.
            Table.('DESCRIÇÃO') = replace(Table.('DESCRIÇÃO'), '↳', '&#x21B3;');
        end


        %-----------------------------------------------------------------%
        % TABELAS PARA SHAREPOINT (SCARAB)
        %-----------------------------------------------------------------%
        function jsonFileContent = scarabJsonFile(projectData, context, ecdObj, correlationKey, executionMode, issueDetails)
            if isscalar(ecdObj)
                [entityId, status] = checkCNPJOrCPF(ecdObj(1).CompanyId, 'NumberValidation');

                projectData.modules.(context).ui.entity.name   = ecdObj(1).CompanyName;
                projectData.modules.(context).ui.entity.id     = entityId;
                projectData.modules.(context).ui.entity.status = status;
            end

            entityGroupName = projectData.modules.(context).ui.entity.name;
            entityGroupId = projectData.modules.(context).ui.entity.id;
            
            jsonFileContent = struct( ...
                'schemaVersion', 4, ...
                'createdAt', datestr(now, 'yyyy-mm-ddTHH:MM:SS'), ...
                'clientName', class.Constants.appName, ...
                'clientVersion', class.Constants.appVersion, ...
                'clientExecutionMode', executionMode, ...
                'auditorName', issueDetails.usuario.nome, ...
                'auditorEmail', issueDetails.usuario.email, ...
                'auditorDepartment', issueDetails.usuario.unidade, ...
                'auditorJobTitle', issueDetails.usuario.funcao, ...
                'project', struct( ...
                    'correlationKey', correlationKey, ...
                    'system', projectData.modules.(context).ui.system, ...
                    'unit', projectData.modules.(context).ui.unit, ...
                    'issue', projectData.modules.(context).ui.issue, ...
                    'subTheme', issueDetails.issueContext.solicitacao.classificacao.subtema, ...
                    'sei', issueDetails.issueContext.acao.sei.processo, ...
                    'seiReport', '', ...
                    'context', context, ...
                    'entityGroupName', entityGroupName, ...
                    'entityGroupId', entityGroupId ...
                ), ...
                'taxEstimateSummary', [], ...
                'files', [], ...
                'accounts', [] ...
            );

            taxEstimateSummary = struct('correlationKey', {}, 'entityName', {}, 'entityId', {}, 'entityState', {}, 'periodStart', {}, 'periodEnd', {}, 'robTelecom', {}, 'icmsEstimado', {}, 'icmsContabil', {}, 'baseCalculoPisCofins', {}, 'pisEstimado', {}, 'pisContabil', {}, 'cofinsEstimado', {}, 'cofinsContabil', {}, 'baseCalculoFustFunttel', {}, 'valorApuradoFust', {}, 'valorApuradoFunttel', {});
            files = struct('correlationKey', {}, 'entityName', {}, 'entityId', {}, 'entityState', {}, 'fileName', {}, 'fileHash', {}, 'fileEncoding', {}, 'fileSentAt', {}, 'periodStart', {}, 'periodEnd', {}, 'validationCheckedAt', {}, 'validationStatus', {}, 'validationMessage', {});
            accounts = [];

            for ii = 1:numel(ecdObj)
                entityName = ecdObj(ii).CompanyName;
                entityId = ecdObj(ii).CompanyId;
                entityState = ecdObj(ii).State;

                % TAXESTIMATESUMMARY
                taxEstimateSummary(end+1) = struct( ...
                    'correlationKey',         correlationKey, ...
                    'entityName',             entityName, ...
                    'entityId',               entityId, ...
                    'entityState',            entityState, ...
                    'periodStart',            datestr(ecdObj(ii).Period(1), 'yyyymmdd'), ...
                    'periodEnd',              datestr(ecdObj(ii).Period(2), 'yyyymmdd'), ...
                    'robTelecom',             round(ecdObj(ii).Table.x_APURACAO_GERAL{ 1, 'TOTAL'}, 2), ...
                    'icmsEstimado',           round(ecdObj(ii).Table.x_APURACAO_GERAL{ 2, 'TOTAL'}, 2), ...
                    'icmsContabil',           round(ecdObj(ii).Table.x_APURACAO_GERAL{ 3, 'TOTAL'}, 2), ...
                    'baseCalculoPisCofins',   round(ecdObj(ii).Table.x_APURACAO_GERAL{ 4, 'TOTAL'}, 2), ...
                    'pisEstimado',            round(ecdObj(ii).Table.x_APURACAO_GERAL{ 5, 'TOTAL'}, 2), ...
                    'pisContabil',            round(ecdObj(ii).Table.x_APURACAO_GERAL{ 6, 'TOTAL'}, 2), ...
                    'cofinsEstimado',         round(ecdObj(ii).Table.x_APURACAO_GERAL{ 7, 'TOTAL'}, 2), ...
                    'cofinsContabil',         round(ecdObj(ii).Table.x_APURACAO_GERAL{ 8, 'TOTAL'}, 2), ...
                    'baseCalculoFustFunttel', round(ecdObj(ii).Table.x_APURACAO_GERAL{ 9, 'TOTAL'}, 2), ...
                    'valorApuradoFust',       round(ecdObj(ii).Table.x_APURACAO_GERAL{10, 'TOTAL'}, 2), ...
                    'valorApuradoFunttel',    round(ecdObj(ii).Table.x_APURACAO_GERAL{11, 'TOTAL'}, 2) ...
                );

                % FILES
                for jj = 1:numel(ecdObj(ii).Sources)
                    fileSentAt = '';
                    validationCheckedAt = '';
                    validationStatus = '';
                    validationMessage = '';

                    if ~isempty(ecdObj(ii).Sources(jj).validationMessage) && isstruct(ecdObj(ii).Sources(jj).validationMessage)
                        if isfield(ecdObj(ii).Sources(jj).validationMessage, 'dtEnvio')
                            fileSentAt = ecdObj(ii).Sources(jj).validationMessage.('dtEnvio');
                        end

                        if isfield(ecdObj(ii).Sources(jj).validationMessage, 'dtCons')
                            validationCheckedAt = ecdObj(ii).Sources(jj).validationMessage.('dtCons');
                        end

                        if isfield(ecdObj(ii).Sources(jj).validationMessage, 'situacao')
                            validationStatus = ecdObj(ii).Sources(jj).validationMessage.('situacao');
                        end

                        if isfield(ecdObj(ii).Sources(jj).validationMessage, 'retVerif')
                            validationMessage = ecdObj(ii).Sources(jj).validationMessage.('retVerif');
                        end
                    end

                    files(end+1) = struct( ...
                        'correlationKey',      correlationKey, ...
                        'entityName',          entityName, ...
                        'entityId',            entityId, ...
                        'entityState',         entityState, ...
                        'fileName',            ecdObj(ii).Sources(jj).file, ...
                        'fileEncoding',        ecdObj(ii).Sources(jj).encoding, ...
                        'fileHash',            ecdObj(ii).Sources(jj).hash, ...
                        'fileSentAt',          fileSentAt, ...
                        'periodStart',         datestr(ecdObj(ii).Sources(jj).period(1), 'yyyymmdd'), ...
                        'periodEnd',           datestr(ecdObj(ii).Sources(jj).period(2), 'yyyymmdd'), ...
                        'validationCheckedAt', validationCheckedAt, ...
                        'validationStatus',    validationStatus, ...
                        'validationMessage',   validationMessage ...
                    );
                end

                % ACCOUNTS
                tempAccounts = ecdObj(ii).Table.x_CONTAS_ANOTACAO;
                if isfield(ecdObj(ii).Table, 'x_CONTAS_HISTORICO') && ~isempty(ecdObj(ii).Table.x_CONTAS_HISTORICO)
                    tempAccounts = join( ...
                        tempAccounts, ...
                        ecdObj(ii).Table.x_CONTAS_HISTORICO, ...
                        'Keys', 'COD_CTA', ...
                        'RightVariables', {'TOTAL DE LANÇAMENTOS', 'LANÇAMENTOS NORMALIZADOS DEDUPLICADOS'} ...
                    );
                    tempAccounts.('LANÇAMENTOS NORMALIZADOS DEDUPLICADOS') = cellfun(@(x) jsonencode(x), tempAccounts.('LANÇAMENTOS NORMALIZADOS DEDUPLICADOS'), 'UniformOutput', false);

                else
                    tempAccounts.('TOTAL DE LANÇAMENTOS')(:) = 0;
                    tempAccounts.('LANÇAMENTOS NORMALIZADOS DEDUPLICADOS')(:) = {'[]'};
                end

                tempAccounts = join( ...
                    tempAccounts, ...
                    ecdObj(ii).Table.x_BALANCETE_RESULTADO, ...
                    'Keys', 'COD_CTA', ...
                    'LeftVariables', tempAccounts.Properties.VariableNames, ...
                    'RightVariables', {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'} ...
                );

                % Arredondamento essencial para que no conteúdo do JSON não
                % apareça algo como "-87842.099999999991". 
                tempAccounts(:, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}) = round(tempAccounts(:, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}), 2);

                tempAccounts.('correlationKey')(:) = {correlationKey};
                tempAccounts.('entityName')(:)     = {entityName};
                tempAccounts.('entityId')(:)       = {entityId};
                tempAccounts.('entityState')(:)    = {entityState};
                tempAccounts.('periodYear')(:)     = year(ecdObj(ii).Sources(jj).period(1));

                tempAccounts = renamevars( ...
                    tempAccounts, ...
                    {'COD_CTA', 'DESCRIÇÃO', 'Declarado?  ✎', 'Apurado?  ✎', 'Alíquota ICMS', 'Observação  ✎', 'TOTAL DE LANÇAMENTOS', 'LANÇAMENTOS NORMALIZADOS DEDUPLICADOS', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                    {'accountCode', 'description', 'entitySelfDeclaration', 'auditorAccountType', 'auditorIcmsConfig', 'auditorComment', 'entryHistoryCount', 'deduplicatedEntryHistory', 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec', 'total'} ...
                );
                accounts = [accounts; tempAccounts];
            end
            accounts = accounts(:, {'correlationKey', 'entityName', 'entityId', 'entityState', 'accountCode', 'description', 'entryHistoryCount', 'deduplicatedEntryHistory', 'periodYear', 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec', 'total', 'entitySelfDeclaration', 'auditorAccountType', 'auditorIcmsConfig', 'auditorComment'});

            % Força que a saída seja uma lista de objetos...
            if numel(taxEstimateSummary) <= 1
                taxEstimateSummary = {taxEstimateSummary};
            end

            if numel(files) <= 1
                files = {files};
            end

            if height(accounts) <= 1
                accounts = {accounts};
            end

            jsonFileContent.taxEstimateSummary = taxEstimateSummary;
            jsonFileContent.files = files;
            jsonFileContent.accounts = accounts;

            jsonFileContent = jsonencode(jsonFileContent, 'PrettyPrint', true);
        end

        %-----------------------------------------------------------------%
        function teamsFileContent = scarabTeamsFileContent(issueDetails, JSONBaseName)
            teamsFileContent = struct( ...
                'schemaVersion', 1, ...
                'clientName', class.Constants.appName, ...
                'auditorName', issueDetails.usuario.nome, ...
                'auditorEmail', issueDetails.usuario.email, ...
                'fileNameList', {{[JSONBaseName '.json']}} ...
            );

            teamsFileContent = jsonencode(teamsFileContent, 'PrettyPrint', true);
        end
    end
end