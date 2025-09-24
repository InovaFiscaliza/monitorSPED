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
            appGeneral = reportInfo.Settings;

            switch fieldName
                case 'MonitoringPlan'
                    fieldValue = jsonencode(appGeneral.(fieldName));
                case 'ExternalRequest'
                    fieldValue = jsonencode(appGeneral.(fieldName));
                otherwise
                    error('UnexpectedFieldName')
            end
        end

        %-----------------------------------------------------------------%
        function fieldValue = ClassProperty(analyzedData, fieldName)
            measData  = analyzedData.InfoSet.measData;
            measTable = analyzedData.InfoSet.measTable;

            switch fieldName
                case 'Filename'
                    fieldValue = strjoin(unique(strcat('"', {measData.(fieldName)}, '"')), ', ');
                case {'Sensor', 'Location', 'Location_I'}
                    fieldValue = strjoin(unique({measData.(fieldName)}), ', ');
                case 'Content'
                    fieldValue = strjoin(strcat({measData.Content}, '<br><font style="color: red;">[Texto truncado — Fonte:&thinsp;', ' ', {measData.Filename}, ']</font>'), '<br><br>');
                case 'MetaData'
                    fieldValue = strjoin(unique(arrayfun(@(x) jsonencode(x.MetaData), measData, 'UniformOutput', false)), '<br>');
                case 'Measures'
                    fieldValue = sum([measData.(fieldName)]);
                case 'FieldValueLimits'
                    [minFieldValue, maxFieldValue] = bounds(measTable.FieldValue);
                    fieldValue = sprintf('%.1f - %.1f V/m', minFieldValue, maxFieldValue);
                case 'ObservationTime'
                    [beginTime, endTime] = bounds(measTable.Timestamp);
                    fieldValue = sprintf('%s a %s', string(beginTime), string(endTime));
                case 'CoveredDistance'
                    fieldValue = sprintf('%.1f km', sum([measData.(fieldName)]));
                case 'LatitudeLimits'
                    [minLat, maxLat] = bounds(measTable.Latitude);
                    fieldValue = sprintf('[%.6fº, %.6fº]', minLat, maxLat);
                case 'LongitudeLimits'
                    [minLng, maxLng] = bounds(measTable.Longitude);
                    fieldValue = sprintf('[%.6fº, %.6fº]', minLng, maxLng);
                case {'Latitude', 'Longitude'}
                    fieldValue = sprintf('%.6fº', mean(measTable.(fieldName)));
                otherwise
                    error('UnexpectedFieldName')
            end
        end

        %-----------------------------------------------------------------%
        function fieldValue = ProjectProperty(reportInfo, analyzedData, fieldName)
            generalSettings = reportInfo.Settings;
            projectData  = reportInfo.Project;
            stationTable = reportInfo.Function.table_Stations;
            measData = analyzedData.InfoSet.measData;

            switch fieldName
                case 'LocationSummary'
                    hash = strjoin(unique({measData.UUID}));
                    hashIndex = find(strcmp({projectData.listOfLocations.Hash}, hash), 1);
                    fieldValue = jsonencode(projectData.listOfLocations(hashIndex));

                case 'LocationList'
                    fieldValue = strjoin(getFullListOfLocation(projectData, measData, stationTable, max(generalSettings.MonitoringPlan.Distance_km, generalSettings.ExternalRequest.Distance_km)), ', ');
                otherwise
                    error('UnexpectedFieldName')
            end
        end
    end
end