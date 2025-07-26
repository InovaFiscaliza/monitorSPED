classdef winMonitorSPED_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        GridLayout                     matlab.ui.container.GridLayout
        popupContainerGrid             matlab.ui.container.GridLayout
        SplashScreen                   matlab.ui.control.Image
        menu_Grid                      matlab.ui.container.GridLayout
        GridLayout3                    matlab.ui.container.GridLayout
        jsBackDoor                     matlab.ui.control.HTML
        FigurePosition                 matlab.ui.control.Image
        AppInfo                        matlab.ui.control.Image
        DataHubLamp                    matlab.ui.control.Lamp
        dockModule_Close               matlab.ui.control.Image
        dockModule_Undock              matlab.ui.control.Image
        NOMEDAEMPRESAMetadadosOutrascoisasLabel_2  matlab.ui.control.Label
        menu_Button4                   matlab.ui.control.StateButton
        menu_Separator2                matlab.ui.control.Image
        menu_Button2                   matlab.ui.control.StateButton
        menu_Button1                   matlab.ui.control.StateButton
        TabGroup                       matlab.ui.container.TabGroup
        Tab1_File                      matlab.ui.container.Tab
        file_Grid                      matlab.ui.container.GridLayout
        file_Tree                      matlab.ui.container.Tree
        file_Metadata                  matlab.ui.control.Label
        TabGroup2                      matlab.ui.container.TabGroup
        ARQUIVOSTab                    matlab.ui.container.Tab
        GridLayout2                    matlab.ui.container.GridLayout
        NOMEDAEMPRESAMetadadosOutrascoisasLabel  matlab.ui.control.Label
        file_toolGrid                  matlab.ui.container.GridLayout
        file_CheckRFB                  matlab.ui.control.Image
        file_MergeFiles                matlab.ui.control.Image
        Image                          matlab.ui.control.Image
        file_OpenFileButton            matlab.ui.control.Image
        Tab2_Playback                  matlab.ui.container.Tab
        Tab5_RFDataHub                 matlab.ui.container.Tab
        Tab6_Config                    matlab.ui.container.Tab
        file_ContextMenu_Tree          matlab.ui.container.ContextMenu
        file_ContextMenu_delTree1Node  matlab.ui.container.Menu
    end

    
    properties (Access = public)
        %-----------------------------------------------------------------%
        % PROPRIEDADES COMUNS A TODOS OS APPS
        %-----------------------------------------------------------------%
        General
        General_I

        rootFolder
        entryPointFolder        

        % Essa propriedade registra o tipo de execução da aplicação, podendo
        % ser: 'built-in', 'desktopApp' ou 'webApp'.
        executionMode        

        % A função do timer é executada uma única vez após a renderização
        % da figura, lendo arquivos de configuração, iniciando modo de operação
        % paralelo etc. A ideia é deixar o MATLAB focar apenas na criação dos 
        % componentes essenciais da GUI (especificados em "createComponents"), 
        % mostrando a GUI para o usuário o mais rápido possível.
        timerObj

        % Controla a seleção da TabGroup a partir do menu.
        tabGroupController

        % Janela de progresso já criada no DOM. Dessa forma, controla-se 
        % apenas a sua visibilidade - e tornando desnecessário criá-la a
        % cada chamada (usando uiprogressdlg, por exemplo).
        progressDialog

        % Objeto que possibilita integração com o eFiscaliza.
        eFiscalizaObj

        %-----------------------------------------------------------------%
        % PROPRIEDADES ESPECÍFICAS
        %-----------------------------------------------------------------%
        projectData
        ecdObj = model.ECD.empty
    end


    methods
        %-----------------------------------------------------------------%
        % COMUNICAÇÃO ENTRE PROCESSOS:
        % • ipcMainJSEventsHandler
        %   Eventos recebidos do objeto app.jsBackDoor por meio de chamada 
        %   ao método "sendEventToMATLAB" do objeto "htmlComponent" (no JS).
        %
        % • ipcMainMatlabCallsHandler
        %   Eventos recebidos dos apps secundários.
        %-----------------------------------------------------------------%
        function ipcMainJSEventsHandler(app, event)
            try
                switch event.HTMLEventName
                    % JS
                    case 'renderer'
                        startup_Controller(app)
                    case 'unload'
                        closeFcn(app)

                    % MAINAPP
                    case 'mainApp.file_Tree'
                        file_ContextMenu_delTree1NodeSelected(app)

                    % DRIVETEST / RFDATAHUB
                    case {'auxApp.winDriveTest.filter_Tree', 'auxApp.winDriveTest.points_Tree', 'auxApp.winRFDataHub.filter_Tree'}
                        if contains(event.HTMLEventName, 'winDriveTest')
                            auxAppName = 'DRIVETEST';
                        elseif contains(event.HTMLEventName, 'winRFDataHub')
                            auxAppName = 'RFDATAHUB';
                        end

                        idxAuxApp = app.tabGroupController.Components.Tag == auxAppName;
                        hAuxApp   = app.tabGroupController.Components.appHandle{idxAuxApp};
                        ipcSecundaryJSEventsHandler(hAuxApp, event)

                    % JSBACKDOOR (compCustomization.js)
                    % "BackgroundColorTurnedInvisible" | "customForm" | "getURL" | "getNavigatorBasicInformation"
                    case 'BackgroundColorTurnedInvisible'
                        switch event.HTMLEventData
                            case 'SplashScreen'
                                if isvalid(app.popupContainerGrid)
                                    delete(app.popupContainerGrid)
                                end
                            otherwise
                                error('UnexpectedEvent')
                        end
                    
                    case 'customForm'
                        switch event.HTMLEventData.uuid
                            case 'eFiscalizaSignInPage'
                                report_uploadInfoController(app, event.HTMLEventData, 'uploadDocument')
                            case 'openDevTools'
                                if isequal(app.General.operationMode.DevTools, rmfield(event.HTMLEventData, 'uuid'))
                                    webWin = struct(struct(struct(app.UIFigure).Controller).PlatformHost).CEF;
                                    webWin.openDevTools();
                                end
                        end

                    case 'getCssPropertyValue'
                        objHandle = eval(event.HTMLEventData.componentName);
                        cssProp   = event.HTMLEventData.propertyName;
                        cssValue  = event.HTMLEventData.propertyValue;

                        if ~isprop(objHandle, 'StyleObservations')
                            objHandle.addprop('StyleObservations');
                        end
                        objHandle.StyleObservations.(cssProp) = cssValue;

                    otherwise
                        error('UnexpectedEvent')
                end
                drawnow

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', getReport(ME));
            end
        end

        %-----------------------------------------------------------------%
        function ipcMainMatlabCallsHandler(app, callingApp, operationType, varargin)
            try
                switch class(callingApp)
                    % CONFIG
                    case {'auxApp.winConfig', 'auxApp.winConfig_exported'}
                        switch operationType
                            case 'closeFcn'
                                closeModule(app.tabGroupController, "CONFIG", app.General)
                            case 'checkDataHubLampStatus'
                                DataHubWarningLamp(app)
                            case 'openDevTools'
                                dialogBox    = struct('id', 'login',    'label', 'Usuário: ', 'type', 'text');
                                dialogBox(2) = struct('id', 'password', 'label', 'Senha: ',   'type', 'password');
                                sendEventToHTMLSource(app.jsBackDoor, 'customForm', struct('UUID', 'openDevTools', 'Fields', dialogBox))
                            otherwise
                                error('UnexpectedCall')
                        end

                    % ECD
                    case {'auxApp.winECD', 'auxApp.winECD_exported'}
                        switch operationType
                            case 'closeFcn'
                                closeModule(app.tabGroupController, "ECD", app.General)
                            case 'updateTreeView'
                                if ~isempty(app.file_Tree.SelectedNodes)
                                    nodeData = unique([app.file_Tree.SelectedNodes.NodeData]);

                                    if isequal(nodeData, varargin{1})
                                        app.file_Metadata.UserData = [];
                                        file_TreeSelectionChanged(app)
                                    end
                                end
                            otherwise
                                error('UnexpectedCall')
                        end

                    % RFDATAHUB
                    case {'auxApp.winRFDataHub', 'auxApp.winRFDataHub_exported'}
                        switch operationType
                            case 'closeFcn'
                                closeModule(app.tabGroupController, "RFDATAHUB", app.General)
                            otherwise
                                error('UnexpectedCall')
                        end
    
                    otherwise
                        error('UnexpectedCall')
                end

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', getReport(ME));            
            end

            % Caso um app auxiliar esteja em modo DOCK, o progressDialog do
            % app auxiliar coincide com o do appAnalise. Força-se, portanto, 
            % a condição abaixo para evitar possível bloqueio da tela.
            app.progressDialog.Visible = 'hidden';
        end
    end
    
    
    methods (Access = private)
        %-----------------------------------------------------------------%
        % JSBACKDOOR
        %-----------------------------------------------------------------%
        function jsBackDoor_Initialization(app)
            app.jsBackDoor.HTMLSource           = appUtil.jsBackDoorHTMLSource();
            app.jsBackDoor.HTMLEventReceivedFcn = @(~, evt)ipcMainJSEventsHandler(app, evt);
        end

        %-----------------------------------------------------------------%
        function jsBackDoor_Customizations(app, tabIndex)
            persistent customizationStatus
            if isempty(customizationStatus)
                customizationStatus = [false, false, false, false];
            end

            switch tabIndex
                case 0
                    sendEventToHTMLSource(app.jsBackDoor, 'startup', app.executionMode);
                    app.progressDialog  = ccTools.ProgressDialog(app.jsBackDoor);
                    customizationStatus = [false, false, false, false];

                otherwise
                    if customizationStatus(tabIndex)
                        return
                    end

                    appName = class(app);

                    customizationStatus(tabIndex) = true;
                    switch tabIndex
                        case 1 % FILE
                            elToModify = {app.popupContainerGrid, ...
                                          app.file_Tree,          ...
                                          app.file_Metadata};                % ui.TextView

                            elDataTag  = ui.CustomizationBase.getElementsDataTag(elToModify);
                            if ~isempty(elDataTag)
                                sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', {                                                           ...
                                    struct('appName', appName, 'dataTag', elDataTag{1}, 'style',    struct('backgroundColor', 'rgba(255,255,255,0.65)')), ...
                                    struct('appName', appName, 'dataTag', elDataTag{2}, 'listener', struct('componentName', 'mainApp.file_Tree', 'keyEvents', {{'Delete', 'Backspace'}})), ...
                                });

                                ui.TextView.startup(app.jsBackDoor, elToModify{3}, appName);
                            end

                        otherwise
                            % Customização dos módulos que são renderizados
                            % nesta figura são controladas pelos próprios
                            % módulos.
                    end
            end
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        % INICIALIZAÇÃO DO APP
        %-----------------------------------------------------------------%
        function startup_timerCreation(app)
            app.timerObj = timer("ExecutionMode", "fixedSpacing", ...
                                 "StartDelay",    1.5,            ...
                                 "Period",        .1,             ...
                                 "TimerFcn",      @(~,~)app.startup_timerFcn);
            start(app.timerObj)
        end

        %-----------------------------------------------------------------%
        function startup_timerFcn(app)
            if ccTools.fcn.UIFigureRenderStatus(app.UIFigure)
                stop(app.timerObj)
                delete(app.timerObj)

                jsBackDoor_Initialization(app)
            end
        end

        %-----------------------------------------------------------------%
        function startup_Controller(app)
            drawnow
            
            % Essa propriedade registra o tipo de execução da aplicação, podendo
            % ser: 'built-in', 'desktopApp' ou 'webApp'.
            app.executionMode = appUtil.ExecutionMode(app.UIFigure);
            if ~strcmp(app.executionMode, 'webApp')
                app.FigurePosition.Visible = 1;
                appUtil.winMinSize(app.UIFigure, class.Constants.windowMinSize)
            end

            % Identifica o local deste arquivo .MLAPP, caso se trate das versões 
            % "built-in" ou "webapp", ou do .EXE relacionado, caso se trate da
            % versão executável (neste caso, o ctfroot indicará o local do .MLAPP).
            MFilePath = fileparts(mfilename('fullpath'));
            app.rootFolder = appUtil.RootFolder(class.Constants.appName, MFilePath);

            % Customizações...
            jsBackDoor_Customizations(app, 0)
            jsBackDoor_Customizations(app, 1)

            startup_ConfigFileRead(app, MFilePath)
            startup_AppProperties(app)
            startup_GUIComponents(app)

            sendEventToHTMLSource(app.jsBackDoor, 'turningBackgroundColorInvisible', struct('componentName', 'SplashScreen', 'componentDataTag', struct(app.SplashScreen).Controller.ViewModel.Id));
            drawnow

            % Por fim, exclui-se o splashscreen.
            if isvalid(app.popupContainerGrid)
                pause(1)
                delete(app.popupContainerGrid)
            end
        end

        %-----------------------------------------------------------------%
        function startup_ConfigFileRead(app, MFilePath)
            % "GeneralSettings.json"
            [app.General_I, msgWarning] = appUtil.generalSettingsLoad(class.Constants.appName, app.rootFolder);
            if ~isempty(msgWarning)
                appUtil.modalWindow(app.UIFigure, 'error', msgWarning);
            end

            % Para criação de arquivos temporários, cria-se uma pasta da 
            % sessão.
            tempDir = tempname;
            mkdir(tempDir)
            app.General_I.fileFolder.tempPath  = tempDir;
            app.General_I.fileFolder.MFilePath = MFilePath;

            switch app.executionMode
                case 'webApp'
                    % Força a exclusão do SplashScreen do MATLAB Web Server.
                    sendEventToHTMLSource(app.jsBackDoor, "delProgressDialog");

                    % Webapp também não suporta outras janelas, de forma que os 
                    % módulos auxiliares devem ser abertos na própria janela
                    % do appAnalise.
                    app.dockModule_Undock.Visible     = 0;

                    app.General_I.operationMode.Debug = false;
                    app.General_I.operationMode.Dock  = true;
                    
                    % A pasta do usuário não é configurável, mas obtida por 
                    % meio de chamada a uiputfile. 
                    app.General_I.fileFolder.userPath = tempDir;

                    % A renderização do plot no MATLAB WebServer, enviando-o à uma 
                    % sessão do webapp como imagem Base64, é crítica por depender 
                    % das comunicações WebServer-webapp e WebServer-BaseMapServer. 
                    % Ao configurar o Basemap como "none", entretanto, elimina-se a 
                    % necessidade de comunicação com BaseMapServer, além de tornar 
                    % mais eficiente a comunicação com webapp porque as imagens
                    % Base64 são menores (uma imagem com Basemap "sattelite" pode 
                    % ter 500 kB, enquanto uma imagem sem Basemap pode ter 25 kB).
                    app.General_I.Plot.GeographicAxes.Basemap = 'none';

                otherwise    
                    % Resgata a pasta de trabalho do usuário (configurável).
                    userPaths = appUtil.UserPaths(app.General_I.fileFolder.userPath);
                    app.General_I.fileFolder.userPath = userPaths{end};

                    switch app.executionMode
                        case 'desktopStandaloneApp'
                            app.General_I.operationMode.Debug = false;
                        case 'MATLABEnvironment'
                            app.General_I.operationMode.Debug = true;
                    end
            end

            app.General            = app.General_I;        
            app.General.AppVersion = util.getAppVersion(app.rootFolder, MFilePath, tempDir); % RFDataHub lido aqui

            % Leitura de arquivo "IBGE.mat", salvando-o em memória como 
            % variável global.
            [~, msgError] = gpsLib.checkIfIBGEIsGlobal();
            if ~isempty(msgError)
                switch app.executionMode
                    case 'MATLABEnvironment'
                        msgQuestion = sprintf(['Erro na leitura da base de dados "IBGE"\n%s\n\nEsse problema pode ' ...
                                               'ser resolvido mapeando "SupportPackages" no path do MATLAB'], msgError);
                    otherwise
                        msgQuestion = sprintf(['Erro na leitura da base de dados "IBGE"\n%s\n\nEsse problema pode ' ...
                                               'ser resolvido apagando manualmente a pasta %s'], msgError, ctfroot);
                end

                appUtil.modalWindow(app.UIFigure, 'uiconfirm', msgQuestion, {'OK'}, 1, 1);
                closeFcn(app)
            end
        end

        %-----------------------------------------------------------------%
        function startup_AppProperties(app)
            % ...
        end

        %-----------------------------------------------------------------%
        function startup_GUIComponents(app)
            % Objeto que conecta o TabGroup ao GraphicMenu.
            app.tabGroupController = tabGroupGraphicMenu(app.menu_Grid, app.TabGroup, app.progressDialog, @app.jsBackDoor_Customizations, []);
            addComponent(app.tabGroupController, "Built-in", "",                      app.menu_Button1, "AlwaysOn", struct('On', 'OpenFile_32Yellow.png', 'Off', 'OpenFile_32White.png'), matlab.graphics.GraphicsPlaceholder, 1)
            addComponent(app.tabGroupController, "External", "auxApp.winECD",         app.menu_Button2, "AlwaysOn", struct('On', 'Playback_32Yellow.png', 'Off', 'Playback_32White.png'), app.menu_Button1,                    2)
            addComponent(app.tabGroupController, "External", "auxApp.winConfig",      app.menu_Button4, "AlwaysOn", struct('On', 'Settings_36Yellow.png', 'Off', 'Settings_36White.png'), app.menu_Button1,                    4)

            % Alerta, caso não tenha sido feito mapemanto de pasta do sharepoint.
            DataHubWarningLamp(app)
        end

        %-----------------------------------------------------------------%
        function DataHubWarningLamp(app)
            if isfolder(app.General.fileFolder.DataHub_POST)
                app.DataHubLamp.Visible = 0;
            else
                app.DataHubLamp.Visible = 1;
            end
        end

        %-----------------------------------------------------------------%
        function file_TreeBuilding(app)
            if ~isempty(app.file_Tree.Children)
                delete(app.file_Tree.Children)
            end

            idsList = {app.ecdObj.CompanyId};

            if ~isempty(idsList)
                [ids, idsIndexes] = unique(idsList, 'stable');
                [~, idsSortedIndexes] = sort({app.ecdObj(idsIndexes).CompanyName});

                for id = ids(idsSortedIndexes)
                    idIndexes = find(strcmp(idsList, id));
                    [~, idSortedIndexes] = sort(arrayfun(@(x) x.Period(1), app.ecdObj(idIndexes)));
    
                    treeNodeParent = uitreenode(app.file_Tree, ...
                        'Text', sprintf('%s (CNPJ nº %s)', app.ecdObj(idIndexes(1)).CompanyName, app.ecdObj(idIndexes(1)).CompanyId), ...
                        'NodeData', idIndexes, 'ContextMenu', app.file_ContextMenu_Tree);
    
                    for idx = idIndexes(idSortedIndexes)
                        uitreenode(treeNodeParent, ...
                            'Text', sprintf('%s', strjoin(string(app.ecdObj(idx).Period), ' a ')), ...
                            'NodeData', idx, 'ContextMenu', app.file_ContextMenu_Tree);
                    end
                end
                expand(app.file_Tree, 'all')
    
                if ~isempty(app.ecdObj)
                    app.file_Tree.SelectedNodes = app.file_Tree.Children(1).Children(1);
                end
                file_TreeSelectionChanged(app)
            end
        end

        %-----------------------------------------------------------------%
        function misc_updateLastVisitedFolder(app, filePath)
            app.General_I.fileFolder.lastVisited = filePath;
            app.General.fileFolder.lastVisited   = filePath;

            appUtil.generalSettingsSave(class.Constants.appName, app.rootFolder, app.General_I, app.executionMode)
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        % TABGROUPCONTROLLER
        %-----------------------------------------------------------------%
        function hAuxApp = auxAppHandle(app, auxAppName)
            arguments
                app
                auxAppName string {mustBeMember(auxAppName, ["ECD", "CONFIG"])}
            end

            hAuxApp = app.tabGroupController.Components.appHandle{app.tabGroupController.Components.Tag == auxAppName};
        end

        %-----------------------------------------------------------------%
        function inputArguments = auxAppInputArguments(app, auxAppName)
            arguments
                app
                auxAppName char {mustBeMember(auxAppName, {'FILE', 'ECD', 'CONFIG'})}
            end
            
            [auxAppIsOpen, ...
             auxAppHandle] = checkStatusModule(app.tabGroupController, auxAppName);

            inputArguments = {app};

            switch auxAppName
                case 'ECD'
                    if auxAppIsOpen
                        % ...
                    end
            end
        end

        %-----------------------------------------------------------------%
        function userSelection = misc_checkIfAuxiliarAppIsOpen(app, operationType)
            userSelection    = 'Sim';

            hECD  = auxAppHandle(app, "ECD");

            if ~isempty(hECD) && isvalid(hECD)
                msgQuestion   = sprintf(['A operação "%s" demanda que o módulo auxiliar "ECD" seja fechado, '          ...
                                         'caso aberto, pois as informações consumidas por esse módulo poderá ficar desatualizada. ' ...
                                         'Deseja continuar?'], operationType);
                userSelection = appUtil.modalWindow(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 2, 2);

                if userSelection == "Sim"
                    closeModule(app.tabGroupController, "ECD",  app.General)
                end
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)

            try
                % WARNING MESSAGES
                appUtil.disablingWarningMessages()

                % <GUI>
                app.popupContainerGrid.Layout.Row = [1,2];
                app.GridLayout.RowHeight = {44, '1x'};
                % </GUI>

                appUtil.winPosition(app.UIFigure)
                startup_timerCreation(app)

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end
            
        end

        % Close request function: UIFigure
        function closeFcn(app, event)

            % Aspectos gerais (comum em todos os apps):
            appUtil.beforeDeleteApp(app.progressDialog, app.General_I.fileFolder.tempPath, app.tabGroupController, app.executionMode)
            delete(app)
            
        end

        % Value changed function: menu_Button1, menu_Button2, menu_Button4
        function menu_mainButtonPushed(app, event)

            clickedButton  = event.Source;
            auxAppTag      = clickedButton.Tag;

            inputArguments = auxAppInputArguments(app, auxAppTag);
            openModule(app.tabGroupController, event.Source, event.PreviousValue, app.General, inputArguments{:})
            
        end

        % Image clicked function: dockModule_Close, dockModule_Undock
        function menu_DockButtonPushed(app, event)
            
            clickedButton = findobj(app.menu_Grid, 'Type', 'uistatebutton', 'Value', true);
            auxAppTag     = clickedButton.Tag;

            switch event.Source
                case app.dockModule_Undock
                    appGeneral = app.General;
                    appGeneral.operationMode.Dock = false;

                    inputArguments = auxAppInputArguments(app, auxAppTag);
                    closeModule(app.tabGroupController, auxAppTag, app.General)
                    openModule(app.tabGroupController, clickedButton, false, appGeneral, inputArguments{:})

                case app.dockModule_Close
                    closeModule(app.tabGroupController, auxAppTag, app.General)
            end

        end

        % Image clicked function: AppInfo, FigurePosition
        function menu_ToolbarImageCliced(app, event)

            switch event.Source
                case app.FigurePosition
                    app.UIFigure.Position(3:4) = class.Constants.windowSize;
                    appUtil.winPosition(app.UIFigure)

                case app.AppInfo
                    if isempty(app.AppInfo.Tag)
                        app.progressDialog.Visible = 'visible';
                        app.AppInfo.Tag = util.HtmlTextGenerator.AppInfo(app.General, app.rootFolder, app.executionMode, "popup");
                        app.progressDialog.Visible = 'hidden';
                    end

                    msgInfo = app.AppInfo.Tag;
                    appUtil.modalWindow(app.UIFigure, 'info', msgInfo);
            end

        end

        % Image clicked function: file_OpenFileButton
        function file_ButtonPushed_OpenFile(app, event)

            % VALIDAÇÃO
            if strcmp(misc_checkIfAuxiliarAppIsOpen(app, 'INCLUIR ARQUIVO'), 'Não')
                return
            end

            % SELEÇÃO DE ARQUIVO(S)
            [fileName, filePath] = uigetfile({'*.txt';'*.csv';'*.mat';'*.*'}, ...
                                              '', app.General.fileFolder.lastVisited, 'MultiSelect', 'on');
            figure(app.UIFigure)

            if isequal(fileName, 0)
                return
            elseif ~iscell(fileName)
                fileName = {fileName};
            end
            misc_updateLastVisitedFolder(app, filePath)            

            d = appUtil.modalWindow(app.UIFigure, "progressdlg", "Em andamento...");
            
            fileFullName = fullfile(filePath, fileName);
            filesError   = struct('File', {}, 'Error', {});

            for ii = 1:numel(fileFullName)
                d.Message = sprintf('<font style="font-size: 12px;">Em andamento a leitura do arquivo %d de %d:<br>• <b>%s</b></font>', ii, numel(fileFullName), fileName{ii});

                % Verifica se arquivo já foi lido, comparando o seu nome com 
                % a variável app.ecdObj.
                if ~ismember(fileName{ii}, {app.ecdObj.FileName})
                    [app.ecdObj, msg] = app.ecdObj.addFiles(fileFullName{ii});

                    if ~isempty(msg)
                        filesError(end+1) = struct('File', sprintf('"%s"', fileName{ii}), 'Error', strjoin(msg));
                        continue
                    end
                end
            end

            % LOG
            if ~isempty(filesError)
                msgWarning = sprintf('<font style="font-size: 12px;">Arquivos que apresentaram erro na leitura:\n%s\n\n</font>', strjoin(strcat({'•&thinsp;<b>'}, {filesError.File}, {'</b>: <i>'}, {filesError.Error}), '</i>\n\n'));
                appUtil.modalWindow(app.UIFigure, "error", msgWarning);                
            end
            
            % Atualiza app.file_Tree.
            file_TreeBuilding(app)

            delete(d)

        end

        % Selection changed function: file_Tree
        function file_TreeSelectionChanged(app, event)
            
            nodeData = [];
            if ~isempty(app.file_Tree.SelectedNodes)
                nodeData = unique([app.file_Tree.SelectedNodes.NodeData]);
            end

            if isequal(app.file_Metadata.UserData, nodeData)
                return
            end

            app.file_MergeFiles.Enable = 0;
            if isempty(nodeData)
                app.file_Metadata.Text = '';
                app.file_Metadata.UserData = [];
                app.file_CheckRFB.Enable = 0;

            else
                app.file_Metadata.Text = util.HtmlTextGenerator.File(app.ecdObj(nodeData));
                app.file_Metadata.UserData = nodeData;
                app.file_CheckRFB.Enable = 1;

                if ~isscalar(nodeData)
                    app.file_MergeFiles.Enable = 1;
                end
            end

            if isempty(app.ecdObj)
                app.menu_Button2.Enable = 0;
            else
                app.menu_Button2.Enable = 1;
            end
            
        end

        % Menu selected function: file_ContextMenu_delTree1Node
        function file_ContextMenu_delTree1NodeSelected(app, event)
            
            if ~isempty(app.file_Tree.SelectedNodes)
                % VALIDAÇÃO
                if strcmp(misc_checkIfAuxiliarAppIsOpen(app, 'EXCLUIR ARQUIVO'), 'Não')
                    return
                end

                % EXCLUIR ARQUIVO(S)
                idx = [app.file_Tree.SelectedNodes.NodeData];
                app.ecdObj(idx) = [];
                file_TreeBuilding(app)
            end

        end

        % Image clicked function: file_MergeFiles
        function file_MergeFilesImageClicked(app, event)
            
            nodeData = [];
            if ~isempty(app.file_Tree.SelectedNodes)
                nodeData = unique([app.file_Tree.SelectedNodes.NodeData]);
            end

            nodeData

            % Retornar erro caso se trate de empresas distintas (com CNPJs 
            % diferentes)

        end

        % Image clicked function: file_CheckRFB
        function file_CheckRFBClicked(app, event)
            
            nodeData = [];
            if ~isempty(app.file_Tree.SelectedNodes)
                nodeData = unique([app.file_Tree.SelectedNodes.NodeData]);
            end

            nodeData

            % Refatorar código do Elio/Sérgio em função em "+util"

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [0.9412 0.9412 0.9412];
            app.UIFigure.Position = [100 100 1244 660];
            app.UIFigure.Name = 'monitorSPED';
            app.UIFigure.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'icon_48.png');
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeFcn, true);
            app.UIFigure.HandleVisibility = 'on';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {44, '1x', 44};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Tooltip = {''};
            app.GridLayout.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.Layout.Row = [1 2];
            app.TabGroup.Layout.Column = 1;

            % Create Tab1_File
            app.Tab1_File = uitab(app.TabGroup);
            app.Tab1_File.BackgroundColor = 'none';

            % Create file_Grid
            app.file_Grid = uigridlayout(app.Tab1_File);
            app.file_Grid.ColumnWidth = {5, 320, '1x', 10, 320, 5};
            app.file_Grid.RowHeight = {94, 10, '1x', 5, 34};
            app.file_Grid.ColumnSpacing = 0;
            app.file_Grid.RowSpacing = 0;
            app.file_Grid.Padding = [0 0 0 26];
            app.file_Grid.BackgroundColor = [1 1 1];

            % Create file_toolGrid
            app.file_toolGrid = uigridlayout(app.file_Grid);
            app.file_toolGrid.ColumnWidth = {22, 5, 22, 22, '1x'};
            app.file_toolGrid.RowHeight = {3, 17, 2};
            app.file_toolGrid.ColumnSpacing = 5;
            app.file_toolGrid.RowSpacing = 0;
            app.file_toolGrid.Padding = [5 6 5 6];
            app.file_toolGrid.Layout.Row = 5;
            app.file_toolGrid.Layout.Column = [1 6];

            % Create file_OpenFileButton
            app.file_OpenFileButton = uiimage(app.file_toolGrid);
            app.file_OpenFileButton.ScaleMethod = 'none';
            app.file_OpenFileButton.ImageClickedFcn = createCallbackFcn(app, @file_ButtonPushed_OpenFile, true);
            app.file_OpenFileButton.Tooltip = {'Seleciona arquivos'};
            app.file_OpenFileButton.Layout.Row = [1 3];
            app.file_OpenFileButton.Layout.Column = 1;
            app.file_OpenFileButton.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Import_16.png');

            % Create Image
            app.Image = uiimage(app.file_toolGrid);
            app.Image.ScaleMethod = 'none';
            app.Image.Enable = 'off';
            app.Image.Layout.Row = [1 3];
            app.Image.Layout.Column = 2;
            app.Image.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV.svg');

            % Create file_MergeFiles
            app.file_MergeFiles = uiimage(app.file_toolGrid);
            app.file_MergeFiles.ImageClickedFcn = createCallbackFcn(app, @file_MergeFilesImageClicked, true);
            app.file_MergeFiles.Enable = 'off';
            app.file_MergeFiles.Tooltip = {'Mescla informação contábil'};
            app.file_MergeFiles.Layout.Row = [1 3];
            app.file_MergeFiles.Layout.Column = 4;
            app.file_MergeFiles.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Merge_32.png');

            % Create file_CheckRFB
            app.file_CheckRFB = uiimage(app.file_toolGrid);
            app.file_CheckRFB.ImageClickedFcn = createCallbackFcn(app, @file_CheckRFBClicked, true);
            app.file_CheckRFB.Enable = 'off';
            app.file_CheckRFB.Tooltip = {'Consulta à Receita Federal'};
            app.file_CheckRFB.Layout.Row = [1 3];
            app.file_CheckRFB.Layout.Column = 3;
            app.file_CheckRFB.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'receita-federal-novo-logo-png_seeklogo-203693.png');

            % Create TabGroup2
            app.TabGroup2 = uitabgroup(app.file_Grid);
            app.TabGroup2.AutoResizeChildren = 'off';
            app.TabGroup2.Layout.Row = 1;
            app.TabGroup2.Layout.Column = [2 5];

            % Create ARQUIVOSTab
            app.ARQUIVOSTab = uitab(app.TabGroup2);
            app.ARQUIVOSTab.AutoResizeChildren = 'off';
            app.ARQUIVOSTab.Title = '📄 ARQUIVOS';
            app.ARQUIVOSTab.BackgroundColor = 'none';

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.ARQUIVOSTab);
            app.GridLayout2.ColumnWidth = {'1x'};
            app.GridLayout2.RowHeight = {'1x'};
            app.GridLayout2.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create NOMEDAEMPRESAMetadadosOutrascoisasLabel
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel = uilabel(app.GridLayout2);
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.VerticalAlignment = 'top';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.WordWrap = 'on';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.FontSize = 11;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.FontColor = [0.149 0.149 0.149];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.Layout.Row = 1;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.Layout.Column = 1;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.Text = 'Este aplicativo permite a leitura de arquivos textuais da Escrituração Contábil Digital (ECD), organizando as informações por CNPJ e períodos fiscais. Também realiza a validação dos arquivos, verificando se os arquivos lidos são os que constam na base de dados da Receita Federal. E, por fim, possibilita anotação dos dados e geração de relatório de fiscalização.';

            % Create file_Metadata
            app.file_Metadata = uilabel(app.file_Grid);
            app.file_Metadata.VerticalAlignment = 'top';
            app.file_Metadata.WordWrap = 'on';
            app.file_Metadata.FontSize = 11;
            app.file_Metadata.Layout.Row = 3;
            app.file_Metadata.Layout.Column = 5;
            app.file_Metadata.Interpreter = 'html';
            app.file_Metadata.Text = '';

            % Create file_Tree
            app.file_Tree = uitree(app.file_Grid);
            app.file_Tree.Multiselect = 'on';
            app.file_Tree.SelectionChangedFcn = createCallbackFcn(app, @file_TreeSelectionChanged, true);
            app.file_Tree.FontSize = 10;
            app.file_Tree.Layout.Row = 3;
            app.file_Tree.Layout.Column = [2 3];

            % Create Tab2_Playback
            app.Tab2_Playback = uitab(app.TabGroup);
            app.Tab2_Playback.AutoResizeChildren = 'off';
            app.Tab2_Playback.BackgroundColor = 'none';

            % Create Tab5_RFDataHub
            app.Tab5_RFDataHub = uitab(app.TabGroup);
            app.Tab5_RFDataHub.BackgroundColor = 'none';

            % Create Tab6_Config
            app.Tab6_Config = uitab(app.TabGroup);
            app.Tab6_Config.BackgroundColor = 'none';

            % Create menu_Grid
            app.menu_Grid = uigridlayout(app.GridLayout);
            app.menu_Grid.ColumnWidth = {'1x', 28, 28, 5, 28, '1x'};
            app.menu_Grid.RowHeight = {7, 20, 7};
            app.menu_Grid.ColumnSpacing = 5;
            app.menu_Grid.RowSpacing = 0;
            app.menu_Grid.Padding = [10 5 5 5];
            app.menu_Grid.Tag = 'COLORLOCKED';
            app.menu_Grid.Layout.Row = 1;
            app.menu_Grid.Layout.Column = 1;
            app.menu_Grid.BackgroundColor = [0.2 0.2 0.2];

            % Create menu_Button1
            app.menu_Button1 = uibutton(app.menu_Grid, 'state');
            app.menu_Button1.ValueChangedFcn = createCallbackFcn(app, @menu_mainButtonPushed, true);
            app.menu_Button1.Tag = 'FILE';
            app.menu_Button1.Tooltip = {'Leitura de arquivos'};
            app.menu_Button1.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'OpenFile_32Yellow.png');
            app.menu_Button1.IconAlignment = 'top';
            app.menu_Button1.Text = '';
            app.menu_Button1.BackgroundColor = [0.2 0.2 0.2];
            app.menu_Button1.FontSize = 11;
            app.menu_Button1.Layout.Row = [1 3];
            app.menu_Button1.Layout.Column = 2;
            app.menu_Button1.Value = true;

            % Create menu_Button2
            app.menu_Button2 = uibutton(app.menu_Grid, 'state');
            app.menu_Button2.ValueChangedFcn = createCallbackFcn(app, @menu_mainButtonPushed, true);
            app.menu_Button2.Tag = 'ECD';
            app.menu_Button2.Enable = 'off';
            app.menu_Button2.Tooltip = {'Escrituração Contábil Digital'};
            app.menu_Button2.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'Playback_32White.png');
            app.menu_Button2.IconAlignment = 'top';
            app.menu_Button2.Text = '';
            app.menu_Button2.BackgroundColor = [0.2 0.2 0.2];
            app.menu_Button2.FontSize = 11;
            app.menu_Button2.Layout.Row = [1 3];
            app.menu_Button2.Layout.Column = 3;

            % Create menu_Separator2
            app.menu_Separator2 = uiimage(app.menu_Grid);
            app.menu_Separator2.ScaleMethod = 'none';
            app.menu_Separator2.Enable = 'off';
            app.menu_Separator2.Layout.Row = [1 3];
            app.menu_Separator2.Layout.Column = 4;
            app.menu_Separator2.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV_White.svg');

            % Create menu_Button4
            app.menu_Button4 = uibutton(app.menu_Grid, 'state');
            app.menu_Button4.ValueChangedFcn = createCallbackFcn(app, @menu_mainButtonPushed, true);
            app.menu_Button4.Tag = 'CONFIG';
            app.menu_Button4.Tooltip = {'Configurações gerais'};
            app.menu_Button4.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'Settings_36White.png');
            app.menu_Button4.IconAlignment = 'top';
            app.menu_Button4.Text = '';
            app.menu_Button4.BackgroundColor = [0.2 0.2 0.2];
            app.menu_Button4.FontSize = 11;
            app.menu_Button4.Layout.Row = [1 3];
            app.menu_Button4.Layout.Column = 5;

            % Create NOMEDAEMPRESAMetadadosOutrascoisasLabel_2
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2 = uilabel(app.menu_Grid);
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.WordWrap = 'on';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.FontSize = 9;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.FontColor = [1 1 1];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Layout.Row = [1 3];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Layout.Column = 1;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Interpreter = 'html';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Text = {'<font style="font-size: 11px; font-weight: bold;">monitorSPED</font> v. 1.0.0 '; 'R2024a'};

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.menu_Grid);
            app.GridLayout3.ColumnWidth = {'1x', 20, 20, 20, 20, 0, 0};
            app.GridLayout3.RowHeight = {'1x'};
            app.GridLayout3.ColumnSpacing = 5;
            app.GridLayout3.Padding = [0 0 0 0];
            app.GridLayout3.Tag = 'MenuSubGrid';
            app.GridLayout3.Layout.Row = 2;
            app.GridLayout3.Layout.Column = 6;
            app.GridLayout3.BackgroundColor = [0.2 0.2 0.2];

            % Create dockModule_Undock
            app.dockModule_Undock = uiimage(app.GridLayout3);
            app.dockModule_Undock.ScaleMethod = 'none';
            app.dockModule_Undock.ImageClickedFcn = createCallbackFcn(app, @menu_DockButtonPushed, true);
            app.dockModule_Undock.Tag = 'DRIVETEST';
            app.dockModule_Undock.Tooltip = {'Reabre módulo em outra janela'};
            app.dockModule_Undock.Layout.Row = 1;
            app.dockModule_Undock.Layout.Column = 6;
            app.dockModule_Undock.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Undock_18White.png');

            % Create dockModule_Close
            app.dockModule_Close = uiimage(app.GridLayout3);
            app.dockModule_Close.ScaleMethod = 'none';
            app.dockModule_Close.ImageClickedFcn = createCallbackFcn(app, @menu_DockButtonPushed, true);
            app.dockModule_Close.Tag = 'DRIVETEST';
            app.dockModule_Close.Tooltip = {'Fecha módulo'};
            app.dockModule_Close.Layout.Row = 1;
            app.dockModule_Close.Layout.Column = 7;
            app.dockModule_Close.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Delete_12SVG_white.svg');

            % Create DataHubLamp
            app.DataHubLamp = uilamp(app.GridLayout3);
            app.DataHubLamp.Enable = 'off';
            app.DataHubLamp.Visible = 'off';
            app.DataHubLamp.Tooltip = {'Pendente mapear pasta do Sharepoint'};
            app.DataHubLamp.Layout.Row = 1;
            app.DataHubLamp.Layout.Column = 3;
            app.DataHubLamp.Color = [1 0 0];

            % Create AppInfo
            app.AppInfo = uiimage(app.GridLayout3);
            app.AppInfo.ImageClickedFcn = createCallbackFcn(app, @menu_ToolbarImageCliced, true);
            app.AppInfo.Tooltip = {'Informações gerais'};
            app.AppInfo.Layout.Row = 1;
            app.AppInfo.Layout.Column = 5;
            app.AppInfo.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Dots_32White.png');

            % Create FigurePosition
            app.FigurePosition = uiimage(app.GridLayout3);
            app.FigurePosition.ImageClickedFcn = createCallbackFcn(app, @menu_ToolbarImageCliced, true);
            app.FigurePosition.Visible = 'off';
            app.FigurePosition.Tooltip = {'Reposiciona janela'};
            app.FigurePosition.Layout.Row = 1;
            app.FigurePosition.Layout.Column = 4;
            app.FigurePosition.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'layout1_32White.png');

            % Create jsBackDoor
            app.jsBackDoor = uihtml(app.GridLayout3);
            app.jsBackDoor.Layout.Row = 1;
            app.jsBackDoor.Layout.Column = 2;

            % Create popupContainerGrid
            app.popupContainerGrid = uigridlayout(app.GridLayout);
            app.popupContainerGrid.ColumnWidth = {'1x', 880, '1x'};
            app.popupContainerGrid.RowHeight = {'1x', 300, '1x'};
            app.popupContainerGrid.Layout.Row = 3;
            app.popupContainerGrid.Layout.Column = 1;
            app.popupContainerGrid.BackgroundColor = [1 1 1];

            % Create SplashScreen
            app.SplashScreen = uiimage(app.popupContainerGrid);
            app.SplashScreen.Layout.Row = 2;
            app.SplashScreen.Layout.Column = 2;
            app.SplashScreen.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'SplashScreen.gif');

            % Create file_ContextMenu_Tree
            app.file_ContextMenu_Tree = uicontextmenu(app.UIFigure);

            % Create file_ContextMenu_delTree1Node
            app.file_ContextMenu_delTree1Node = uimenu(app.file_ContextMenu_Tree);
            app.file_ContextMenu_delTree1Node.MenuSelectedFcn = createCallbackFcn(app, @file_ContextMenu_delTree1NodeSelected, true);
            app.file_ContextMenu_delTree1Node.ForegroundColor = [1 0 0];
            app.file_ContextMenu_delTree1Node.Text = 'Excluir';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = winMonitorSPED_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
