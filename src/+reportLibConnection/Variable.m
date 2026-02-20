classdef (Abstract) Variable

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
        function fieldValue = GeneralSettings(reportInfo, fieldName, varargin)
            projectData     = reportInfo.Project;
            context         = reportInfo.Context;
            ecdObj          = reportInfo.Object;
            generalSettings = reportInfo.Settings;

            switch fieldName
                case {'FILE+ReportTemplate', 'ECD+ReportTemplate'}
                    fieldNames = strsplit(fieldName, '+');
                    fieldValue = sprintf([ ...
                        '<span style=\"display: block; margin: 10px; margin-bottom: 20px; ' ...
                        'text-align: justify; word-break: break-all;\">CONFIGURAÇÕES:<br>' ...
                        '&#x2022;&thinsp;Módulo \"%s\": %s<br>&#x2022;&thinsp;Modelo do ' ...
                        'relatório: %s<br><br>SÍMBOLOS:<br>&#x2022;&thinsp;&#x1F6AB; ' ...
                        '(escrituração não possui lançamentos contábeis)<br>&#x2022;' ...
                        '&thinsp;&#x1F7E2; (registro encontrado na base da Receita Federal), ' ...
                        '&#x1F534; (não encontrado na base da Receita Federal) e &#x26AA; ' ...
                        '(situação indeterminada)<br>&#x2022;&thinsp;&#10133; (registro mesclado) ' ...
                        'e &#x231B; (período fiscal não anual)</span>' ...
                        ], fieldNames{1}, reportLibConnection.Variable.GeneralSettings(reportInfo, fieldNames{1}), reportLibConnection.Variable.GeneralSettings(reportInfo, 'ReportTemplate'));

                case {'FILE', 'ECD'}
                    fieldValue = jsonencode(generalSettings.context.(fieldName));

                case 'ReportTemplate'
                     fieldValue = jsonencode(struct('Name', reportInfo.Model.Name, 'DocumentType', reportInfo.Model.DocumentType, 'Version', reportInfo.Model.Version));

                case 'Year'
                    yearList = unique(year([ecdObj.Period]));
                    fieldValue = strjoin(string(yearList), ', ');

                otherwise
                    error('UnexpectedFieldName')
            end
        end

        %-----------------------------------------------------------------%
        function fieldValue = ClassProperty(analyzedData, fieldName)
            ecdObj = analyzedData.InfoSet.ecdObj;

            switch fieldName
                case {'NumFiles', 'FileNameList'}
                    fileList = {};
                    for ii = 1:numel(ecdObj)
                        fileList = [fileList, {ecdObj(ii).Sources.file}];
                    end
                    fileList = unique(fileList);

                    switch fieldName
                        case 'NumFiles'
                            fieldValue = numel(fileList);
                        case 'FileNameList'
                            fieldValue = strjoin(strcat('"', fileList, '"'), ', ');
                    end

                case {'CompanyName', 'CompanyId', 'State'}
                    fieldValue = strjoin(unique({ecdObj.(fieldName)}), ', ');

                case 'Period'
                    periodList = [];
                    for ii = 1:numel(ecdObj)
                        for jj = 1:numel(ecdObj(ii).Sources)
                            periodList = [periodList, ecdObj(ii).Sources(jj).period];
                        end
                    end

                    [beginPeriodGlobal, endPeriodGlobal] = bounds(periodList, "all");
                    yearsCovered = unique(year(periodList));

                    if isscalar(yearsCovered)
                        monthsCovered = [];
                        for ii = 1:2:numel(periodList)-1
                            monthsCovered = [monthsCovered, month(periodList(ii)):month(periodList(ii+1))];
                        end
                        
                        monthsCovered  = unique(monthsCovered);
                        allYearCovered = isequal(monthsCovered, 1:12);

                        if allYearCovered
                            monthsCoveredNote = sprintf('todo o ano de %.0f', yearsCovered);
                        else 
                            if isscalar(monthsCovered)
                                monthsCoveredNote = sprintf('um único mês do ano de %.0f', yearsCovered);
                            else
                                monthsCoveredNote = sprintf('%.0f meses do ano de %.0f', numel(monthsCovered), yearsCovered);
                            end
                        end
                        fieldValue = sprintf('%s a %s, que contempla %s', beginPeriodGlobal, endPeriodGlobal, monthsCoveredNote);        
                    else
                        fieldValue = sprintf('%s a %s, que contempla %.0f anos fiscais', beginPeriodGlobal, endPeriodGlobal, numel(yearsCovered));
                    end

                case 'ReceitaFederal'
                    fieldValue = jsonencode(ecdObj.Sources(end).validationMessage);

                case 'ContentSample'
                    contentArray = arrayfun(@(x) strjoin(splitlines(x.Content(1:min(500, numel(x.Content)))), '<br>'), ecdObj, 'UniformOutput', false);
                    fieldValue = ['<font style="text-align: justify; word-break: break-all;">', strjoin(strcat(contentArray, '<br><font style="color: red;">[Texto truncado — Fonte:&thinsp;', ' ', {ecdObj.FileName}, ']</font>'), '<br><br>') '</font>'];

                case 'Layout'
                    fieldValue = strjoin(string(unique([ecdObj.Layout])));
                    
                case 'NumAccount'
                    fieldValue = height(ecdObj.Table.x_BALANCETE_RESULTADO);
                    switch fieldValue
                        case 0
                            fieldValue = '<font style="color:red;">nenhuma</font> conta';
                        case 1
                            fieldValue = 'uma única conta';
                        otherwise
                            fieldValue = sprintf('%d contas', fieldValue);
                    end

                case 'TotalValue'
                    fieldValue = sum(ecdObj.Table.x_BALANCETE_RESULTADO.TOTAL);
                    if fieldValue < 0
                        fieldValue = sprintf('<font style="color:red;">R$ %.2f</font>', fieldValue);
                    else
                        fieldValue = sprintf('R$ %.2f', fieldValue);
                    end

                otherwise
                    error('UnexpectedFieldName')
            end
        end
    end
end