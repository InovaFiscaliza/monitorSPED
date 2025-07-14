classdef winConfig_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        GridLayout               matlab.ui.container.GridLayout
        Folders_Grid             matlab.ui.container.GridLayout
        FolderMapPanel           matlab.ui.container.Panel
        FolderMapGrid            matlab.ui.container.GridLayout
        userPathButton           matlab.ui.control.Image
        userPath                 matlab.ui.control.EditField
        userPathLabel            matlab.ui.control.Label
        DataHubPOSTButton        matlab.ui.control.Image
        DataHubPOST              matlab.ui.control.EditField
        DataHubPOSTLabel         matlab.ui.control.Label
        config_FolderMapLabel    matlab.ui.control.Label
        CustomPlotGrid           matlab.ui.container.GridLayout
        general_FilePanel        matlab.ui.container.Panel
        general_FileLabel        matlab.ui.control.Label
        General_Grid             matlab.ui.container.GridLayout
        openAuxiliarApp2Debug    matlab.ui.control.CheckBox
        openAuxiliarAppAsDocked  matlab.ui.control.CheckBox
        gpuType                  matlab.ui.control.DropDown
        gpuTypeLabel             matlab.ui.control.Label
        versionInfo              matlab.ui.control.Label
        versionInfoRefresh       matlab.ui.control.Image
        versionInfoLabel         matlab.ui.control.Label
        LeftPanelRadioGroup      matlab.ui.container.ButtonGroup
        btnFolder                matlab.ui.control.RadioButton
        btnAnalysis              matlab.ui.control.RadioButton
        btnGeneral               matlab.ui.control.RadioButton
        LeftPanel                matlab.ui.container.Panel
        LeftPanelGrid            matlab.ui.container.GridLayout
        menuUnderline            matlab.ui.control.Image
        menu_ButtonGrid          matlab.ui.container.GridLayout
        menu_ButtonIcon          matlab.ui.control.Image
        menu_ButtonLabel         matlab.ui.control.Label
        toolGrid                 matlab.ui.container.GridLayout
        openDevTools             matlab.ui.control.Image
    end

    
    properties
        %-----------------------------------------------------------------%
        Container
        isDocked = false
        
        mainApp
        rootFolder

        % A função do timer é executada uma única vez após a renderização
        % da figura, lendo arquivos de configuração, iniciando modo de operação
        % paralelo etc. A ideia é deixar o MATLAB focar apenas na criação dos 
        % componentes essenciais da GUI (especificados em "createComponents"), 
        % mostrando a GUI para o usuário o mais rápido possível.
        timerObj
        jsBackDoor

        % Janela de progresso já criada no DOM. Dessa forma, controla-se 
        % apenas a sua visibilidade - e tornando desnecessário criá-la a
        % cada chamada (usando uiprogressdlg, por exemplo).
        progressDialog

        stableVersion
    end


    properties (Access = private)
        %-----------------------------------------------------------------%
        DefaultValues = struct('Graphics',  struct('openGL', 'hardware', 'Format', 'jpeg', 'Resolution', '120', 'Dock', true),                                                                                                                                                                                                        ...
                               'Elevation', struct('Points', '256', 'ForceSearch', false, 'Server', 'Open-Elevation'))
    end


    methods
        %-----------------------------------------------------------------%
        % IPC: COMUNICAÇÃO ENTRE PROCESSOS
        %-----------------------------------------------------------------%
        function ipcSecundaryJSEventsHandler(app, event)
            try
                switch event.HTMLEventName
                    case 'renderer'
                        startup_Controller(app)
                    otherwise
                        error('UnexpectedEvent')
                end

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', ME.message);
            end
        end
    end
    

    methods (Access = private)
        %-----------------------------------------------------------------%
        % JSBACKDOOR
        %-----------------------------------------------------------------%
        function jsBackDoor_Initialization(app)
            app.jsBackDoor = uihtml(app.UIFigure, "HTMLSource",           appUtil.jsBackDoorHTMLSource(),                 ...
                                                  "HTMLEventReceivedFcn", @(~, evt)ipcSecundaryJSEventsHandler(app, evt), ...
                                                  "Visible",              "off");
        end

        %-----------------------------------------------------------------%
        function jsBackDoor_Customizations(app)
            if app.isDocked
                app.progressDialog = app.mainApp.progressDialog;
            else
                sendEventToHTMLSource(app.jsBackDoor, 'startup', app.mainApp.executionMode);
                app.progressDialog = ccTools.ProgressDialog(app.jsBackDoor);
            end

            elToModify = {app.versionInfo};
            elDataTag  = ui.CustomizationBase.getElementsDataTag(elToModify);
            if ~isempty(elDataTag)
                appName = class(app);
                ui.TextView.startup(app.jsBackDoor, elToModify{1}, appName);
            end
        end
    end


    methods (Access = private)
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
            jsBackDoor_Customizations(app)

            startup_GUIComponents(app)
        end

        %-----------------------------------------------------------------%
        function startup_GUIComponents(app)
            switch app.mainApp.executionMode
                case 'webApp'
                    delete(app.openDevTools)
                otherwise
                    app.btnFolder.Enable               = 1;
                    app.versionInfoRefresh.Enable      = 1;
                    app.gpuType.Enable                 = 1;
                    app.openAuxiliarAppAsDocked.Enable = 1;
            end

            if ~isdeployed
                app.openAuxiliarApp2Debug.Enable = 1;
            end

            General_updatePanel(app)
            Folder_updatePanel(app)
        end

        %-----------------------------------------------------------------%
        function General_updatePanel(app)
            % Versão:
            ui.TextView.update(app.versionInfo, util.HtmlTextGenerator.AppInfo(app.mainApp.General, app.mainApp.rootFolder, app.mainApp.executionMode));

            % Renderizador:
            graphRender = opengl('data');
            switch graphRender.HardwareSupportLevel
                case 'basic'; graphRenderSupport = 'hardwarebasic';
                case 'full';  graphRenderSupport = 'hardware';
                case 'none';  graphRenderSupport = 'software';
                otherwise;    graphRenderSupport = graphRender.HardwareSupportLevel; % "driverissue"
            end

            if ~ismember(graphRenderSupport, app.gpuType.Items)
                app.gpuType.Items{end+1} = graphRenderSupport;
            end
            app.gpuType.Value = graphRenderSupport;

            % Modo de operação:
            app.openAuxiliarAppAsDocked.Value   = app.mainApp.General.operationMode.Dock;
            app.openAuxiliarApp2Debug.Value     = app.mainApp.General.operationMode.Debug;
        end

        %-----------------------------------------------------------------%
        function Folder_updatePanel(app)
            % Na versão webapp, a configuração das pastas não é habilitada.

            if ~strcmp(app.mainApp.executionMode, 'webApp')
                app.btnFolder.Enable      = 1;

                DataHub_POST = app.mainApp.General.fileFolder.DataHub_POST;    
                if isfolder(DataHub_POST)
                    app.DataHubPOST.Value = DataHub_POST;
                end

                app.userPath.Value        = app.mainApp.General.fileFolder.userPath;
            end
        end

        %-----------------------------------------------------------------%
        function saveGeneralSettings(app)
            appUtil.generalSettingsSave(class.Constants.appName, app.rootFolder, app.mainApp.General_I, app.mainApp.executionMode)
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp)
            
            % A razão de ser deste app é possibilitar visualização/edição 
            % de algumas das informações do arquivo "GeneralSettings.json".
            app.mainApp    = mainApp;
            app.rootFolder = mainApp.rootFolder;

            if app.isDocked
                app.GridLayout.Padding(4) = 19;
                app.jsBackDoor = mainApp.jsBackDoor;
                startup_Controller(app)
            else
                appUtil.winPosition(app.UIFigure)
                startup_timerCreation(app)
            end
            
        end

        % Close request function: UIFigure
        function closeFcn(app, event)
            
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcn')
            delete(app)
            
        end

        % Selection changed function: LeftPanelRadioGroup
        function RadioButtonGroupSelectionChanged(app, event)
            
            selectedButton = app.LeftPanelRadioGroup.SelectedObject;
            switch selectedButton
                case app.btnGeneral;  app.GridLayout.ColumnWidth(4:6) = {'1x',0,0};
                case app.btnAnalysis; app.GridLayout.ColumnWidth(4:6) = {0,'1x',0};
                case app.btnFolder;   app.GridLayout.ColumnWidth(4:6) = {0,0,'1x'};
            end
            
        end

        % Image clicked function: versionInfoRefresh
        function AppVersion_refreshButtonPushed(app, event)
            
            app.progressDialog.Visible = 'visible';

            [htmlContent, app.stableVersion] = util.HtmlTextGenerator.checkAvailableUpdate(app.mainApp.General, app.rootFolder);
            appUtil.modalWindow(app.UIFigure, "info", htmlContent);       

            app.progressDialog.Visible = 'hidden';

        end

        % Value changed function: gpuType, openAuxiliarApp2Debug, 
        % ...and 1 other component
        function Graphics_ParameterValueChanged(app, event)
            
            switch event.Source
                case app.gpuType
                    if ismember(app.gpuType.Value, {'software', 'hardware', 'hardwarebasic'})
                        eval(sprintf('opengl %s', app.gpuType.Value))

                        graphRender = opengl('data');
                        
                        app.mainApp.General.openGL = app.gpuType.Value;
                        app.mainApp.General.AppVersion.openGL = rmfield(graphRender, {'MaxTextureSize', 'Visual', 'SupportsGraphicsSmoothing', 'SupportsDepthPeelTransparency', 'SupportsAlignVertexCenters', 'Extensions', 'MaxFrameBufferSize'});
                    end

                case app.openAuxiliarAppAsDocked
                    app.mainApp.General.operationMode.Dock  = app.openAuxiliarAppAsDocked.Value;

                case app.openAuxiliarApp2Debug
                    app.mainApp.General.operationMode.Debug = app.openAuxiliarApp2Debug.Value;
            end

            app.mainApp.General_I.openGL        = app.mainApp.General.openGL;
            app.mainApp.General_I.operationMode = app.mainApp.General.operationMode;

            saveGeneralSettings(app)

        end

        % Image clicked function: DataHubPOSTButton, userPathButton
        function Folder_ButtonPushed(app, event)
            
            try
                relatedFolder = eval(sprintf('app.config_Folder_%s.Value', event.Source.Tag));                    
            catch
                relatedFolder = app.mainApp.General.fileFolder.(event.Source.Tag);
            end
            
            if isfolder(relatedFolder)
                initialFolder = relatedFolder;
            elseif isfile(relatedFolder)
                initialFolder = fileparts(relatedFolder);
            else
                initialFolder = app.userPath.Value;
            end
            
            selectedFolder = uigetdir(initialFolder);
            figure(app.UIFigure)

            if selectedFolder
                switch event.Source
                    case app.DataHubPOSTButton
                        if strcmp(app.mainApp.General.fileFolder.DataHub_POST, selectedFolder) 
                            return
                        else
                            selectedFolderFiles = dir(selectedFolder);
                            if ~ismember('.monitorsped_post', {selectedFolderFiles.name})
                                appUtil.modalWindow(app.UIFigure, 'error', 'Não se trata da pasta "DataHub - POST", do monitorSPED.');
                                return
                            end

                            app.DataHubPOST.Value = selectedFolder;
                            app.mainApp.General.fileFolder.DataHub_POST = selectedFolder;
    
                            ipcMainMatlabCallsHandler(app.mainApp, app, 'checkDataHubLampStatus')
                        end

                    case app.userPathButton
                        app.userPath.Value = selectedFolder;
                        app.mainApp.General.fileFolder.userPath = selectedFolder;
                end

                app.mainApp.General_I.fileFolder = app.mainApp.General.fileFolder;
                saveGeneralSettings(app)
                Folder_updatePanel(app)
            end

        end

        % Image clicked function: openDevTools
        function openDevToolsClicked(app, event)
            
            ipcMainMatlabCallsHandler(app.mainApp, app, 'openDevTools')

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app, Container)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            if isempty(Container)
                app.UIFigure = uifigure('Visible', 'off');
                app.UIFigure.AutoResizeChildren = 'off';
                app.UIFigure.Position = [100 100 1244 660];
                app.UIFigure.Name = 'monitorSPED';
                app.UIFigure.Icon = 'icon_48.png';
                app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeFcn, true);

                app.Container = app.UIFigure;

            else
                if ~isempty(Container.Children)
                    delete(Container.Children)
                end

                app.UIFigure  = ancestor(Container, 'figure');
                app.Container = Container;
                if ~isprop(Container, 'RunningAppInstance')
                    addprop(app.Container, 'RunningAppInstance');
                end
                app.Container.RunningAppInstance = app;
                app.isDocked  = true;
            end

            % Create GridLayout
            app.GridLayout = uigridlayout(app.Container);
            app.GridLayout.ColumnWidth = {5, 320, 10, '1x', 0, 0, 5};
            app.GridLayout.RowHeight = {5, 23, 3, 5, 100, '1x', 5, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create toolGrid
            app.toolGrid = uigridlayout(app.GridLayout);
            app.toolGrid.ColumnWidth = {'1x', 22, 1};
            app.toolGrid.RowHeight = {4, 17, 2};
            app.toolGrid.ColumnSpacing = 5;
            app.toolGrid.RowSpacing = 0;
            app.toolGrid.Padding = [5 5 0 5];
            app.toolGrid.Layout.Row = 8;
            app.toolGrid.Layout.Column = [1 7];
            app.toolGrid.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create openDevTools
            app.openDevTools = uiimage(app.toolGrid);
            app.openDevTools.ScaleMethod = 'none';
            app.openDevTools.ImageClickedFcn = createCallbackFcn(app, @openDevToolsClicked, true);
            app.openDevTools.Tooltip = {'DevTools'};
            app.openDevTools.Layout.Row = 2;
            app.openDevTools.Layout.Column = 2;
            app.openDevTools.ImageSource = 'Debug_18.png';

            % Create menu_ButtonGrid
            app.menu_ButtonGrid = uigridlayout(app.GridLayout);
            app.menu_ButtonGrid.ColumnWidth = {18, '1x', '1x'};
            app.menu_ButtonGrid.RowHeight = {'1x'};
            app.menu_ButtonGrid.ColumnSpacing = 3;
            app.menu_ButtonGrid.Padding = [2 0 0 0];
            app.menu_ButtonGrid.Layout.Row = 2;
            app.menu_ButtonGrid.Layout.Column = 2;
            app.menu_ButtonGrid.BackgroundColor = [0.749 0.749 0.749];

            % Create menu_ButtonLabel
            app.menu_ButtonLabel = uilabel(app.menu_ButtonGrid);
            app.menu_ButtonLabel.FontSize = 11;
            app.menu_ButtonLabel.Layout.Row = 1;
            app.menu_ButtonLabel.Layout.Column = 2;
            app.menu_ButtonLabel.Text = 'CONFIGURAÇÕES';

            % Create menu_ButtonIcon
            app.menu_ButtonIcon = uiimage(app.menu_ButtonGrid);
            app.menu_ButtonIcon.ScaleMethod = 'none';
            app.menu_ButtonIcon.Tag = '1';
            app.menu_ButtonIcon.Layout.Row = 1;
            app.menu_ButtonIcon.Layout.Column = 1;
            app.menu_ButtonIcon.HorizontalAlignment = 'left';
            app.menu_ButtonIcon.ImageSource = 'Settings_18.png';

            % Create menuUnderline
            app.menuUnderline = uiimage(app.GridLayout);
            app.menuUnderline.ScaleMethod = 'none';
            app.menuUnderline.Layout.Row = 3;
            app.menuUnderline.Layout.Column = 2;
            app.menuUnderline.ImageSource = 'LineH.svg';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = [5 6];
            app.LeftPanel.Layout.Column = 2;

            % Create LeftPanelGrid
            app.LeftPanelGrid = uigridlayout(app.LeftPanel);
            app.LeftPanelGrid.ColumnWidth = {'1x'};
            app.LeftPanelGrid.RowHeight = {100, '1x'};
            app.LeftPanelGrid.Padding = [0 0 0 0];
            app.LeftPanelGrid.BackgroundColor = [1 1 1];

            % Create LeftPanelRadioGroup
            app.LeftPanelRadioGroup = uibuttongroup(app.GridLayout);
            app.LeftPanelRadioGroup.AutoResizeChildren = 'off';
            app.LeftPanelRadioGroup.SelectionChangedFcn = createCallbackFcn(app, @RadioButtonGroupSelectionChanged, true);
            app.LeftPanelRadioGroup.BorderType = 'none';
            app.LeftPanelRadioGroup.BackgroundColor = [1 1 1];
            app.LeftPanelRadioGroup.Layout.Row = 5;
            app.LeftPanelRadioGroup.Layout.Column = 2;
            app.LeftPanelRadioGroup.FontSize = 11;

            % Create btnGeneral
            app.btnGeneral = uiradiobutton(app.LeftPanelRadioGroup);
            app.btnGeneral.Text = 'Aspectos gerais';
            app.btnGeneral.FontSize = 11;
            app.btnGeneral.Position = [14 69 100 22];
            app.btnGeneral.Value = true;

            % Create btnAnalysis
            app.btnAnalysis = uiradiobutton(app.LeftPanelRadioGroup);
            app.btnAnalysis.Text = 'Análise';
            app.btnAnalysis.FontSize = 11;
            app.btnAnalysis.Position = [14 47 58 22];

            % Create btnFolder
            app.btnFolder = uiradiobutton(app.LeftPanelRadioGroup);
            app.btnFolder.Enable = 'off';
            app.btnFolder.Text = 'Mapeamento de pastas';
            app.btnFolder.FontSize = 11;
            app.btnFolder.Position = [14 25 195 22];

            % Create General_Grid
            app.General_Grid = uigridlayout(app.GridLayout);
            app.General_Grid.ColumnWidth = {'1x', 16};
            app.General_Grid.RowHeight = {26, 150, 22, '1x', 17, 22, 1, 22, 15};
            app.General_Grid.RowSpacing = 5;
            app.General_Grid.Padding = [0 0 0 0];
            app.General_Grid.Layout.Row = [2 6];
            app.General_Grid.Layout.Column = 4;
            app.General_Grid.BackgroundColor = [1 1 1];

            % Create versionInfoLabel
            app.versionInfoLabel = uilabel(app.General_Grid);
            app.versionInfoLabel.VerticalAlignment = 'bottom';
            app.versionInfoLabel.FontSize = 10;
            app.versionInfoLabel.Layout.Row = 1;
            app.versionInfoLabel.Layout.Column = 1;
            app.versionInfoLabel.Text = 'ASPECTOS GERAIS';

            % Create versionInfoRefresh
            app.versionInfoRefresh = uiimage(app.General_Grid);
            app.versionInfoRefresh.ScaleMethod = 'none';
            app.versionInfoRefresh.ImageClickedFcn = createCallbackFcn(app, @AppVersion_refreshButtonPushed, true);
            app.versionInfoRefresh.Enable = 'off';
            app.versionInfoRefresh.Tooltip = {'Verifica atualizações'};
            app.versionInfoRefresh.Layout.Row = 1;
            app.versionInfoRefresh.Layout.Column = 2;
            app.versionInfoRefresh.VerticalAlignment = 'bottom';
            app.versionInfoRefresh.ImageSource = 'Refresh_18.png';

            % Create versionInfo
            app.versionInfo = uilabel(app.General_Grid);
            app.versionInfo.BackgroundColor = [1 1 1];
            app.versionInfo.VerticalAlignment = 'top';
            app.versionInfo.WordWrap = 'on';
            app.versionInfo.FontSize = 11;
            app.versionInfo.Layout.Row = [2 4];
            app.versionInfo.Layout.Column = [1 2];
            app.versionInfo.Interpreter = 'html';
            app.versionInfo.Text = '';

            % Create gpuTypeLabel
            app.gpuTypeLabel = uilabel(app.General_Grid);
            app.gpuTypeLabel.VerticalAlignment = 'bottom';
            app.gpuTypeLabel.FontSize = 10;
            app.gpuTypeLabel.FontColor = [0.149 0.149 0.149];
            app.gpuTypeLabel.Layout.Row = 5;
            app.gpuTypeLabel.Layout.Column = [1 2];
            app.gpuTypeLabel.Text = 'Unidade gráfica:';

            % Create gpuType
            app.gpuType = uidropdown(app.General_Grid);
            app.gpuType.Items = {'hardwarebasic', 'hardware', 'software'};
            app.gpuType.ValueChangedFcn = createCallbackFcn(app, @Graphics_ParameterValueChanged, true);
            app.gpuType.Enable = 'off';
            app.gpuType.FontSize = 11;
            app.gpuType.BackgroundColor = [1 1 1];
            app.gpuType.Layout.Row = 6;
            app.gpuType.Layout.Column = [1 2];
            app.gpuType.Value = 'hardware';

            % Create openAuxiliarAppAsDocked
            app.openAuxiliarAppAsDocked = uicheckbox(app.General_Grid);
            app.openAuxiliarAppAsDocked.ValueChangedFcn = createCallbackFcn(app, @Graphics_ParameterValueChanged, true);
            app.openAuxiliarAppAsDocked.Enable = 'off';
            app.openAuxiliarAppAsDocked.Text = 'Modo DOCK: módulos auxiliares abertos na janela principal do app';
            app.openAuxiliarAppAsDocked.FontSize = 11;
            app.openAuxiliarAppAsDocked.Layout.Row = 8;
            app.openAuxiliarAppAsDocked.Layout.Column = [1 2];

            % Create openAuxiliarApp2Debug
            app.openAuxiliarApp2Debug = uicheckbox(app.General_Grid);
            app.openAuxiliarApp2Debug.ValueChangedFcn = createCallbackFcn(app, @Graphics_ParameterValueChanged, true);
            app.openAuxiliarApp2Debug.Enable = 'off';
            app.openAuxiliarApp2Debug.Text = 'Modo DEBUG';
            app.openAuxiliarApp2Debug.FontSize = 11;
            app.openAuxiliarApp2Debug.Layout.Row = 9;
            app.openAuxiliarApp2Debug.Layout.Column = [1 2];

            % Create CustomPlotGrid
            app.CustomPlotGrid = uigridlayout(app.GridLayout);
            app.CustomPlotGrid.ColumnWidth = {'1x', 16};
            app.CustomPlotGrid.RowHeight = {26, '1x'};
            app.CustomPlotGrid.RowSpacing = 5;
            app.CustomPlotGrid.Padding = [0 0 0 0];
            app.CustomPlotGrid.Layout.Row = [2 6];
            app.CustomPlotGrid.Layout.Column = 5;
            app.CustomPlotGrid.BackgroundColor = [1 1 1];

            % Create general_FileLabel
            app.general_FileLabel = uilabel(app.CustomPlotGrid);
            app.general_FileLabel.VerticalAlignment = 'bottom';
            app.general_FileLabel.FontSize = 10;
            app.general_FileLabel.Layout.Row = 1;
            app.general_FileLabel.Layout.Column = 1;
            app.general_FileLabel.Text = 'LEITURA DE ARQUIVOS';

            % Create general_FilePanel
            app.general_FilePanel = uipanel(app.CustomPlotGrid);
            app.general_FilePanel.Layout.Row = 2;
            app.general_FilePanel.Layout.Column = [1 2];

            % Create Folders_Grid
            app.Folders_Grid = uigridlayout(app.GridLayout);
            app.Folders_Grid.ColumnWidth = {'1x'};
            app.Folders_Grid.RowHeight = {26, '1x'};
            app.Folders_Grid.RowSpacing = 5;
            app.Folders_Grid.Padding = [0 0 0 0];
            app.Folders_Grid.Layout.Row = [2 6];
            app.Folders_Grid.Layout.Column = 6;
            app.Folders_Grid.BackgroundColor = [1 1 1];

            % Create config_FolderMapLabel
            app.config_FolderMapLabel = uilabel(app.Folders_Grid);
            app.config_FolderMapLabel.VerticalAlignment = 'bottom';
            app.config_FolderMapLabel.FontSize = 10;
            app.config_FolderMapLabel.Layout.Row = 1;
            app.config_FolderMapLabel.Layout.Column = 1;
            app.config_FolderMapLabel.Text = 'MAPEAMENTO DE PASTAS';

            % Create FolderMapPanel
            app.FolderMapPanel = uipanel(app.Folders_Grid);
            app.FolderMapPanel.AutoResizeChildren = 'off';
            app.FolderMapPanel.Layout.Row = 2;
            app.FolderMapPanel.Layout.Column = 1;

            % Create FolderMapGrid
            app.FolderMapGrid = uigridlayout(app.FolderMapPanel);
            app.FolderMapGrid.ColumnWidth = {'1x', 20};
            app.FolderMapGrid.RowHeight = {17, 22, 17, 22, '1x'};
            app.FolderMapGrid.ColumnSpacing = 5;
            app.FolderMapGrid.RowSpacing = 5;
            app.FolderMapGrid.BackgroundColor = [1 1 1];

            % Create DataHubPOSTLabel
            app.DataHubPOSTLabel = uilabel(app.FolderMapGrid);
            app.DataHubPOSTLabel.VerticalAlignment = 'bottom';
            app.DataHubPOSTLabel.FontSize = 10;
            app.DataHubPOSTLabel.Layout.Row = 1;
            app.DataHubPOSTLabel.Layout.Column = 1;
            app.DataHubPOSTLabel.Text = 'DataHub - POST:';

            % Create DataHubPOST
            app.DataHubPOST = uieditfield(app.FolderMapGrid, 'text');
            app.DataHubPOST.Editable = 'off';
            app.DataHubPOST.FontSize = 11;
            app.DataHubPOST.Layout.Row = 2;
            app.DataHubPOST.Layout.Column = 1;

            % Create DataHubPOSTButton
            app.DataHubPOSTButton = uiimage(app.FolderMapGrid);
            app.DataHubPOSTButton.ImageClickedFcn = createCallbackFcn(app, @Folder_ButtonPushed, true);
            app.DataHubPOSTButton.Tag = 'DataHub_POST';
            app.DataHubPOSTButton.Layout.Row = 2;
            app.DataHubPOSTButton.Layout.Column = 2;
            app.DataHubPOSTButton.ImageSource = 'OpenFile_36x36.png';

            % Create userPathLabel
            app.userPathLabel = uilabel(app.FolderMapGrid);
            app.userPathLabel.VerticalAlignment = 'bottom';
            app.userPathLabel.FontSize = 10;
            app.userPathLabel.Layout.Row = 3;
            app.userPathLabel.Layout.Column = 1;
            app.userPathLabel.Text = 'Pasta do usuário:';

            % Create userPath
            app.userPath = uieditfield(app.FolderMapGrid, 'text');
            app.userPath.Editable = 'off';
            app.userPath.FontSize = 11;
            app.userPath.Layout.Row = 4;
            app.userPath.Layout.Column = 1;

            % Create userPathButton
            app.userPathButton = uiimage(app.FolderMapGrid);
            app.userPathButton.ImageClickedFcn = createCallbackFcn(app, @Folder_ButtonPushed, true);
            app.userPathButton.Tag = 'userPath';
            app.userPathButton.Layout.Row = 4;
            app.userPathButton.Layout.Column = 2;
            app.userPathButton.ImageSource = 'OpenFile_36x36.png';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = winConfig_exported(Container, varargin)

            % Create UIFigure and components
            createComponents(app, Container)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            if app.isDocked
                delete(app.Container.Children)
            else
                delete(app.UIFigure)
            end
        end
    end
end
