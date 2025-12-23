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
        function Run(mainApp, projectData, ecdObj, reportSettings, generalSettings)        
            arguments
                mainApp
                projectData
                ecdObj
                reportSettings
                generalSettings
            end

            [projectFolder, ...
             programDataFolder] = appEngine.util.Path(class.Constants.appName, mainApp.rootFolder);

            context    = reportSettings.context;
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
            reportInfo = struct('App',      mainApp, ...
                                'Version',  mainApp.General.AppVersion,                                               ...
                                'Path',     struct('rootFolder',                 mainApp.rootFolder,                  ...
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
                                                   'cfg_File',                  'reportLibConnection.Variable.GeneralSettings(reportInfo, "File+ReportTemplate")', ...
                                                   'cfg_ECD',                   'reportLibConnection.Variable.GeneralSettings(reportInfo, "ECD+ReportTemplate")', ...
                                                   'var_Issue',                  issueId, ...
                                                   'var_Unit',                   reportSettings.unit, ...
                                                   'eFiscaliza_solicitacaoCode', 'reportLibConnection.Variable.GeneralSettings(reportInfo, "Solicitação de Inspeção", "ECD")', ...
                                                   'eFiscaliza_acaoCode',       'reportLibConnection.Variable.GeneralSettings(reportInfo, "Ação de Inspeção", "ECD")', ...
                                                   'eFiscaliza_atividadeCode',  'reportLibConnection.Variable.GeneralSettings(reportInfo, "Atividade de Inspeção", "ECD")', ...
                                                   'eFiscaliza_requester',      'reportLibConnection.Variable.GeneralSettings(reportInfo, "Unidade Demandante", "ECD")', ...
                                                   'eFiscaliza_unit',           'reportLibConnection.Variable.GeneralSettings(reportInfo, "Unidade Executante", "ECD")', ...
                                                   'eFiscaliza_unitCity',       'reportLibConnection.Variable.GeneralSettings(reportInfo, "Sede da Unidade Executante", "ECD")', ...
                                                   'eFiscaliza_description',    'reportLibConnection.Variable.GeneralSettings(reportInfo, "Descrição da Atividade de Inspeção", "ECD")', ...
                                                   'eFiscaliza_period',         'reportLibConnection.Variable.GeneralSettings(reportInfo, "Período Previsto da Fiscalização", "ECD")', ...
                                                   'eFiscaliza_fiscais',        'reportLibConnection.Variable.GeneralSettings(reportInfo, "Lista de Fiscais", "ECD")', ...
                                                   'eFiscaliza_sei',            'reportLibConnection.Variable.GeneralSettings(reportInfo, "Processo SEI", "ECD")', ...
                                                   'tbl_FileByCompany',         'reportLibConnection.Table.FileByCompany(reportInfo)', ...
                                                   ...
                                                   ... % APLICÁVEIS À SEÇÃO COM RECORRÊNCIA DO RELATÓRIO
                                                   ... % 'var_Index'
                                                   'var_Id',                    'analyzedData.ID', ...
                                                   'var_NumFilesGlobal',        'numel(analyzedData.InfoSet.ecdObj)', ...
                                                   'var_NumFiles',              'reportLibConnection.Variable.ClassProperty(analyzedData, "NumFiles")', ...
                                                   'var_FileNameList',          'reportLibConnection.Variable.ClassProperty(analyzedData, "FileNameList")', ...
                                                   'var_CompanyName',           'reportLibConnection.Variable.ClassProperty(analyzedData, "CompanyName")', ...
                                                   'var_CompanyId',             'reportLibConnection.Variable.ClassProperty(analyzedData, "CompanyId")', ...
                                                   'var_CompanyUF',             'reportLibConnection.Variable.ClassProperty(analyzedData, "State")', ...
                                                   'var_Hash',                  'reportLibConnection.Variable.ClassProperty(analyzedData, "Hash")', ...
                                                   'var_Period',                'reportLibConnection.Variable.ClassProperty(analyzedData, "Period")', ...
                                                   'var_ReceitaFederal',        'reportLibConnection.Variable.ClassProperty(analyzedData, "ReceitaFederal")', ...
                                                   'var_ContentSample',         'reportLibConnection.Variable.ClassProperty(analyzedData, "ContentSample")', ...
                                                   'var_Layout',                'reportLibConnection.Variable.ClassProperty(analyzedData, "Layout")', ...
                                                   'var_NumAccount',            'reportLibConnection.Variable.ClassProperty(analyzedData, "NumAccount")', ...
                                                   'var_TotalValue',            'reportLibConnection.Variable.ClassProperty(analyzedData, "TotalValue")', ...
                                                   'tbl_SourceFileStatus',      'reportLibConnection.Table.SourceFileStatus(analyzedData)', ...
                                                   'tbl_FileMetadata',          'reportLibConnection.Table.FileMetadata(analyzedData)', ...
                                                   'tbl_Raw',                   'reportLibConnection.Table.Raw(analyzedData, tableSettings)', ...
                                                   'tbl_TabelaApuracao',        'reportLibConnection.Table.TabelaApuracao(analyzedData)', ...
                                                   'tbl_TabelaAnotacao_All',    'reportLibConnection.Table.TabelaAnotacao(analyzedData, "all")', ...
                                                   'tbl_TabelaAnotacao_On',     'reportLibConnection.Table.TabelaAnotacao(analyzedData, "on")'), ...
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
            end


            %-------------------------------------------------------------%
            % Conexão com reportLib, parte do repositório "SupportPackages"
            %-------------------------------------------------------------%
            HTMLDocContent = reportLib.Controller(reportInfo, dataOverview);


            %-------------------------------------------------------------%
            % Exclui container criado para os plots, caso aplicável.
            %-------------------------------------------------------------%
            hFigure    = mainApp.UIFigure;
            hContainer = findobj(hFigure, 'Tag', 'reportGeneratorContainer');
            if ~isempty(hContainer)
                delete(hContainer)
            end

            
            %-------------------------------------------------------------%
            % Em sendo a versão "Preliminar", apenas apresenta o html no
            % navegador. Por outro lado, em sendo a versão "Definitiva",
            % salva-se o arquivo ZIP em pasta local.
            %-------------------------------------------------------------%
            [baseFullFileName, baseFileName] = appEngine.util.DefaultFileName(generalSettings.fileFolder.tempPath, 'monitorSPED_FinalReport', issueId);
            HTMLFile = [baseFullFileName '.html'];
            
            writematrix(HTMLDocContent, HTMLFile, 'QuoteStrings', 'none', 'FileType', 'text', 'Encoding', docVersion.encoding)

            switch docVersion.version
                case 'preview'
                    web(HTMLFile, '-new')
                    updateGeneratedFiles(projectData, context)

                case 'final'
                    generatedFilesId = strjoin(sort({ecdObj.Hash}), ' - ');

                    JSONFile = '';
                    if strcmp(context, 'ECD')
                        JSONFile = [baseFullFileName '.json'];
                        JSONContent = reportLibConnection.Table.scarabJsonFile(projectData, context, ecdObj);
                        writematrix(JSONContent, JSONFile, "FileType", "text", "QuoteStrings", "none", "Encoding", "UTF-8")
                    end

                    ZIPFile  = ui.Dialog(mainApp.UIFigure, 'uiputfile', '', {'*.zip', 'monitorSPED (*.zip)'}, fullfile(generalSettings.fileFolder.userPath, [baseFileName '.zip']));
                    if isempty(ZIPFile)
                        return
                    end

                    ZIPFileList = {HTMLFile};
                    if ~isempty(JSONFile)
                        ZIPFileList{end+1} = JSONFile;
                    end
                    zip(ZIPFile, ZIPFileList)
                    updateGeneratedFiles(projectData, context, ecdObj, generatedFilesId, {}, HTMLFile, JSONFile, ZIPFile)
            end
        end
    end
end