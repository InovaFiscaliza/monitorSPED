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
                           'VariableNames', {'#', 'CNPJ', 'NIRE', 'Razão Social', 'UF', 'Número de arquivos', 'Período contábil – Arquivo'});

            idsList = {ecdObj.CompanyId};
            ids = unique(idsList);
            
            for ii = 1:numel(ids)
                % Identifica fluxos relacionados a cada CNPJ, ordenando os 
                % fluxos de acordo com a data de fim do seu período fiscal.
                idIndexes   = find(strcmp(idsList, ids{ii}));
                [~, idSort] = sort(arrayfun(@(x) x.Period(2), ecdObj(idIndexes)));
                idIndexes   = idIndexes(idSort);

                Table(end+1,:) = {...
                    ii, ...
                    ecdObj(idIndexes(1)).CompanyId, ...
                    ecdObj(idIndexes(1)).CompanyInfo.NIRE, ...                                        
                    ecdObj(idIndexes(1)).CompanyName, ...
                    strjoin(unique({ecdObj(idIndexes).State}), '<br>'), ...
                    numel(ecdObj(idIndexes)), ...
                    strjoin(strcat(arrayfun(@(x) sprintf('%s a %s', x.Period(:)), ecdObj(idIndexes), 'UniformOutput', false), '&emsp;–&emsp;', {ecdObj(idIndexes).FileName}), '<br>') ...
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

                    id = generateTextId(ecdObj(ii), 'scalar-period-oriented', jj);

                    validationMessage = ecdObj(ii).Sources(end).validationMessage;
                    if all(cellfun(@(x) isfield(validationMessage, x), {'xmlns', 'versao', 'nire', 'hashEsc'}))
                        validationMessage = rmfield(validationMessage, {'xmlns', 'versao', 'nire', 'hashEsc'});
                    end

                    Table(end+1,:) = { ...
                        sprintf('%d.%d%s', ecdIdx, kk, zz), ...
                        sprintf('%s a %s', ecdObj(ii).Period(:)), ...
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
        function Table = Raw(analyzedData, tableSettings)
            ecdObj = analyzedData.InfoSet.ecdObj;

            parsedSource = strsplit(tableSettings.Source, '+');
            tableSource  = parsedSource{1};
            tableId      = parsedSource{2};

            checkIfScalar(ecdObj)

            isTableRead(ecdObj, {tableId})
            Table = ecdObj.Table.(['x' tableId]);
        end
    end
end