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
        function htmlContent = AppInfo(appGeneral, rootFolder, executionMode, renderCount, outputFormat)
            arguments
                appGeneral 
                rootFolder 
                executionMode
                renderCount
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
        
            dataStruct    = struct('group', 'COMPUTADOR',     'value', struct('Machine', rmfield(appVersion.machine, 'name'), 'Mode', sprintf('%s - %s', executionMode, appMode)));
            dataStruct(2) = struct('group', 'MATLAB',         'value', rmfield(appVersion.matlab, 'name'));
            if ~isempty(appVersion.browser)
                dataStruct(3) = struct('group', 'NAVEGADOR',  'value', rmfield(appVersion.browser, 'name'));
            end
            dataStruct(end+1) = struct('group', 'RENDERIZAÇÕES','value', renderCount);
            dataStruct(end+1) = struct('group', 'APLICATIVO', 'value', appVersion.application);
            
        
            freeInitialText = sprintf('<font style="font-size: 12px;">O repositório das ferramentas desenvolvidas no Laboratório de inovação da SFI pode ser acessado <a href="%s" target="_blank">aqui</a>.</font>\n\n', appURL.Sharepoint);
            htmlContent     = textFormatGUI.struct2PrettyPrintList(dataStruct, 'print -1', freeInitialText, outputFormat);
        end


        %-----------------------------------------------------------------%
        % WINMONITORSPED: FILE
        %-----------------------------------------------------------------%
        function textId = generateTextId(ecdObj, elementType, varargin)
            arguments
                ecdObj
                elementType char {mustBeMember(elementType, {'company-oriented', 'period-oriented', 'scalar-period-oriented'})}
            end

            arguments (Repeating)
                varargin
            end

            checkIfScalar(ecdObj)

            switch elementType
                case 'company-oriented'
                    nireInfo = '';
                    if ~isempty(ecdObj.CompanyInfo.NIRE)
                        nireInfo = sprintf('%s - ', ecdObj.CompanyInfo.NIRE);
                    end
                    textId = sprintf('%s - %s%s', ecdObj.CompanyId, nireInfo, ecdObj.CompanyName);

                case 'period-oriented'
                    preffixFlag = varargin{1};
                    preffixText = '';
                    if preffixFlag
                        preffixText = sprintf('%s     ', strjoin(string(ecdObj.Period), ' a '));
                    end

                    hasWarnings = '';
                    if ~isempty(ecdObj.GUI.warnings)
                        hasWarnings = '❗';
                    end

                    hasTransactions = '';
                    if ~ecdObj.GUI.hasTransactions
                        hasTransactions = '🚫';
                    end

                    [receitaFederalStatus, receitaFederalSourceFileStatus] = checkIfValidStatus(ecdObj);
                    if receitaFederalStatus
                        receitaFederalStatusIcon = '🟢'; % '&#x1F7E2;'
                    else
                        if all(receitaFederalSourceFileStatus < 0)
                            receitaFederalStatusIcon = '🔴'; % '&#x1F534;'
                        else
                            receitaFederalStatusIcon = '⚪';
                        end
                    end

                    periodStatusIcon = '';
                    if ~ecdObj.GUI.hasValidPeriod
                        periodStatusIcon = '⌛';
                    end

                    mergeStatusIcon = '';
                    if ecdObj.PeriodMerged
                        mergeStatusIcon = '➕';
                    end

                    textId = sprintf('%s%s%s%s%s%s', preffixText, hasWarnings, hasTransactions, receitaFederalStatusIcon, periodStatusIcon, mergeStatusIcon);

                case 'scalar-period-oriented'
                    sourceIndex = varargin{1};

                    hasWarnings = '';
                    if ~isempty(ecdObj.GUI.warnings)
                        hasWarnings = '❗';
                    end

                    hasTransactions = '';
                    if ~ecdObj.GUI.hasTransactions
                        hasTransactions = '🚫';
                    end

                    if ecdObj.Sources(sourceIndex).validationStatus > 0
                        receitaFederalStatusIcon = '🟢'; % '&#x1F7E2;'
                    else
                        if ecdObj.Sources(sourceIndex).validationStatus < 0
                            receitaFederalStatusIcon = '🔴'; % '&#x1F534;'
                        else
                            receitaFederalStatusIcon = '⚪';
                        end
                    end

                    [beginPeriod, endPeriod] = bounds(ecdObj.Sources(sourceIndex).period);
                    monthsCovered = month(beginPeriod):month(endPeriod);

                    periodStatusIcon = '';
                    if ~isequal(monthsCovered, 1:12)
                        periodStatusIcon = '⌛';
                    end

                    mergeStatusIcon = '';
                    if ecdObj.PeriodMerged
                        mergeStatusIcon = '➕';
                    end

                    textId = sprintf('%s%s%s%s%s', hasWarnings, hasTransactions, receitaFederalStatusIcon, periodStatusIcon, mergeStatusIcon);
            end
        end
        
        %-----------------------------------------------------------------%
        function htmlContent = File(ecdObj)
            if isscalar(ecdObj)
                if ~ecdObj.PeriodMerged
                    groupName = 'FileName';
                else
                    groupName = 'TempFileName';
                end
                dataStruct(1) = struct('group', groupName, 'value', sprintf('"%s"', ecdObj.FileName));
                
                if ecdObj.PeriodMerged
                    dataStruct(end+1) = struct('group', 'Origin', 'value', textFormatGUI.cellstr2Bullets(cellfun(@(x) sprintf('"%s"', x), {ecdObj.Sources.file}, 'UniformOutput', false)));
                end

                dataStruct(end+1) = struct('group', 'Size',     'value', textFormatGUI.bytes2human(ecdObj.Size));
                dataStruct(end+1) = struct('group', 'Hash',     'value', ecdObj.Hash);
                dataStruct(end+1) = struct('group', 'Encoding', 'value', ecdObj.Encoding);
                dataStruct(end+1) = struct('group', 'Encoding Test', 'value', ecdObj.EncodingInfo);                
                dataStruct(end+1) = struct('group', 'Content',  'value', [strtrim(strjoin((splitlines(ecdObj.Content(1:min(500, numel(ecdObj.Content))))), '\n')) '<br><font style="color: gray;">... [texto truncado]</font>']);
                
                [ordinaryIds, ~, readOrdinaryIds] = getTableIds(ecdObj);
                if isequal(ordinaryIds, readOrdinaryIds)
                    dataStruct(end+1) = struct('group', 'REGISTROS ORDINÁRIOS', 'value', strjoin(ordinaryIds, ', '));
                else
                    dataStruct(end+1) = struct('group', 'REGISTROS ORDINÁRIOS', 'value', strjoin(ordinaryIds, ', '));
                    dataStruct(end+1) = struct('group', 'REGISTROS LIDOS OU CRIADOS', 'value', strjoin(readOrdinaryIds, ', '));
                end

                if ~isempty(ecdObj.GUI.warnings)
                    dataStruct(end+1) = struct('group', 'ALERTAS ❗', 'value', ['<font style="color: red;">' strjoin(ecdObj.GUI.warnings, '<br>') '</font>']);
                end
                
                if ~ecdObj.GUI.hasTransactions
                    hasTransactionsMessage = [ ...
                        '<font style="color: red;">Empresa provavelmente está inativa, sem movimentação fiscal. ' ...
                        'Isto porque não foram encontrados contas de resultados (I050) ou lançamentos contábeis (I200) ' ...
                        'nesta escrituração.</font>' ...
                    ];
                    dataStruct(end+1) = struct('group', 'FATO CONTÁBIL 🚫', 'value', hasTransactionsMessage);
                end

                dataStruct(end+1) = struct('group', 'Layout',  'value', string(ecdObj.Layout));
                
                if ~ecdObj.PeriodMerged
                    [receitaFederalStatus, receitaFederalSourceFileStatus] = checkIfValidStatus(ecdObj);
                    if receitaFederalStatus
                        receitaFederalStatusIcon = '🟢'; % '&#x1F7E2;'
                    else
                        if all(receitaFederalSourceFileStatus < 0)
                            receitaFederalStatusIcon = '🔴'; % '&#x1F534;'
                        else
                            receitaFederalStatusIcon = '⚪';
                        end
                    end
                    dataStruct(end+1) = struct('group', sprintf('RECEITA FEDERAL %s', receitaFederalStatusIcon), 'value', ecdObj.Sources(end).validationMessage);

                    if numel(ecdObj.Sources) > 1
                        dataStruct(end+1) = struct('group', 'RECEITA FEDERAL TEST', 'value', jsonencode(rmfield(ecdObj.Sources, {'file', 'period', 'validationMessage', 'validationStatus'})));
                    end
                end                

                nireInfo = '';
                if ~isempty(ecdObj.CompanyInfo.NIRE)
                    nireInfo = sprintf('NIRE nº %s<br>', ecdObj.CompanyInfo.NIRE);
                end
                
                freeInitialText = [sprintf('<font style="font-size: 16px; "><b>%s</b></font><br>', ecdObj.CompanyName) ...
                                   sprintf('<font style="font-size: 11px;">CNPJ nº %s (%s)<br>', ecdObj.CompanyId, ecdObj.State) ...
                                   sprintf('%s', nireInfo), ...
                                   sprintf('%s</font><br><br>', strjoin(string(ecdObj.Period), ' a '))];
                
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
        % AUXAPP.WINECD
        %-----------------------------------------------------------------%
        function [accountTable, index, htmlContent] = AccountInfo(ecdObj, accountName)
            accountTable  = innerjoin(ecdObj.Table.x_CONTAS_ANOTACAO, ecdObj.Table.x_BALANCETE_RESULTADO, 'Keys', 'COD_CTA', 'RightVariables', {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'});
            accountTable  = innerjoin(accountTable,                   ecdObj.Table.x_CONTAS_DESCRICAO,    'Keys', 'COD_CTA', 'RightVariables', 'DESCRIÇÃO');

            [~, index]    = ismember(accountName, accountTable.("COD_CTA"));
            accountHist   = getAccountHistoric(ecdObj, accountName);

            dataStruct(1) = struct('group', 'FullDescription', 'value', ['•&thinsp;' accountTable.('DESCRIÇÃO'){index}]);
            dataStruct(2) = struct('group', 'AccountHistoric', 'value', textFormatGUI.cellstr2Bullets(accountHist));
            htmlContent   = textFormatGUI.struct2PrettyPrintList(dataStruct, 'delete', '');
        end

        %-----------------------------------------------------------------%
        function htmlContent = Warnings(ecdObj)
            [ordinaryIds, customIds, readIds] = getTableIds(ecdObj);

            if isempty(customIds)
                customIds = {'-1'};
            end

            dataStruct(1) = struct('group', 'OrdinaryTable',     'value', strjoin(ordinaryIds, ', '));
            dataStruct(2) = struct('group', 'ReadOrdinaryTable', 'value', strjoin(setdiff(readIds, customIds), ', '));
            dataStruct(3) = struct('group', 'CreateCustomTable', 'value', strjoin(customIds, ', '));

            if isempty(ecdObj.GUI.warnings)
                readWarnings = '-1';
            else
                readWarnings = strjoin(ecdObj.GUI.warnings, '\n');
            end
            dataStruct(4) = struct('group', 'Warnings', 'value', readWarnings);

            htmlContent = textFormatGUI.struct2PrettyPrintList(dataStruct, 'print -1', '', 'popup');
        end

        
        %-----------------------------------------------------------------%
        % AUXAPP.WINCONFIG: CHECKUPDATE
        %-----------------------------------------------------------------%
        function htmlContent = checkUpdate(appGeneral, rootFolder)
            try
                % Versão instalada no computador:
                appName          = class.Constants.appName;
                presentVersion   = struct(appName, appGeneral.AppVersion.application.version); 
                
                % Versão estável, indicada nos arquivos de referência (na nuvem):
                generalURL       = util.publicLink(appName, rootFolder);
                generalVersions  = webread(generalURL, weboptions("ContentType", "json"));        
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
        
                    msgWarning = textFormatGUI.struct2PrettyPrintList(dataStruct, 'print -1', '', 'popup');
                end
                
            catch ME
                msgWarning = ME.message;
            end
        
            htmlContent = msgWarning;
        end
    end
end