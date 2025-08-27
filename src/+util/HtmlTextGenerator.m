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
        % APPANALISE:INFO
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
            
        
            freeInitialText = sprintf('<font style="font-size: 12px;">O repositório das ferramentas desenvolvidas no Escritório de inovação da SFI pode ser acessado <a href="%s" target="_blank">aqui</a>.</font>\n\n', appURL.Sharepoint);
            htmlContent     = textFormatGUI.struct2PrettyPrintList(dataStruct, 'print -1', freeInitialText, outputFormat);
        end


        %-----------------------------------------------------------------%
        % MONITORSPED:FILE
        %-----------------------------------------------------------------%
        function htmlContent = File(ecdObj)
            mergeArray  = [ecdObj.PeriodMerged];
            statusArray = [ecdObj.FileStatus];

            if all(mergeArray)
                colorStatus = "purple";
                textStatus  = "REGISTRO MESCLADO";
            else
                if     all(statusArray == -2); colorStatus = 'red';   textStatus = 'ERRO FICHA |9999| OU REQUISIÇÃO HTTP';
                elseif all(statusArray == -1); colorStatus = 'red';   textStatus = 'NÃO CONSTA ARQUIVO RECEITA FEDERAL';
                elseif all(statusArray ==  0); colorStatus = 'gray';  textStatus = 'PENDENTE PESQUISA RECEITA FEDERAL';
                elseif all(statusArray ==  1); colorStatus = 'green'; textStatus = 'COINCIDE ARQUIVO RECEITA FEDERAL';
                else;                          colorStatus = 'gray';  textStatus = 'INDEFINIDO';
                end
            end

            if isscalar(ecdObj)
                if isfield(ecdObj.Table, 'x9900') && ~isempty(ecdObj.Table.x9900)
                    nonemptySheets = unique(ecdObj.Table.x9900.("REG_BLC"));
                else
                    sheetsNames    = fieldnames(ecdObj.Table);
                    nonemptySheets = sheetsNames(cellfun(@(x) ~isempty(ecdObj.Table.(x)), sheetsNames));
                    nonemptySheets = extractAfter(sort(nonemptySheets), 'x');
                end

                dataStruct(1) = struct('group', 'FileName', 'value', sprintf('"%s" (%s)', ecdObj.FileName, ecdObj.FileEncoding)); % textFormatGUI.cellstr2ListWithQuotes({...})
                dataStruct(2) = struct('group', 'Period',   'value', strjoin(string(ecdObj.Period), ' a '));
                dataStruct(3) = struct('group', 'Content',  'value', [strjoin(strtrim(splitlines(ecdObj.Content(1:500))), '\n') '<br><font style="color: red;">... [texto truncado]</font>']);
                dataStruct(4) = struct('group', 'Layout',   'value', string(ecdObj.Layout));
                
                if ~isempty(ecdObj.ReceitaFederal)
                    dataStruct(5) = struct('group', 'ReceitaFederal', 'value', ecdObj.ReceitaFederal);
                end
                dataStruct(end+1) = struct('group', 'Table', 'value', strjoin(nonemptySheets, ', '));

                freeInitialText   = [sprintf('<font style="font-size: 10px; color: white; background-color: %s; display: inline-block; vertical-align: middle; padding: 5px; border-radius: 5px;">%s</font><br><br>', colorStatus, textStatus) ...
                                     sprintf('<font style="font-size: 16px;"><b>%s</b></font><br>', ecdObj.CompanyName)                                                                                                                        ...
                                     sprintf('<font style="font-size: 11px;">CNPJ nº %s</font><br><br>', ecdObj.CompanyId)];

            else
                idsList = {ecdObj.CompanyId};
                ids = unique(idsList);

                if isscalar(ids)
                    dataStruct(1)   = struct('group', 'FileName', 'value', textFormatGUI.cellstr2Bullets(cellfun(@(x) sprintf('"%s"', x), {ecdObj.FileName}, 'UniformOutput', false)));
                    freeInitialText = [sprintf('<font style="font-size: 10px; color: white; background-color: %s; display: inline-block; vertical-align: middle; padding: 5px; border-radius: 5px;">%s</font><br><br>', colorStatus, textStatus) ...
                                       sprintf('<font style="font-size: 16px;"><b>%s</b></font><br>', ecdObj(1).CompanyName)                                                                                                                     ...
                                       sprintf('<font style="font-size: 11px;">CNPJ nº %s</font><br><br>', ecdObj(1).CompanyId)];

                else
                    dataStruct(1)   = struct('group', 'FileName', 'value', textFormatGUI.cellstr2Bullets(cellfun(@(x) sprintf('"%s"', x), {ecdObj.FileName}, 'UniformOutput', false)));
                    freeInitialText = [sprintf('<font style="font-size: 10px; color: white; background-color: %s; display: inline-block; vertical-align: middle; padding: 5px; border-radius: 5px;">%s</font><br><br>', colorStatus, textStatus) ...
                                       sprintf('<font style="font-size: 16px;"><b>%s</b></font><br><br>', '*.*')];
                end
            end

            htmlContent = textFormatGUI.struct2PrettyPrintList(dataStruct, 'delete', freeInitialText);
        end
    end
end