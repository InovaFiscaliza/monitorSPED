classdef (Abstract) Controller

    % Trata-se de classe abstrata, cujo método Run cria as variáveis requeridas
    % pelo biblioteca reportLib, de SupportPackages. São elas:
    % • reportInfo....: estrutura com os campos obrigatórios "App", "Version", 
    %   "Path", "Model" e "Function". Campos opcionais podem ser criados.

    % • dataOverview..: lista de estruturas com os campos obrigatórios "ID", 
    %   "InfoSet" e "HTML". Em "InfoSet", armazena-se um handle para instância 
    %   da classe model.ECD. As instância desse classe são agrupadas por CNPJ 
    %   e ordenadas pelo fim do PERÍODO CONTÁBIL.

    % • analyzedData..: instância de dataOverview (imaginando que dataOverview 
    %   é a variável que possibilita a recorrência).

    % Quando o objeto criado é uma IMAGEM, tem-se:
    % • imgSettings.: campo extraído do script .JSON que norteia a criação
    %   do relatório, o qual é uma estrutura com os campos "Origin", "Source", 
    %   "Caption", "Settings", "Intro", "Error" e "LineBreak".
    
    % Quando o objeto criado uma TABELA, tem-se:
    % • tableSettings.: campo extraído do script .JSON que norteia a criação
    %   do relatório, o qual é uma estrutura com os campos "Origin", "Source", 
    %   "Columns", "Caption", "Settings", "Intro", "Error" e "LineBreak".

    properties (Constant)
        %-----------------------------------------------------------------%
        docVersion = dictionary(["Preliminar", "Definitiva"], ...
            [struct('version', 'preview', 'encoding', 'UTF-8'), struct('version', 'final', 'encoding', 'ISO-8859-1')])
    end

    methods (Static)
        %-----------------------------------------------------------------%
        function Run(callingApp, projectData, ecdObj, reportSettings, generalSettings)        
            arguments
                callingApp
                projectData
                ecdObj
                reportSettings
                generalSettings
            end

            switch class(callingApp)
                case {'winMonitorSPED', 'winMonitorSPED_exported'}
                    app = callingApp;
                    context = 'File';
                case {'auxApp.winECD',  'auxApp.winECD_exported'}
                    app = callingApp.mainApp;
                    context = 'ECD';
                otherwise
                    error('UnexpectedCaller')
            end

            [projectFolder, ...
             programDataFolder] = appUtil.Path(class.Constants.appName, app.rootFolder);

            issueId    = num2str(reportSettings.issue);
            docName    = reportSettings.model;
            docIndex   = find(strcmp({projectData.report.templates.Name}, docName), 1);
            if isempty(docIndex)
                error('Pendente escolha do modelo de relatório')
            end

            docType    = projectData.report.templates(docIndex).DocumentType;
            docVersion = reportLibConnection.Controller.docVersion(reportSettings.reportVersion);

            try
                if ~isdeployed()
                    error('ForceDebugMode')
                end
                docScript = jsondecode(fileread(fullfile(programDataFolder, 'ReportTemplates', projectData.report.templates(docIndex).File)));
            catch
                docScript = jsondecode(fileread(fullfile(projectFolder,     'ReportTemplates', projectData.report.templates(docIndex).File)));
            end
        
            %-------------------------------------------------------------%
            % reportInfo
            %
            % Importante observar que o campo "Function" armazena informações
            % gerais, a compor itens "Introdução", "Metodologia" e "Conclusão",
            % e informações específicas, a compor itens com recorrências, como 
            % "Resultados".
            %-------------------------------------------------------------%
            reportInfo = struct('App',      app, ...
                                'Version',  app.General.AppVersion,                                                   ...
                                'Path',     struct('rootFolder',                 app.rootFolder,                      ...
                                                   'userFolder',                 generalSettings.fileFolder.userPath, ...
                                                   'tempFolder',                 generalSettings.fileFolder.tempPath, ...
                                                   'appConnection',              projectFolder,                       ...
                                                   'appDataFolder',              programDataFolder),                  ...
                                'Model',    struct('Name',                       docName,                             ...
                                                   'DocumentType',               docType,                             ...
                                                   'Script',                     docScript,                           ...
                                                   'Version',                    docVersion.version),                 ...
                                'Function', struct(...
                                                   ... % APLICÁVEIS ÀS SEÇÕES GERAIS DO RELATÓRIO
                                                   'cfg_File',                  'reportLibConnection.Variable.GeneralSettings(reportInfo, "File")', ...
                                                   'cfg_ECD',                   'reportLibConnection.Variable.GeneralSettings(reportInfo, "ECD")', ...
                                                   'cfg_ReportTemplate',         jsonencode(struct('Name', docName, 'DocumentType', docType, 'Version', docVersion.version)), ...
                                                   'var_Issue',                  issueId, ...
                                                   'var_Unit',                   reportSettings.unit, ...
                                                   'tbl_FileByCompany',         'reportLibConnection.Table.FileByCompany(reportInfo)', ...
                                                   'tbl_PeriodByCompany',       'reportLibConnection.Table.PeriodByCompany(reportInfo)', ...
                                                   ...
                                                   ... % APLICÁVEIS À SEÇÃO COM RECORRÊNCIA DO RELATÓRIO
                                                   ... % 'var_Index'
                                                   'var_Id',                    'analyzedData.ID', ...
                                                   'var_NumFilesGlobal',        'numel(analyzedData.InfoSet.ecdObj)', ...
                                                   'var_NumFiles',              'reportLibConnection.Variable.ClassProperty(analyzedData, "NumFiles")', ...
                                                   'var_FileNameList',          'reportLibConnection.Variable.ClassProperty(analyzedData, "FileNameList")', ...
                                                   'var_CompanyName',           'reportLibConnection.Variable.ClassProperty(analyzedData, "CompanyName")', ...
                                                   'var_CompanyId',             'reportLibConnection.Variable.ClassProperty(analyzedData, "CompanyId")', ...
                                                   'var_Hash',                  'reportLibConnection.Variable.ClassProperty(analyzedData, "Hash")', ...
                                                   'var_Period',                'reportLibConnection.Variable.ClassProperty(analyzedData, "Period")', ...
                                                   'var_ReceitaFederal',        'reportLibConnection.Variable.ClassProperty(analyzedData, "ReceitaFederal")', ...
                                                   'var_ContentSample',         'reportLibConnection.Variable.ClassProperty(analyzedData, "ContentSample")', ...
                                                   'var_Layout',                'reportLibConnection.Variable.ClassProperty(analyzedData, "Layout")', ...
                                                   'tbl_SourceFileStatus',      'reportLibConnection.Table.SourceFileStatus(analyzedData)', ...
                                                   'tbl_FileMetadata',          'reportLibConnection.Table.FileMetadata(analyzedData)', ...
                                                   'tbl_Raw',                   'reportLibConnection.Table.Raw(analyzedData, tableSettings)'), ...
                                'Project',  projectData, ...
                                'Object',   ecdObj,      ...
                                'Settings', generalSettings);
            
            fieldsUnnecessary = {'rootFolder', 'entryPointFolder', 'tempSessionFolder', 'ctfRoot'};
            fieldsUnnecessary(cellfun(@(x) ~isfield(reportInfo.Version.application, x), fieldsUnnecessary)) = [];
            if ~isempty(fieldsUnnecessary)
                reportInfo.Version.application = rmfield(reportInfo.Version.application, fieldsUnnecessary);
            end

            %-------------------------------------------------------------%
            % dataOverview
            %
            % Caso dataOverview não seja escalar e exista um item no relatório
            % com recorrência, a própria lib cria a variável "var_Index", acessível 
            % em "reportInfo.Function.var_Index".
            %-------------------------------------------------------------%
            dataOverview = struct('ID', {}, 'InfoSet', {}, 'HTML', {});
            
            idsList = {ecdObj.CompanyId};
            ids = unique(idsList);

            for id = ids
                idIndexes   = find(strcmp(idsList, id));
                [~, idSort] = sort(arrayfun(@(x) x.Period(2), ecdObj(idIndexes)));
                idIndexes   = idIndexes(idSort);

                nireInfo  = '';
                if ~isempty(ecdObj(idIndexes(1)).CompanyInfo.NIRE)
                    nireInfo = sprintf('%s - ', ecdObj(idIndexes(1)).CompanyInfo.NIRE);
                end
                companyId = sprintf('%s - %s%s', ecdObj(idIndexes(1)).CompanyId, nireInfo, ecdObj(idIndexes(1)).CompanyName);

                dataOverview(end+1) = struct('ID',      companyId,                           ...
                                             'InfoSet', struct('indexes', idIndexes,         ...
                                                               'ecdObj', ecdObj(idIndexes)), ...
                                             'HTML',    struct('Component', {}, 'Source', {}, 'Value', {}));
                    

                % if any(arrayfun(@(x) ~isempty(x.GUI.externalFiles), ecdObj(idIndexes)))
                %     externalFilesList = arrayfun(@(x) x.GUI.externalFiles, ecdObj(idIndexes));
                %     dataOverview(end).HTML = vertcat(externalFilesList{:});
                % end
            end


            %-------------------------------------------------------------%
            % Conexão com reportLib, parte do repositório "SupportPackages"
            %-------------------------------------------------------------%
            HTMLDocContent = reportLib.Controller(reportInfo, dataOverview);


            %-------------------------------------------------------------%
            % Exclui container criado para os plots, caso aplicável.
            %-------------------------------------------------------------%
            hFigure    = app.UIFigure;
            hContainer = findobj(hFigure, 'Tag', 'reportGeneratorContainer');
            if ~isempty(hContainer)
                delete(hContainer)
            end

            
            %-------------------------------------------------------------%
            % Em sendo a versão "Preliminar", apenas apresenta o html no
            % navegador. Por outro lado, em sendo a versão "Definitiva",
            % salva-se o arquivo ZIP em pasta local.
            %-------------------------------------------------------------%
            [baseFullFileName, baseFileName] = appUtil.DefaultFileName(generalSettings.fileFolder.tempPath, 'monitorSPED_FinalReport', issueId);
            HTMLFile = [baseFullFileName '.html'];
            
            writematrix(HTMLDocContent, HTMLFile, 'QuoteStrings', 'none', 'FileType', 'text', 'Encoding', docVersion.encoding)

            switch docVersion.version
                case 'preview'
                    web(HTMLFile, '-new')
                    updateGeneratedFiles(projectData, context)

                case 'final'
                    % RAWFiles = {ecdObj.FileFullName};
                    % XLSXFile = [baseFullFileName '.xlsx'];                    
                    % ZIPFile  = appUtil.modalWindow(app.UIFigure, 'uiputfile', '', {'*.zip', 'monitorRNI (*.zip)'}, fullfile(app.General.fileFolder.userPath, [baseFileName '.zip']));
                    % if isempty(ZIPFile)
                    %     return
                    % end                    
                    % 
                    % zip(ZIPFile, [{HTMLFile}, {XLSXFile}, RAWFiles])
                    % 
                    % updateGeneratedFiles(projectData, context, RAWFiles, HTMLFile, XLSXFile, ZIPFile)
            end
        end
    end
end