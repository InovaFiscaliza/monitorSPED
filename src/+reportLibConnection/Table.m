classdef (Abstract) Table

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
        function Table = TabelaApuracao(analyzedData)
            ecdObj = analyzedData.InfoSet.ecdObj;

            checkIfScalar(ecdObj)

            rawTable = ecdObj.Table.x_TABELA_APURACAO;
            Table = [table(rawTable.Properties.RowNames, 'VariableName', {'TIPO'}), rawTable];
        end

        %-----------------------------------------------------------------%
        function Table = TabelaAnotacao(analyzedData, status)
            arguments
                analyzedData
                status {mustBeMember(status, {'all', 'on'})}
            end

            ecdObj = analyzedData.InfoSet.ecdObj;

            checkIfScalar(ecdObj)

            rawTable = ecdObj.Table.x_CONTAS_ANOTACAO;
            if strcmp(status, 'on')
                rawTable = rawTable(~ismember(rawTable.('Apurado?  ✎'), ["-", "Não"]), :);
            end

            Table = innerjoin(rawTable, ecdObj.Table.x_BALANCETE_RESULTADO, 'Keys', 'COD_CTA', 'RightVariables', {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'});
            Table = innerjoin(Table,    ecdObj.Table.x_CONTAS_DESCRICAO,    'Keys', 'COD_CTA', 'RightVariables', 'DESCRIÇÃO');

            % Eliminando caracteres especiais não renderizados no editor de
            % texto do SEI.
            Table.('DESCRIÇÃO') = replace(Table.('DESCRIÇÃO'), '↳', '&#x21B3;');
        end


        %-----------------------------------------------------------------%
        % TABELAS PARA SHAREPOINT (SCARAB)
        %-----------------------------------------------------------------%
        function jsonFileContent = scarabJsonFile(projectData, context, ecdObj, eFiscalizaObj)
            correlationKey = char(matlab.lang.internal.uuid());

            userLogin = '';
            if ~isempty(eFiscalizaObj) && isvalid(eFiscalizaObj)
                userLogin = getLogin(eFiscalizaObj);
            end

            entityGroupName = projectData.modules.(context).ui.entity.name;
            entityGroupId = projectData.modules.(context).ui.entity.id;
            if isscalar(ecdObj)
                entityGroupName = ecdObj(1).CompanyName;
                entityGroupId = ecdObj(1).CompanyId;
            end

            jsonFileContent = struct( ...
                'schemaVersion', 1, ...
                'correlationKey', correlationKey, ...
                'project', struct( ...
                    'correlationKey', correlationKey, ...
                    'system', projectData.modules.(context).ui.system, ...
                    'issue', projectData.modules.(context).ui.issue, ...
                    'context', context, ...
                    'entityGroupName', entityGroupName, ...
                    'entityGroupId', entityGroupId, ...
                    'unit', projectData.modules.(context).ui.unit, ...
                    'auditor', userLogin ...
                ), ...
                'taxEstimateSummary', [], ...
                'files', [], ...
                'accounts', [] ...
            );

            taxEstimateSummary = struct('correlationKey', {}, 'entityName', {}, 'entityId', {}, 'periodStart', {}, 'periodEnd', {}, 'robTelecom', {}, 'icmsTelecom', {}, 'icmsContabil', {}, 'baseCalculoPisCofins', {}, 'pisTelecom', {}, 'pisContabil', {}, 'cofinsTelecom', {}, 'cofinsContabil', {}, 'baseCalculoFustFunttel', {}, 'valorApuradoFust', {}, 'valorApuradoFunttel', {});
            files = struct('correlationKey', {}, 'entityName', {}, 'entityId', {}, 'fileName', {}, 'fileHash', {}, 'fileEncoding', {}, 'fileSentAt', {}, 'periodStart', {}, 'periodEnd', {}, 'validationCheckedAt', {}, 'validationStatus', {}, 'validationMessage', {});
            accounts = [];

            for ii = 1:numel(ecdObj)
                entityName = ecdObj(ii).CompanyName;
                entityId = ecdObj(ii).CompanyId;

                % TAXESTIMATESUMMARY
                taxEstimateSummary(end+1) = struct( ...
                    'correlationKey',         correlationKey, ...
                    'entityName',             entityName, ...
                    'entityId',               entityId, ...
                    'periodStart',            datestr(ecdObj(ii).Period(1), 'yyyymmdd'), ...
                    'periodEnd',              datestr(ecdObj(ii).Period(2), 'yyyymmdd'), ...
                    'robTelecom',             ecdObj(ii).Table.x_TABELA_APURACAO{'ROB TELECOM', 'TOTAL'}, ...
                    'icmsTelecom',            ecdObj(ii).Table.x_TABELA_APURACAO{'ICMS TELECOM', 'TOTAL'}, ...
                    'icmsContabil',           ecdObj(ii).Table.x_TABELA_APURACAO{'ICMS CONTÁBIL', 'TOTAL'}, ...
                    'baseCalculoPisCofins',   ecdObj(ii).Table.x_TABELA_APURACAO{'BÁSE DE CÁLCULO (PIS/COFINS)', 'TOTAL'}, ...
                    'pisTelecom',             ecdObj(ii).Table.x_TABELA_APURACAO{'PIS TELECOM', 'TOTAL'}, ...
                    'pisContabil',            ecdObj(ii).Table.x_TABELA_APURACAO{'PIS CONTÁBIL', 'TOTAL'}, ...
                    'cofinsTelecom',          ecdObj(ii).Table.x_TABELA_APURACAO{'COFINS TELECOM', 'TOTAL'}, ...
                    'cofinsContabil',         ecdObj(ii).Table.x_TABELA_APURACAO{'COFINS CONTÁBIL', 'TOTAL'}, ...
                    'baseCalculoFustFunttel', ecdObj(ii).Table.x_TABELA_APURACAO{'BÁSE DE CÁLCULO (FUST/FUNTTEL)', 'TOTAL'}, ...
                    'valorApuradoFust',       ecdObj(ii).Table.x_TABELA_APURACAO{'VALOR APURADO FUST', 'TOTAL'}, ...
                    'valorApuradoFunttel',    ecdObj(ii).Table.x_TABELA_APURACAO{'VALOR APURADO FUNTTEL', 'TOTAL'} ...
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
                tempAccounts = join( ...
                    ecdObj(ii).Table.x_CONTAS_ANOTACAO, ...
                    ecdObj(ii).Table.x_CONTAS_DESCRICAO, ...
                    'Keys', 'COD_CTA', ...
                    'LeftVariables', ecdObj(ii).Table.x_CONTAS_ANOTACAO.Properties.VariableNames, ...
                    'RightVariables', 'DESCRIÇÃO' ...
                );

                tempAccounts = join( ...
                    tempAccounts, ...
                    ecdObj(ii).Table.x_BALANCETE_RESULTADO, ...
                    'Keys', 'COD_CTA', ...
                    'LeftVariables', tempAccounts.Properties.VariableNames, ...
                    'RightVariables', {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'} ...
                );

                tempAccounts.('correlationKey')(:) = {correlationKey};
                tempAccounts.('entityName')(:)     = {entityName};
                tempAccounts.('entityId')(:)       = {entityId};
                tempAccounts.('periodYear')(:)     = year(ecdObj(ii).Sources(jj).period(1));

                tempAccounts = renamevars( ...
                    tempAccounts, ...
                    {'COD_CTA', 'Apurado?  ✎', 'Alíquota ICMS', 'Observação  ✎', 'DESCRIÇÃO', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                    {'accountCode', 'auditorAccountType', 'auditorIcmsConfig', 'auditorComment', 'description', 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec', 'total'} ...
                );
                accounts = [accounts; tempAccounts];
            end
            accounts = accounts(:, {'correlationKey', 'entityName', 'entityId', 'accountCode', 'description', 'periodYear', 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec', 'total', 'auditorAccountType', 'auditorIcmsConfig', 'auditorComment'});

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
    end
end