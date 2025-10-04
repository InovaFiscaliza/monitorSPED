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
        function fieldValue = GeneralSettings(reportInfo, fieldName)
            generalSettings = reportInfo.Settings;

            switch fieldName                
                case {'File', 'ECD'}
                    fieldValue = jsonencode(generalSettings.(fieldName));
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
                            fieldValue = num2str(numel(fileList));
                        case 'FileNameList'
                            fieldValue = strjoin(strcat('"', fileList, '"'), ', ');
                    end
                case {'CompanyName', 'CompanyId'}
                    fieldValue = strjoin(unique({ecdObj.(fieldName)}), ', ');
                case 'Period'
                    [beginTime, endTime] = bounds([ecdObj.Period], "all");
                    fieldValue = sprintf('%s a %s', beginTime, endTime);
                case 'ReceitaFederal'
                    fieldValue = jsonencode(ecdObj.Sources(end).validationMessage);
                case 'ContentSample'
                    contentArray = arrayfun(@(x) strjoin(splitlines(x.Content(1:min(500, numel(x.Content)))), '<br>'), ecdObj, 'UniformOutput', false);
                    fieldValue = ['<font style="text-align: justify; word-break: break-all;">', strjoin(strcat(contentArray, '<br><font style="color: red;">[Texto truncado — Fonte:&thinsp;', ' ', {ecdObj.FileName}, ']</font>'), '<br><br>') '</font>'];
                case 'Layout'
                    fieldValue = strjoin(string(unique([ecdObj.Layout])));
                otherwise
                    error('UnexpectedFieldName')
            end
        end
    end
end