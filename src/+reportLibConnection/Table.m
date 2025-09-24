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
        function Table = FileStatus(dataOverview)
            ecdObj = [dataOverview.InfoSet];
            Table  = table('Size',          [0, 6],                                             ...
                           'VariableTypes', {'double', 'cell', 'cell', 'cell', 'cell', 'cell'}, ...
                           'VariableNames', {'#', 'Arquivo', 'Codificação', 'Hash', 'Resposta webservice', 'Situação'});
        
            for ii = 1:numel(ecdObj)
                id = generateTextId(ecdObj(ii), 'period-oriented', false);

                Table(end+1,:) = {ii, ...
                    strjoin(unique({ecdObj(ii).Sources.file}, 'stable'), '<br>'), ...
                    strjoin({ecdObj(ii).Sources.encoding}, '<br>'), ...
                    strjoin({ecdObj(ii).Sources.hash}, '<br>'), ...
                    strjoin(arrayfun(@(x) jsonencode(x), [ecdObj(ii).Sources.validationMessage], 'UniformOutput', false), ',<br>'), ...
                    id};
            end
        end

        %-----------------------------------------------------------------%
        function Table = FileByCompany(dataOverview)
            ecdObj = [dataOverview.InfoSet];
            Table  = table('Size',          [0, 5],                                   ...
                           'VariableTypes', {'cell', 'cell', 'cell', 'cell', 'cell'}, ...
                           'VariableNames', {'Empresa', 'CNPJ', 'Arquivo', 'Período Fiscal', 'Registros'});
        
            for ii = 1:numel(ecdObj)
                Table(end+1,:) = {...
                    ecdObj(ii).CompanyName, ...
                    ecdObj(ii).CompanyId, ...
                    strjoin(unique({ecdObj(ii).Sources.file}, 'stable'), '<br>'), ...
                    char(strjoin(string(ecdObj(ii).Period), ' a ')), ...
                    strjoin(strcat(ecdObj(ii).Table.x9900.REG_BLC, ' (', cellstr(string(ecdObj(ii).Table.x9900.QTD_REG_BLC)), ')'), ', ')};
            end
        end

        %-----------------------------------------------------------------%
        function Table = PeriodByCompany(dataOverview)
            ecdObj = dataOverview.InfoSet.ecdObj;
            Table  = table('Size',          [0, 4],                           ...
                           'VariableTypes', {'cell', 'cell', 'cell', 'cell'}, ...
                           'VariableNames', {'Empresa', 'CNPJ', 'Período Fiscal', 'Situação'});

            idsList = {ecdObj.CompanyId};
            ids = unique(idsList);

            for id = ids
                % Identifica fluxos relacionados a cada CNPJ, ordenando os 
                % fluxos de acordo com a data de fim do seu período fiscal.
                idIndexes   = find(strcmp(idsList, id));
                [~, idSort] = sort(arrayfun(@(x) x.Period(2), ecdObj(idIndexes)));
                idIndexes   = idIndexes(idSort);

                idPeriod    = strjoin(arrayfun(@(x) char(strjoin(string(x.Period), ' a ')), ecdObj(idIndexes), 'UniformOutput', false), '<br>');
                idStatus    = strjoin(arrayfun(@(x) generateTextId(x, 'period-oriented', false), ecdObj(idIndexes), 'UniformOutput', false), '<br>');

                Table(end+1,:) = {...
                    ecdObj(idIndexes(1)).CompanyName, ...
                    ecdObj(idIndexes(1)).CompanyId, ...
                    idPeriod, ...
                    idStatus};                    
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