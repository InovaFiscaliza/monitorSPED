classdef winMonitorSPED_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        GridLayout                     matlab.ui.container.GridLayout
        popupContainerGrid             matlab.ui.container.GridLayout
        SplashScreen                   matlab.ui.control.Image
        menu_Grid                      matlab.ui.container.GridLayout
        jsBackDoor                     matlab.ui.control.HTML
        DataHubLamp                    matlab.ui.control.Image
        FigurePosition                 matlab.ui.control.Image
        AppInfo                        matlab.ui.control.Image
        menu_Button4                   matlab.ui.control.StateButton
        menu_Separator2                matlab.ui.control.Image
        menu_Button2                   matlab.ui.control.StateButton
        menu_Button1                   matlab.ui.control.StateButton
        menu_AppName                   matlab.ui.control.Label
        menu_AppIcon                   matlab.ui.control.Image
        TabGroup                       matlab.ui.container.TabGroup
        Tab1_File                      matlab.ui.container.Tab
        file_Grid                      matlab.ui.container.GridLayout
        file_Tree                      matlab.ui.container.Tree
        file_Metadata                  matlab.ui.control.Label
        TabGroup2                      matlab.ui.container.TabGroup
        ARQUIVOSTab                    matlab.ui.container.Tab
        GridLayout2                    matlab.ui.container.GridLayout
        Image                          matlab.ui.control.Image
        file_FileSortMethodIcon        matlab.ui.control.Image
        file_FileSortMethod            matlab.ui.control.DropDown
        file_ModuleIntro               matlab.ui.control.Label
        file_toolGrid                  matlab.ui.container.GridLayout
        tool_UploadFinalFile           matlab.ui.control.Image
        tool_GenerateReport            matlab.ui.control.Image
        tool_CheckRFB                  matlab.ui.control.Image
        tool_Separator2                matlab.ui.control.Image
        tool_MergeFiles                matlab.ui.control.Image
        tool_ReadFiles                 matlab.ui.control.Image
        tool_Separator1                matlab.ui.control.Image
        tool_SelectFilesToRead         matlab.ui.control.Image
        Tab2_Playback                  matlab.ui.container.Tab
        Tab3_Config                    matlab.ui.container.Tab
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
        popupContainer

        % Objeto que possibilita integração com o eFiscaliza.
        eFiscalizaObj

        %-----------------------------------------------------------------%
        % PROPRIEDADES ESPECÍFICAS
        %-----------------------------------------------------------------%
        projectData
        ecdObj = model.ECD.empty
        receitaFederalObj
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
                    % JSBACKDOOR (compCustomization.js)
                    case 'renderer'
                        startup_Controller(app)

                    case 'unload'
                        closeFcn(app)

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

                    case 'getNavigatorBasicInformation'
                        app.General.AppVersion.browser = event.HTMLEventData;

                    case 'getCssPropertyValue'
                        componentName = event.HTMLEventData.componentName;

                        if ~isempty(componentName)
                            if ~isprop(app, 'isDocked') % mainApp (app container)
                                auxAppTag = event.HTMLEventData.auxAppTag;
                                if ~isempty(auxAppTag)
                                    hAuxApp   = auxAppHandle(app, auxAppTag);
                                    objHandle = hAuxApp.(componentName);
                                else
                                    objHandle = eval(['app.' componentName]);
                                end
                            else
                                objHandle = eval(['app.' componentName]);
                            end
                            
                            cssProp  = event.HTMLEventData.propertyName;
                            cssValue = event.HTMLEventData.propertyValue;
    
                            if ~isprop(objHandle, 'StyleObservations')
                                objHandle.addprop('StyleObservations');
                            end
                            objHandle.StyleObservations.(cssProp) = cssValue;
                        end

                    % MAINAPP
                    case 'mainApp.file_Tree'
                        contextMenu_delTreeNodeSelected(app)

                    otherwise
                        error('UnexpectedEvent')
                end
                drawnow

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', getReport(ME));
            end
        end

        %-----------------------------------------------------------------%
        function varargout = ipcMainMatlabCallsHandler(app, callingApp, operationType, varargin)
            varargout = {};

            try
                switch class(callingApp)
                    % CONFIG
                    case {'auxApp.winConfig', 'auxApp.winConfig_exported'}
                        switch operationType
                            case 'closeFcn'
                                closeModule(app.tabGroupController, "CONFIG", app.General)
                            case 'dockButtonPushed'
                                auxAppTag = varargin{1};
                                varargout{1} = auxAppInputArguments(app, auxAppTag);
                            case 'checkDataHubLampStatus'
                                DataHubWarningLamp(app)
                            case 'openDevTools'
                                dialogBox    = struct('id', 'login',    'label', 'Usuário: ', 'type', 'text');
                                dialogBox(2) = struct('id', 'password', 'label', 'Senha: ',   'type', 'password');
                                sendEventToHTMLSource(app.jsBackDoor, 'customForm', struct('UUID', 'openDevTools', 'Fields', dialogBox))
                            case 'simulationModeChanged'
                                if app.General.operationMode.Simulation
                                    toolbar_SelectFileToReadImageClicked(app)

                                    % Muda programaticamente o modo p/ ARQUIVOS.
                                    set(app.menu_Button1, 'Enable', 1, 'Value', 1)                    
                                    menu_mainButtonPushed(app, struct('Source', app.menu_Button1, 'PreviousValue', false))
                                end
                            case 'fileSortMethodChanged'
                                if ~strcmp(app.file_FileSortMethod.Value, app.General.File.sortMethod)
                                    app.file_FileSortMethod.Value = app.General.File.sortMethod;
                                    file_FileSortMethodValueChanged(app)
                                end
                            otherwise
                                error('UnexpectedCall')
                        end

                    % ECD
                    case {'auxApp.winECD', 'auxApp.winECD_exported'}
                        switch operationType
                            case 'closeFcn'
                                closeModule(app.tabGroupController, "ECD", app.General)
                            case 'dockButtonPushed'
                                auxAppTag = varargin{1};
                                varargout{1} = auxAppInputArguments(app, auxAppTag);
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

                    customizationStatus(tabIndex) = true;
                    switch tabIndex
                        case 1 % FILE
                            elToModify = {app.popupContainerGrid,  ...
                                          app.file_Tree,           ...                                          
                                          app.file_Metadata};                % ui.TextView
                            elDataTag  = ui.CustomizationBase.getElementsDataTag(elToModify);

                            if ~isempty(elDataTag)
                                appName = class(app);
                                
                                sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                                    struct('appName', appName, 'dataTag', elDataTag{1}, 'style', struct('backgroundColor', 'rgba(255,255,255,0.65)')), ...
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

            if ~ismember(app.General_I.File.input, {'file', 'folder'})
                app.General_I.File.input = 'file';
            end

            if ~ismember(app.General_I.File.sortMethod, {'CNPJ', 'PERÍODO FISCAL', 'RECEITA FEDERAL'})
                app.General_I.File.sortMethod = 'CNPJ';
            end

            if ~ismember(app.General_I.File.checkStatus, {'OnlyCache', 'Cache+RealTime', 'RealTime'})
                app.General_I.File.checkStatus = 'Cache+RealTime';
            end

            switch app.executionMode
                case 'webApp'
                    % Força a exclusão do SplashScreen do MATLAB Web Server.
                    sendEventToHTMLSource(app.jsBackDoor, "delProgressDialog");

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
            app.General.AppVersion = util.getAppVersion(app.rootFolder, MFilePath, tempDir);
            sendEventToHTMLSource(app.jsBackDoor, 'getNavigatorBasicInformation')
        end

        %-----------------------------------------------------------------%
        function startup_AppProperties(app)
            % app.projectData
            app.projectData = model.projectLib(app, app.rootFolder);

            % app.receitaFederalObj
            app.receitaFederalObj = ws.ReceitaFederal();
        end

        %-----------------------------------------------------------------%
        function startup_GUIComponents(app)
            % Objeto que conecta o TabGroup ao GraphicMenu.
            app.tabGroupController = tabGroupGraphicMenu(app.menu_Grid, app.TabGroup, app.progressDialog, @app.jsBackDoor_Customizations, []);
            addComponent(app.tabGroupController, "Built-in", "",                      app.menu_Button1, "AlwaysOn", struct('On', 'OpenFile_32Yellow.png', 'Off', 'OpenFile_32White.png'), matlab.graphics.GraphicsPlaceholder, 1)
            addComponent(app.tabGroupController, "External", "auxApp.winECD",         app.menu_Button2, "AlwaysOn", struct('On', 'Zoom_32Yellow.png',     'Off', 'Zoom_32White.png'),     app.menu_Button1,                    2)
            addComponent(app.tabGroupController, "External", "auxApp.winConfig",      app.menu_Button4, "AlwaysOn", struct('On', 'Settings_36Yellow.png', 'Off', 'Settings_36White.png'), app.menu_Button1,                    3)

            DataHubWarningLamp(app)
            app.file_FileSortMethod.Value = app.General.File.sortMethod;
            addStyle(app.file_Tree, uistyle('Interpreter', 'html'))
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
        function file_TreeBuilding(app, selectedNodeData)
            arguments
                app
                selectedNodeData = []
            end

            if ~isempty(app.file_Tree.Children)
                app.file_Metadata.UserData = [];
                delete(app.file_Tree.Children)
            end

            idsList = {app.ecdObj.CompanyId};
            selectedNode = [];
            
            if ~isempty(idsList)
                ids = unique(idsList);

                switch app.file_FileSortMethod.Value
                    case 'CNPJ'
                        selectedNode = file_createTreeElements(app, idsList, ids, selectedNode, selectedNodeData);
                    otherwise
                        switch app.file_FileSortMethod.Value
                            case 'PERÍODO FISCAL'
                                validTreeNodeText = '<font style="color: blue; font-weight: bold; text-decoration: underline;">VÁLIDOS</font> EM RELAÇÃO AO CRITÉRIO "PERÍODO FISCAL ANUAL"';
                            case 'RECEITA FEDERAL'
                                validTreeNodeText = '<font style="color: blue; font-weight: bold; text-decoration: underline;">VÁLIDOS</font> EM RELAÇÃO AO CRITÉRIO "ARQUIVO CONSTA NA BASE DA RECEITA FEDERAL"';
                        end
                        validTreeNode   = uitreenode(app.file_Tree, 'Text', validTreeNodeText);
                        selectedNode    = file_createTreeElements(app, idsList, ids, selectedNode, selectedNodeData, validTreeNode,   'only-valid');
                        
                        invalidTreeNode = uitreenode(app.file_Tree, 'Text', '<font style="color: red; font-weight: bold; text-decoration: underline;">INVÁLIDOS</font>');
                        selectedNode    = file_createTreeElements(app, idsList, ids, selectedNode, selectedNodeData, invalidTreeNode, 'only-invalid');
                end
            end

            expand(app.file_Tree, 'all')

            if ~isempty(app.file_Tree.Children)
                if ~isempty(selectedNode)
                    app.file_Tree.SelectedNodes = selectedNode;
                else
                    if isempty(app.file_Tree.Children(1).Children)
                        app.file_Tree.SelectedNodes = app.file_Tree.Children(1);
                    else
                        app.file_Tree.SelectedNodes = app.file_Tree.Children(1).Children(1);
                    end
                end
            end

            file_TreeSelectionChanged(app)
        end

        %-----------------------------------------------------------------%
        function selectedNode = file_createTreeElements(app, idsList, ids, selectedNode, selectedNodeData, varargin)
            arguments
                app 
                idsList 
                ids 
                selectedNode
                selectedNodeData
            end

            arguments (Repeating)
                varargin
            end

            switch app.file_FileSortMethod.Value
                case 'CNPJ'
                    parentNode = app.file_Tree;
                otherwise
                    parentNode = varargin{1};
                    requiredStatus = varargin{2};
            end

            for id = ids
                % Identifica fluxos relacionados a cada CNPJ, ordenando os 
                % fluxos de acordo com a data de fim do seu período fiscal.
                idIndexes   = find(strcmp(idsList, id));
                [~, idSort] = sort(arrayfun(@(x) x.Period(2), app.ecdObj(idIndexes)));
                idIndexes   = idIndexes(idSort);

                % Aplica filtro, caso construção da árvore seja orientada
                % ao "PERÍODO FISCAL" ou à "RECEITA FEDERAL".
                if ismember(app.file_FileSortMethod.Value, {'PERÍODO FISCAL', 'RECEITA FEDERAL'})
                    for ii = numel(idIndexes):-1:1
                        index = idIndexes(ii);
    
                        switch app.file_FileSortMethod.Value
                            case 'PERÍODO FISCAL'
                                validFile = checkIfValidPeriod(app.ecdObj(index));
                            case 'RECEITA FEDERAL'
                                validFile = checkIfValidStatus(app.ecdObj(index));
                        end
    
                        if strcmp(requiredStatus, 'only-valid') && ~validFile
                            idIndexes(ii) = [];
                        elseif strcmp(requiredStatus, 'only-invalid') && validFile
                            idIndexes(ii) = [];
                        end
                    end
    
                    if isempty(idIndexes)
                        continue
                    end
                end

                textCompanyNode = generateTextId(app.ecdObj(idIndexes(1)), 'company-oriented');
                treeCompanyNode = uitreenode(parentNode, ...
                    'Text', textCompanyNode, ...
                    'NodeData', idIndexes, 'ContextMenu', app.file_ContextMenu_Tree);
    
                for idx = idIndexes
                    textPeriodNode = generateTextId(app.ecdObj(idx), 'period-oriented', true);
                    treePeriodNode = uitreenode(treeCompanyNode, ...
                        'Text', textPeriodNode, ...
                        'NodeData', idx, 'ContextMenu', app.file_ContextMenu_Tree);
    
                    if ismember(idx, selectedNodeData)
                        selectedNode = [selectedNode, treePeriodNode];
                    end
                end
            end
        end

        %-----------------------------------------------------------------%
        function indexes = file_findSelectedNodeData(app)
            indexes = [];
            if ~isempty(app.file_Tree.SelectedNodes)
                indexes = unique([app.file_Tree.SelectedNodes.NodeData]);
            end
        end

        %-----------------------------------------------------------------%
        function updateLastVisitedFolder(app, filePath)
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
        function userSelection = checkIfAuxiliarAppIsOpen(app, operationType)
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
                app.GridLayout.RowHeight(end) = [];

                app.menu_AppName.Text = sprintf('%s v. %s\n<font style="font-size: 9px;">%s</font>', ...
                    class.Constants.appName, class.Constants.appVersion, class.Constants.appRelease);
                % </GUI>

                appUtil.winPosition(app.UIFigure)
                startup_timerCreation(app)

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end
            
        end

        % Close request function: UIFigure
        function closeFcn(app, event)

            if strcmp(app.progressDialog.Visible, 'visible')
                app.progressDialog.Visible = 'hidden';
                return
            end

            if ~strcmp(app.executionMode, 'webApp') && ~isempty(app.ecdObj)
                msgQuestion   = 'Deseja fechar o aplicativo?';
                userSelection = appUtil.modalWindow(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 1, 2);
                if userSelection == "Não"
                    return
                end
            end

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

        % Selection changed function: file_Tree
        function file_TreeSelectionChanged(app, event)
            
            indexes = file_findSelectedNodeData(app);
            
            if isempty(indexes)
                app.file_Metadata.Text         = '';
                app.file_Metadata.UserData     = [];
                
                app.tool_ReadFiles.Enable      = 0;
                app.tool_MergeFiles.Enable     = 0;
                app.tool_CheckRFB.Enable       = 0;
                app.tool_GenerateReport.Enable = 0;

            else
                if isequal(app.file_Metadata.UserData, indexes)
                    return
                end

                app.file_Metadata.Text         = util.HtmlTextGenerator.File(app.ecdObj(indexes));
                app.file_Metadata.UserData     = indexes;

                app.tool_ReadFiles.Enable      = 1;
                app.tool_CheckRFB.Enable       = 1;
                app.tool_GenerateReport.Enable = 1;

                if isscalar(indexes)
                    app.tool_MergeFiles.Enable = 0;
                else
                    app.tool_MergeFiles.Enable = 1;
                end
            end

            if isempty(app.ecdObj)
                app.menu_Button2.Enable = 0;
            else
                app.menu_Button2.Enable = 1;
            end
            
        end

        % Value changed function: file_FileSortMethod
        function file_FileSortMethodValueChanged(app, event)
            
            indexes = file_findSelectedNodeData(app);
            file_TreeBuilding(app, indexes)

        end

        % Image clicked function: tool_SelectFilesToRead
        function toolbar_SelectFileToReadImageClicked(app, event)

            % VALIDAÇÃO
            if strcmp(checkIfAuxiliarAppIsOpen(app, 'INCLUIR ARQUIVO'), 'Não')
                return
            end

            d = [];
            fileFullName = {};

            if app.General.operationMode.Simulation
                app.General.operationMode.Simulation = false;
                
                [projectFolder, ...
                 programDataFolder] = appUtil.Path(class.Constants.appName, app.rootFolder);
                simulationFolders   = {programDataFolder, projectFolder};

                for ii = 1:numel(simulationFolders)
                    filePath    = fullfile(simulationFolders{ii}, 'Simulation');    
                    listOfFiles = dir(filePath);
                    fileName    = {listOfFiles.name};
                    fileName    = fileName(endsWith(lower(fileName), '.txt'));
                    
                    if ~isempty(fileName)
                        fileFullName = fullfile(filePath, fileName);
                        break
                    end
                end

                if isempty(fileFullName)
                    msgWarning = 'Nenhum arquivo de simulação foi identificado.';
                    appUtil.modalWindow(app.UIFigure, "warning", msgWarning);
                    return
                end

            else
                switch app.General.File.input
                    case 'file'
                        [fileName, filePath] = uigetfile({'*.txt';'*.csv';'*.mat';'*.*'}, ...
                                                          '', app.General.fileFolder.lastVisited, 'MultiSelect', 'on');
                        figure(app.UIFigure)
            
                        if isequal(fileName, 0)
                            return
                        elseif ~iscellstr(fileName)
                            fileName = cellstr(fileName);
                        end
                        fileFullName = fullfile(filePath, fileName);
    
                    case 'folder'
                        filePath = uigetdir(app.General.fileFolder.lastVisited);
                        figure(app.UIFigure)
    
                        if isequal(filePath, 0)
                            return
                        end
    
                        d = appUtil.modalWindow(app.UIFigure, "progressdlg", "Em andamento...");
                        [fileFullName, fileName] = util.getFilesFromFolder(filePath);
                end
                updateLastVisitedFolder(app, filePath)
            end

            if isempty(d)
                d = appUtil.modalWindow(app.UIFigure, "progressdlg", "Em andamento...");
            end
            
            filesError = struct('File', {}, 'Error', {});

            for ii = 1:numel(fileFullName)
                d.Message = sprintf('Em andamento a leitura do arquivo %d de %d:<br>• <b>%s</b>', ii, numel(fileFullName), fileName{ii});

                % Verifica se arquivo já foi lido, comparando o seu nome com 
                % a variável app.ecdObj.
                if ~ismember(fileName{ii}, {app.ecdObj.FileName})
                    [app.ecdObj, msg] = app.ecdObj.addFiles(fileFullName{ii}, [], app.receitaFederalObj);

                    if ~isempty(msg)
                        filesError(end+1) = struct('File', sprintf('"%s"', fileName{ii}), 'Error', strjoin(msg));
                        continue
                    end
                end
            end

            % LOG
            if ~isempty(filesError)
                msgWarning = sprintf('Arquivos que apresentaram erro na leitura:\n%s\n\n', strjoin(strcat({'•&thinsp;<b>'}, {filesError.File}, {'</b>: <i>'}, {filesError.Error}), '</i>\n\n'));
                appUtil.modalWindow(app.UIFigure, "error", msgWarning);
            end
            
            % Atualiza app.file_Tree.
            indexes = file_findSelectedNodeData(app);
            file_TreeBuilding(app, indexes)

            delete(d)

        end

        % Image clicked function: tool_ReadFiles
        function toolbar_ReadFilesImageClicked(app, event)
            
            d = appUtil.modalWindow(app.UIFigure, "progressdlg", textFormatGUI.HTMLParagraph('Em andamento...'));

            switch event.Source
                case app.tool_ReadFiles
                    indexes = file_findSelectedNodeData(app);
                case app.tool_GenerateReport
                    indexes = event.Indexes;
                otherwise
                    error('UnexpectedCaller')
            end

            warnings = {};
            for ii = 1:numel(indexes)
                d.Message = textFormatGUI.HTMLParagraph(sprintf('Em andamento a leitura dos registros do arquivo %d de %d:<br>• <b>%s</b>', ii, numel(indexes), app.ecdObj(indexes(ii)).FileName));
                parseTableAndAddToCache(app.ecdObj(indexes(ii)))

                if ~isempty(app.ecdObj(indexes(ii)).GUI.warnings)
                    warnings{end+1} = sprintf('• <b>%s</b><br>%s', app.ecdObj(indexes(ii)).FileName, strjoin(app.ecdObj(indexes(ii)).GUI.warnings, '<br>'));
                end
            end
            file_TreeBuilding(app, indexes)

            if event.Source == app.tool_ReadFiles && ~isempty(warnings)
                msgWarning = ['Alarme(s) gerado(s) no processo de leitura do(s) arquivo(s):<br>', strjoin(warnings, '<br>')];
                appUtil.modalWindow(app.UIFigure, "warning", msgWarning);
            end

            delete(d)

        end

        % Image clicked function: tool_MergeFiles
        function toolbar_MergeFilesImageClicked(app, event)

            indexes = file_findSelectedNodeData(app);

            if numel(indexes) >= 2
                if ~isscalar(unique({app.ecdObj(indexes).CompanyId}))
                    appUtil.modalWindow(app.UIFigure, 'info', 'A mesclagem é aplicável apenas a registros de uma mesma empresa.');
                    return
                end

                if strcmp(checkIfAuxiliarAppIsOpen(app, 'MESCLAR FLUXOS'), 'Não')
                    return
                end

                app.progressDialog.Visible = 'visible';

                [app.ecdObj, msg] = mergeFiles(app.ecdObj, indexes, app.General.fileFolder.tempPath);
                if isempty(msg)
                    file_TreeBuilding(app, indexes)
                else
                    appUtil.modalWindow(app.UIFigure, "error", msg); 
                end

                app.progressDialog.Visible = 'hidden';
            end

        end

        % Image clicked function: tool_CheckRFB
        function toolbar_CheckStatusImageClicked(app, event)
            
            indexes = file_findSelectedNodeData(app);

            if ~isempty(indexes)
                if all([app.ecdObj(indexes).PeriodMerged])
                    appUtil.modalWindow(app.UIFigure, 'info', 'Consulta à Receita Federal não é aplicável a registro mesclado.');
                    return
                end

                app.progressDialog.Visible = 'visible';

                checkFileFlag = checkFileStatus(app.ecdObj(indexes), app.receitaFederalObj, app.General.File.checkStatus);
                if checkFileFlag
                    file_TreeBuilding(app, indexes)
                end

                app.progressDialog.Visible = 'hidden';
            end

        end

        % Image clicked function: tool_GenerateReport
        function toolbar_GenerateReportImageClicked(app, event)
            
            indexes = file_findSelectedNodeData(app);

            if ~isempty(indexes)
                % <VALIDAÇÕES>
                if numel(indexes) < numel(app.ecdObj)
                    msgQuestion   = 'Deseja gerar inventário de TODOS os arquivos lidos, ou apenas do SELECIONADO?';
                    userSelection = appUtil.modalWindow(app.UIFigure, 'uiconfirm', msgQuestion, {'Todos', 'Selecionado', 'Cancelar'}, 1, 3);

                    switch userSelection
                        case 'Cancelar'
                            return
                        case 'Todos'
                            indexes = 1:numel(app.ecdObj);
                    end
                end
                % </VALIDAÇÕES>

                % <PROCESSO>
                toolbar_ReadFilesImageClicked(app, struct('Source', app.tool_GenerateReport, 'Indexes', indexes))

                app.progressDialog.Visible = 'visible';

                try
                    reportSettings = struct('system', 'eFiscaliza', ...
                                            'unit',   '',           ...
                                            'issue',  -1,           ...
                                            'model',  'Inventário de arquivos', ...
                                            'reportVersion', 'Preliminar');
                    reportLibConnection.Controller.Run(app, app.projectData, app.ecdObj(indexes), reportSettings, app.General)
                catch ME
                    appUtil.modalWindow(app.UIFigure, 'error', getReport(ME));
                end

                app.progressDialog.Visible = 'hidden';
                % </PROCESSO>
            end

        end

        % Image clicked function: Image
        function toolbar_ShowLegendImageClicked(app, event)
            
            msg = ['Em relação à situação:<br>' ...
                   '&#x1F7E2; Registro encontrado na base da Receita Federal<br>' ...
                   '&#x1F534; Registro não encontrado na base da Receita Federal<br>' ...
                   '⚪ Situação indeterminada<br><br>' ...
                   'Em relação à mesclagem:<br>' ...
                   '➕ Registro mesclado<br>' ...
                   '⌛ Período fiscal não anual<br><br>' ...
                   'Em relação à leitura:<br>' ...
                   '✅ Registros ordinários já lidos<br>' ...
                   '❗ Pendente leitura de todos os registros ordinários<br>' ...
                   '❌ Erro de validação'];

            appUtil.modalWindow(app.UIFigure, 'none', msg);

        end

        % Menu selected function: file_ContextMenu_delTree1Node
        function contextMenu_delTreeNodeSelected(app, event)
            
            indexes = file_findSelectedNodeData(app);

            if ~isempty(indexes)
                % VALIDAÇÃO
                if strcmp(checkIfAuxiliarAppIsOpen(app, 'EXCLUIR ARQUIVO'), 'Não')
                    return
                end

                % EXCLUIR ARQUIVO(S)                
                app.ecdObj(indexes) = [];
                file_TreeBuilding(app)
            end

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
            app.UIFigure.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'icon_16.png');
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeFcn, true);
            app.UIFigure.HandleVisibility = 'on';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {54, '1x', 44};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Tag = 'winMonitorSPED';
            app.GridLayout.Tooltip = {''};
            app.GridLayout.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.Layout.Row = [1 2];
            app.TabGroup.Layout.Column = 1;

            % Create Tab1_File
            app.Tab1_File = uitab(app.TabGroup);
            app.Tab1_File.AutoResizeChildren = 'off';
            app.Tab1_File.BackgroundColor = 'none';
            app.Tab1_File.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create file_Grid
            app.file_Grid = uigridlayout(app.Tab1_File);
            app.file_Grid.ColumnWidth = {10, 360, '1x', 10, '0.25x', 360, 10};
            app.file_Grid.RowHeight = {94, 10, '1x', 10, 34};
            app.file_Grid.ColumnSpacing = 0;
            app.file_Grid.RowSpacing = 0;
            app.file_Grid.Padding = [0 0 0 40];
            app.file_Grid.BackgroundColor = [1 1 1];

            % Create file_toolGrid
            app.file_toolGrid = uigridlayout(app.file_Grid);
            app.file_toolGrid.ColumnWidth = {22, 5, 22, 22, 5, 22, '1x', 22, 22};
            app.file_toolGrid.RowHeight = {4, 17, '1x'};
            app.file_toolGrid.ColumnSpacing = 5;
            app.file_toolGrid.RowSpacing = 0;
            app.file_toolGrid.Padding = [10 5 10 5];
            app.file_toolGrid.Layout.Row = 5;
            app.file_toolGrid.Layout.Column = [1 7];
            app.file_toolGrid.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];

            % Create tool_SelectFilesToRead
            app.tool_SelectFilesToRead = uiimage(app.file_toolGrid);
            app.tool_SelectFilesToRead.ScaleMethod = 'none';
            app.tool_SelectFilesToRead.ImageClickedFcn = createCallbackFcn(app, @toolbar_SelectFileToReadImageClicked, true);
            app.tool_SelectFilesToRead.Tooltip = {'Seleciona arquivos'};
            app.tool_SelectFilesToRead.Layout.Row = [1 3];
            app.tool_SelectFilesToRead.Layout.Column = 1;
            app.tool_SelectFilesToRead.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Import_16.png');

            % Create tool_Separator1
            app.tool_Separator1 = uiimage(app.file_toolGrid);
            app.tool_Separator1.ScaleMethod = 'none';
            app.tool_Separator1.Enable = 'off';
            app.tool_Separator1.Layout.Row = [1 3];
            app.tool_Separator1.Layout.Column = 2;
            app.tool_Separator1.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV.svg');

            % Create tool_ReadFiles
            app.tool_ReadFiles = uiimage(app.file_toolGrid);
            app.tool_ReadFiles.ScaleMethod = 'none';
            app.tool_ReadFiles.ImageClickedFcn = createCallbackFcn(app, @toolbar_ReadFilesImageClicked, true);
            app.tool_ReadFiles.Enable = 'off';
            app.tool_ReadFiles.Tooltip = {'Leitura de todos os registros ordinários'};
            app.tool_ReadFiles.Layout.Row = 2;
            app.tool_ReadFiles.Layout.Column = 3;
            app.tool_ReadFiles.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'run_all_tests_16.png');

            % Create tool_MergeFiles
            app.tool_MergeFiles = uiimage(app.file_toolGrid);
            app.tool_MergeFiles.ImageClickedFcn = createCallbackFcn(app, @toolbar_MergeFilesImageClicked, true);
            app.tool_MergeFiles.Enable = 'off';
            app.tool_MergeFiles.Tooltip = {'Mescla informação contábil'};
            app.tool_MergeFiles.Layout.Row = [1 3];
            app.tool_MergeFiles.Layout.Column = 4;
            app.tool_MergeFiles.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Merge_32.png');

            % Create tool_Separator2
            app.tool_Separator2 = uiimage(app.file_toolGrid);
            app.tool_Separator2.ScaleMethod = 'none';
            app.tool_Separator2.Enable = 'off';
            app.tool_Separator2.Layout.Row = [1 3];
            app.tool_Separator2.Layout.Column = 5;
            app.tool_Separator2.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV.svg');

            % Create tool_CheckRFB
            app.tool_CheckRFB = uiimage(app.file_toolGrid);
            app.tool_CheckRFB.ImageClickedFcn = createCallbackFcn(app, @toolbar_CheckStatusImageClicked, true);
            app.tool_CheckRFB.Enable = 'off';
            app.tool_CheckRFB.Tooltip = {'Consulta à Receita Federal'};
            app.tool_CheckRFB.Layout.Row = [1 3];
            app.tool_CheckRFB.Layout.Column = 6;
            app.tool_CheckRFB.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'receita-federal-novo-logo-png_seeklogo-203693.png');

            % Create tool_GenerateReport
            app.tool_GenerateReport = uiimage(app.file_toolGrid);
            app.tool_GenerateReport.ScaleMethod = 'none';
            app.tool_GenerateReport.ImageClickedFcn = createCallbackFcn(app, @toolbar_GenerateReportImageClicked, true);
            app.tool_GenerateReport.Enable = 'off';
            app.tool_GenerateReport.Tooltip = {'Gera relatório'; '(estado escrituração na Receita Federal)'};
            app.tool_GenerateReport.Layout.Row = [1 3];
            app.tool_GenerateReport.Layout.Column = 8;
            app.tool_GenerateReport.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Publish_HTML_16.png');

            % Create tool_UploadFinalFile
            app.tool_UploadFinalFile = uiimage(app.file_toolGrid);
            app.tool_UploadFinalFile.Enable = 'off';
            app.tool_UploadFinalFile.Tooltip = {'Upload relatório'};
            app.tool_UploadFinalFile.Layout.Row = 2;
            app.tool_UploadFinalFile.Layout.Column = 9;
            app.tool_UploadFinalFile.ImageSource = 'Up_24.png';

            % Create TabGroup2
            app.TabGroup2 = uitabgroup(app.file_Grid);
            app.TabGroup2.AutoResizeChildren = 'off';
            app.TabGroup2.Layout.Row = 1;
            app.TabGroup2.Layout.Column = [2 6];

            % Create ARQUIVOSTab
            app.ARQUIVOSTab = uitab(app.TabGroup2);
            app.ARQUIVOSTab.AutoResizeChildren = 'off';
            app.ARQUIVOSTab.Title = 'ARQUIVOS';
            app.ARQUIVOSTab.BackgroundColor = 'none';
            app.ARQUIVOSTab.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.ARQUIVOSTab);
            app.GridLayout2.ColumnWidth = {22, 150, '1x', 22};
            app.GridLayout2.RowHeight = {22, 22};
            app.GridLayout2.ColumnSpacing = 5;
            app.GridLayout2.RowSpacing = 5;
            app.GridLayout2.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create file_ModuleIntro
            app.file_ModuleIntro = uilabel(app.GridLayout2);
            app.file_ModuleIntro.VerticalAlignment = 'top';
            app.file_ModuleIntro.WordWrap = 'on';
            app.file_ModuleIntro.FontSize = 11;
            app.file_ModuleIntro.FontColor = [0.149 0.149 0.149];
            app.file_ModuleIntro.Layout.Row = 1;
            app.file_ModuleIntro.Layout.Column = [1 4];
            app.file_ModuleIntro.Text = 'Este aplicativo permite a leitura de arquivos textuais da Escrituração Contábil Digital (ECD) e a sua análise.';

            % Create file_FileSortMethod
            app.file_FileSortMethod = uidropdown(app.GridLayout2);
            app.file_FileSortMethod.Items = {'CNPJ', 'PERÍODO FISCAL', 'RECEITA FEDERAL'};
            app.file_FileSortMethod.ValueChangedFcn = createCallbackFcn(app, @file_FileSortMethodValueChanged, true);
            app.file_FileSortMethod.FontSize = 10;
            app.file_FileSortMethod.BackgroundColor = [0.9804 0.9804 0.9804];
            app.file_FileSortMethod.Layout.Row = 2;
            app.file_FileSortMethod.Layout.Column = 2;
            app.file_FileSortMethod.Value = 'CNPJ';

            % Create file_FileSortMethodIcon
            app.file_FileSortMethodIcon = uiimage(app.GridLayout2);
            app.file_FileSortMethodIcon.ScaleMethod = 'none';
            app.file_FileSortMethodIcon.Layout.Row = 2;
            app.file_FileSortMethodIcon.Layout.Column = 1;
            app.file_FileSortMethodIcon.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'sort_az_ascending.png');

            % Create Image
            app.Image = uiimage(app.GridLayout2);
            app.Image.ScaleMethod = 'none';
            app.Image.ImageClickedFcn = createCallbackFcn(app, @toolbar_ShowLegendImageClicked, true);
            app.Image.Tooltip = {'Legenda de símbolos'};
            app.Image.Layout.Row = 2;
            app.Image.Layout.Column = 4;
            app.Image.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Legend_16.png');

            % Create file_Metadata
            app.file_Metadata = uilabel(app.file_Grid);
            app.file_Metadata.VerticalAlignment = 'top';
            app.file_Metadata.WordWrap = 'on';
            app.file_Metadata.FontSize = 11;
            app.file_Metadata.Layout.Row = 3;
            app.file_Metadata.Layout.Column = [5 6];
            app.file_Metadata.Interpreter = 'html';
            app.file_Metadata.Text = '';

            % Create file_Tree
            app.file_Tree = uitree(app.file_Grid);
            app.file_Tree.Multiselect = 'on';
            app.file_Tree.SelectionChangedFcn = createCallbackFcn(app, @file_TreeSelectionChanged, true);
            app.file_Tree.FontSize = 11;
            app.file_Tree.Layout.Row = 3;
            app.file_Tree.Layout.Column = [2 3];

            % Create Tab2_Playback
            app.Tab2_Playback = uitab(app.TabGroup);
            app.Tab2_Playback.AutoResizeChildren = 'off';
            app.Tab2_Playback.BackgroundColor = 'none';
            app.Tab2_Playback.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create Tab3_Config
            app.Tab3_Config = uitab(app.TabGroup);
            app.Tab3_Config.AutoResizeChildren = 'off';
            app.Tab3_Config.BackgroundColor = 'none';
            app.Tab3_Config.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create menu_Grid
            app.menu_Grid = uigridlayout(app.GridLayout);
            app.menu_Grid.ColumnWidth = {22, 74, '1x', 34, 34, 5, 34, '1x', 20, 20, 1, 20, 20};
            app.menu_Grid.RowHeight = {5, 7, 20, 7, 5};
            app.menu_Grid.ColumnSpacing = 5;
            app.menu_Grid.RowSpacing = 0;
            app.menu_Grid.Padding = [10 5 5 5];
            app.menu_Grid.Tag = 'COLORLOCKED';
            app.menu_Grid.Layout.Row = 1;
            app.menu_Grid.Layout.Column = 1;
            app.menu_Grid.BackgroundColor = [0.2 0.2 0.2];

            % Create menu_AppIcon
            app.menu_AppIcon = uiimage(app.menu_Grid);
            app.menu_AppIcon.ScaleMethod = 'none';
            app.menu_AppIcon.Layout.Row = [1 5];
            app.menu_AppIcon.Layout.Column = 1;
            app.menu_AppIcon.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'deleteEntireRow_16-aa465db167fbf7f8e67f1c8f29834ebd.png');

            % Create menu_AppName
            app.menu_AppName = uilabel(app.menu_Grid);
            app.menu_AppName.WordWrap = 'on';
            app.menu_AppName.FontSize = 11;
            app.menu_AppName.FontColor = [1 1 1];
            app.menu_AppName.Layout.Row = [1 5];
            app.menu_AppName.Layout.Column = [2 3];
            app.menu_AppName.Interpreter = 'html';
            app.menu_AppName.Text = {'monitorSPED v. 1.0.0'; '<font style="font-size: 9px;">R2024a</font>'};

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
            app.menu_Button1.Layout.Row = [2 4];
            app.menu_Button1.Layout.Column = 4;
            app.menu_Button1.Value = true;

            % Create menu_Button2
            app.menu_Button2 = uibutton(app.menu_Grid, 'state');
            app.menu_Button2.ValueChangedFcn = createCallbackFcn(app, @menu_mainButtonPushed, true);
            app.menu_Button2.Tag = 'ECD';
            app.menu_Button2.Enable = 'off';
            app.menu_Button2.Tooltip = {'Escrituração Contábil Digital'};
            app.menu_Button2.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'Zoom_32White.png');
            app.menu_Button2.IconAlignment = 'top';
            app.menu_Button2.Text = '';
            app.menu_Button2.BackgroundColor = [0.2 0.2 0.2];
            app.menu_Button2.FontSize = 11;
            app.menu_Button2.Layout.Row = [2 4];
            app.menu_Button2.Layout.Column = 5;

            % Create menu_Separator2
            app.menu_Separator2 = uiimage(app.menu_Grid);
            app.menu_Separator2.ScaleMethod = 'none';
            app.menu_Separator2.Enable = 'off';
            app.menu_Separator2.Layout.Row = [2 4];
            app.menu_Separator2.Layout.Column = 6;
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
            app.menu_Button4.Layout.Row = [2 4];
            app.menu_Button4.Layout.Column = 7;

            % Create AppInfo
            app.AppInfo = uiimage(app.menu_Grid);
            app.AppInfo.ImageClickedFcn = createCallbackFcn(app, @menu_ToolbarImageCliced, true);
            app.AppInfo.Tooltip = {'Informações gerais'};
            app.AppInfo.Layout.Row = 3;
            app.AppInfo.Layout.Column = 13;
            app.AppInfo.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Dots_32White.png');

            % Create FigurePosition
            app.FigurePosition = uiimage(app.menu_Grid);
            app.FigurePosition.ImageClickedFcn = createCallbackFcn(app, @menu_ToolbarImageCliced, true);
            app.FigurePosition.Visible = 'off';
            app.FigurePosition.Tooltip = {'Reposiciona janela'};
            app.FigurePosition.Layout.Row = 3;
            app.FigurePosition.Layout.Column = 12;
            app.FigurePosition.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'layout1_32White.png');

            % Create DataHubLamp
            app.DataHubLamp = uiimage(app.menu_Grid);
            app.DataHubLamp.Visible = 'off';
            app.DataHubLamp.Tooltip = {'Pendente mapear o Sharepoint'};
            app.DataHubLamp.Layout.Row = 3;
            app.DataHubLamp.Layout.Column = 10;
            app.DataHubLamp.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'red-circle-blink.gif');

            % Create jsBackDoor
            app.jsBackDoor = uihtml(app.menu_Grid);
            app.jsBackDoor.Layout.Row = 3;
            app.jsBackDoor.Layout.Column = 9;

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
            app.file_ContextMenu_Tree.Tag = 'winMonitorSPED';

            % Create file_ContextMenu_delTree1Node
            app.file_ContextMenu_delTree1Node = uimenu(app.file_ContextMenu_Tree);
            app.file_ContextMenu_delTree1Node.MenuSelectedFcn = createCallbackFcn(app, @contextMenu_delTreeNodeSelected, true);
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
