classdef (Abstract) HtmlTextGenerator

    % Essa classe abstrata organiza a criação de "textos decorados",
    % valendo-se das funcionalidades do HTML+CSS. Um texto aqui produzido
    % será renderizado em um componente uihtml, uilabel ou outro que tenha 
    % html como interpretador.

    % Antes de cada função, consta a indicação do módulo que chama a
    % função.

    properties (Constant)
        %-----------------------------------------------------------------%
    end

    
    methods (Static = true)
        %-----------------------------------------------------------------%
        % WINMONITORSPED: APPINFO
        %-----------------------------------------------------------------%
        function htmlContent = AppInfo(appGeneral, rootFolder, executionMode, outputFormat)
            arguments
                appGeneral 
                rootFolder 
                executionMode 
                outputFormat char {mustBeMember(outputFormat, {'popup', 'textview'})} = 'textview'
            end
        
            appName    = class.Constants.appName;
            appVersion = appGeneral.AppVersion;
            appURL     = util.publicLink(appName, rootFolder, appName);
        
            switch executionMode
                case {'MATLABEnvironment', 'desktopStandaloneApp'}
                    appMode = 'desktopApp';        
                case 'webApp'
                    computerName = ccTools.fcn.OperationSystem('computerName');
                    if strcmpi(computerName, appGeneral.computerName.webServer)
                        appMode = 'webServer';
                    else
                        appMode = 'deployServer';                    
                    end
            end
        
            dataStruct    = struct('group', 'COMPUTADOR',    'value', struct('Machine', appVersion.machine, 'Mode', sprintf('%s - %s', executionMode, appMode)));
            dataStruct(2) = struct('group', 'MATLAB',        'value', appVersion.matlab);
            if ~isempty(appVersion.browser)
                dataStruct(3) = struct('group', 'NAVEGADOR', 'value', appVersion.browser);
            end
            dataStruct(end+1) = struct('group', appName,     'value', appVersion.(appName));
            
        
            freeInitialText = sprintf('<font style="font-size: 12px;">O repositório das ferramentas desenvolvidas no Laboratório de inovação da SFI pode ser acessado <a href="%s" target="_blank">aqui</a>.</font>\n\n', appURL.Sharepoint);
            htmlContent     = textFormatGUI.struct2PrettyPrintList(dataStruct, 'print -1', freeInitialText, outputFormat);
        end


        %-----------------------------------------------------------------%
        % WINMONITORSPED: FILE
        %-----------------------------------------------------------------%
        function htmlContent = File(ecdObj)
            if isscalar(ecdObj)
                if ~ecdObj.PeriodMerged
                    groupName = 'FileName';
                else
                    groupName = 'TempFileName';
                end
                dataStruct(1) = struct('group', groupName, 'value', sprintf('"%s"', ecdObj.FileName));

                dataStruct(2) = struct('group', 'Period',  'value', strjoin(string(ecdObj.Period), ' a '));
                dataStruct(3) = struct('group', 'Content', 'value', [strjoin(strtrim(splitlines(ecdObj.Content(1:500))), '\n') '<br><font style="color: red;">... [texto truncado]</font>']);
                dataStruct(4) = struct('group', 'Table',   'value', strjoin(getTableIds(ecdObj), ', '));
                dataStruct(5) = struct('group', 'Layout',  'value', string(ecdObj.Layout));
                
                if ~ecdObj.PeriodMerged
                    dataStruct(end+1) = struct('group', 'Hash',           'value', upper(ecdObj.FileHash));
                end
                
                if ~isempty(ecdObj.ReceitaFederal)
                    dataStruct(end+1) = struct('group', 'ReceitaFederal', 'value', ecdObj.ReceitaFederal);
                end                

                nireInfo = '';
                if ~isempty(ecdObj.CompanyInfo.NIRE)
                    nireInfo = sprintf('<font style="font-size: 11px;">NIRE nº %s</font><br>', ecdObj.CompanyInfo.NIRE);
                end
                
                freeInitialText   = [sprintf('<font style="font-size: 16px; "><b>%s</b></font><br>', ecdObj.CompanyName) ...
                                     sprintf('<font style="font-size: 11px;">CNPJ nº %s</font><br>', ecdObj.CompanyId)   ...
                                     sprintf('%s<br>', nireInfo)];
                
            else
                idsList = {ecdObj.CompanyId};
                ids = unique(idsList);

                if isscalar(ids)
                    dataStruct(1)   = struct('group', 'FileName', 'value', textFormatGUI.cellstr2Bullets(cellfun(@(x) sprintf('"%s"', x), {ecdObj.FileName}, 'UniformOutput', false)));

                    nireInfo = '';
                    if ~isempty(ecdObj(1).CompanyInfo.NIRE)
                        nireInfo = sprintf('<font style="font-size: 11px;">NIRE nº %s</font><br>', ecdObj(1).CompanyInfo.NIRE);
                    end

                    freeInitialText = [sprintf('<font style="font-size: 16px;"><b>%s</b></font><br>',  ecdObj(1).CompanyName) ...
                                       sprintf('<font style="font-size: 11px;">CNPJ nº %s</font><br>', ecdObj(1).CompanyId) ...
                                       sprintf('%s<br>', nireInfo)];

                else
                    dataStruct(1)   = struct('group', 'FileName', 'value', textFormatGUI.cellstr2Bullets(cellfun(@(x) sprintf('"%s"', x), {ecdObj.FileName}, 'UniformOutput', false)));
                    freeInitialText = sprintf('<font style="font-size: 16px;"><b>%s</b></font><br><br>', '*.*');
                end
            end

            htmlContent = textFormatGUI.struct2PrettyPrintList(dataStruct, 'delete', freeInitialText);
        end


        %-----------------------------------------------------------------%
        % AUXAPP.WINECD: WARNINGS
        %-----------------------------------------------------------------%
        function htmlContent = Warnings(ecdObj)
            [ordinaryIds, createCustomIds, readOrdinaryIds] = getTableIds(ecdObj, true);

            if isempty(createCustomIds)
                createCustomIds = {'-1'};
            end

            dataStruct(1) = struct('group', 'OrdinaryTable',     'value', strjoin(ordinaryIds,     ', '));
            dataStruct(2) = struct('group', 'ReadOrdinaryTable', 'value', strjoin(readOrdinaryIds, ', '));
            dataStruct(3) = struct('group', 'CreateCustomTable', 'value', strjoin(createCustomIds, ', '));

            if isempty(ecdObj.GUI.warnings)
                readWarnings = '-1';
            else
                readWarnings = strjoin(ecdObj.GUI.warnings, '\n');
            end
            dataStruct(4) = struct('group', 'Warnings',          'value', readWarnings);

            htmlContent = textFormatGUI.struct2PrettyPrintList(dataStruct, 'print -1', '', 'popup');
        end
        
        
        %-----------------------------------------------------------------%
        % AUXAPP.WINCONFIG: CHECKUPDATE
        %-----------------------------------------------------------------%
        function htmlContent = checkUpdate(appGeneral, rootFolder)
            try
                % Versão instalada no computador:
                appName          = class.Constants.appName;
                presentVersion   = struct(appName, appGeneral.AppVersion.(appName).version); 
                
                % Versão estável, indicada nos arquivos de referência (na nuvem):
                generalURL       = util.publicLink(appName, rootFolder);
                generalVersions  = webread(generalURL,           weboptions("ContentType", "json"));        
                stableVersion    = struct(appName, generalVersions.(appName).Version);
                
                % Validação:
                if isequal(presentVersion, stableVersion)
                    msgWarning   = 'O monitorSPED está atualizado';
                else
                    updatedModule    = {};
                    nonUpdatedModule = {};
                    if strcmp(presentVersion.(appName), stableVersion.(appName))
                        updatedModule(end+1)    = {appName};
                    else
                        nonUpdatedModule(end+1) = {appName};
                    end
        
                    dataStruct    = struct('group', 'VERSÃO INSTALADA', 'value', presentVersion);
                    dataStruct(2) = struct('group', 'VERSÃO ESTÁVEL',   'value', stableVersion);
                    dataStruct(3) = struct('group', 'SITUAÇÃO',         'value', struct('updated', strjoin(updatedModule, ', '), 'nonupdated', strjoin(nonUpdatedModule, ', ')));
        
                    msgWarning = textFormatGUI.struct2PrettyPrintList(dataStruct);
                end
                
            catch ME
                msgWarning = ME.message;
            end
        
            htmlContent = msgWarning;
        end
    end
end