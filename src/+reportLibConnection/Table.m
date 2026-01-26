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
        function jsonFileContent = scarabJsonFile(projectData, context, ecdObj)
            jsonFileInfo = struct( ...
                'Project', {}, ...
                'CompanyInfo', {}, ...
                'Period', {}, ...
                'Sources', {}, ...
                'Accounts', {}, ...
                'TrialBalance', {}, ...
                'TaxEstimateSummary', {} ...
            );

            for ii = 1:numel(ecdObj)
                x_CONTAS_ANOTACAO     = ecdObj(ii).Table.x_CONTAS_ANOTACAO;
                x_BALANCETE_RESULTADO = ecdObj(ii).Table.x_BALANCETE_RESULTADO;
                x_TABELA_APURACAO     = ecdObj(ii).Table.x_TABELA_APURACAO;

                % Ajustes nos nomes das colunas, eliminando caracteres especiais 
                % não renderizados no editor de texto do SEI, além de nomes
                % iniciados por números (como "Observação  ✎" e "01"). Além 
                % disso, inclusão da coluna "DESCRIÇÃO".
                variableNames = x_CONTAS_ANOTACAO.Properties.VariableNames;
                variableToAdd = 'DESCRIÇÃO';
                if ismember('COD_CTA', variableNames) && ~ismember(variableToAdd, variableNames)
                    x_CONTAS_ANOTACAO = addAccountDescription(ecdObj(ii), x_CONTAS_ANOTACAO, variableNames, variableToAdd, 'x_CONTAS_DESCRICAO');
                end
                x_CONTAS_ANOTACAO     = renamevars(x_CONTAS_ANOTACAO,     {'Apurado?  ✎', 'Alíquota ICMS', 'Observação  ✎', 'DESCRIÇÃO'}, {'APURADO', 'ICMS', 'OBSERVACAO', 'DESCRICAO'});

                % Renomeia-se as colunas que denotam meses, além de adiciona-se
                % nomes das linhas como coluna "TIPO" (no caso da tabela 
                % "_TABELA_APURACAO").
                x_BALANCETE_RESULTADO = renamevars(x_BALANCETE_RESULTADO, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}, {'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'});
                x_TABELA_APURACAO     = renamevars(x_TABELA_APURACAO,     {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}, {'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'});
                x_TABELA_APURACAO     = [table(x_TABELA_APURACAO.Properties.RowNames, 'VariableName', {'TIPO'}), x_TABELA_APURACAO];
                x_TABELA_APURACAO.Properties.RowNames = {};

                jsonFileInfo(end+1) = struct( ...
                    'Project', rmfield(projectData.modules.(context).ui, {'templates', 'reportVersion'}), ...
                    'CompanyInfo', ecdObj(ii).CompanyInfo, ...
                    'Period', ecdObj(ii).Period, ...
                    'Sources', ecdObj(ii).Sources, ...
                    'Accounts', x_CONTAS_ANOTACAO, ...
                    'TrialBalance', x_BALANCETE_RESULTADO, ...
                    'TaxEstimateSummary', x_TABELA_APURACAO ...
                );
            end

            jsonFileContent = jsonencode(jsonFileInfo, 'PrettyPrint', true);
        end
    end
end