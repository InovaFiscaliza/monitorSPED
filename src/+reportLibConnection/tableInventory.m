classdef tableInventory

    % Relação de variáveis que podem ser manipuladas quando da execução de
    % um dos métodos desta classe estática. Importante, contudo, editar os
    % argumentos previstos por método em "reportLibConnection.Controller".

    % • reportInfo....: estrutura com os campos "App", "Version", "Path", 
    %   "Model" e "Function".

    % • dataOverview..: lista de estruturas com os campos "ID", "InfoSet" e
    %   "HTML". Em "InfoSet", armazena-se um handle para instância da classe 
    %   model.ECD. As instância desse classe são organizadas, em dataOverview, 
    %   ordenadas ao CNPJ (ordenação primária) e Período Fiscal (secundária).

    % • analyzedData..: instância da classe model.ECD.
    
    % • tableSettings.: campo extraído do script .JSON que norteia a criação
    %   do relatório, o qual é uma estrutura com os campos "Origin", "Source", 
    %   "Columns", "Caption", "Settings", "Intro", "Error" e "LineBreak".

    methods (Static)
        %-----------------------------------------------------------------%
        function Table = File(dataOverview)
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
        function Table = Company(dataOverview)
            ecdObj = [dataOverview.InfoSet];
            Table  = table('Size',          [0, 5],                                   ...
                           'VariableTypes', {'cell', 'cell', 'cell', 'cell', 'cell'}, ...
                           'VariableNames', {'Empresa', 'CNPJ', 'Arquivo', 'Período Fiscal', 'Registros'});
        
            for ii = 1:numel(ecdObj)
                Table(end+1,:) = {...
                    ecdObj(ii).CompanyName, ...
                    ecdObj(ii).CompanyId, ...
                    strjoin(unique({ecdObj(ii).Sources.file}, 'stable'), '<br>'), ...
                    ecdObj(ii).Period, ...
                    jsonencode(ecdObj(ii).Table.x9900)};
            end
        end
    end
end