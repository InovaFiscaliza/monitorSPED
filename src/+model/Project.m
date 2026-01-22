classdef Project < handle

    properties
        %-----------------------------------------------------------------%
        name
        file
        hash

        modules
        report = struct('templates', [], 'settings',  [])
        
        issueDetails = struct('system', {}, 'issue', {}, 'details', {}, 'timestamp', {})
        entityDetails = struct('id', {}, 'details', {}, 'timestamp', {})

        inss
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        mainApp
        rootFolder
    end


    methods
        %-----------------------------------------------------------------%
        function obj = Project(mainApp, rootFolder)
            obj.mainApp = mainApp;
            obj.rootFolder = rootFolder;
            
            obj.inss = model.ProjectBase.readInssReferenceData(rootFolder);
            contextInitialization(obj, {'FILE', 'ECD'}, mainApp.General)
        end

        %-----------------------------------------------------------------%
        function contextInitialization(obj, contextList, generalSettings)
            % O "id", do "generatedFiles", é a lista ordenada de "hashs" dos registros 
            % que compõem "inspectedProducts".

            obj.name = '';
            obj.file = '';
            obj.hash = '';

            for ii = 1:numel(contextList)
                context = contextList{ii};
                obj.modules.(context) = struct( ...
                    'annotationTable', [], ...
                    'generatedFiles', struct( ...
                        'id', '', ...
                        'rawFiles', {{}}, ...
                        'lastHTMLDocFullPath', '', ...
                        'lastJSONFullPath', '', ...
                        'lastTableFullPath', '', ...
                        'lastZIPFullPath', '' ...
                    ), ...
                    'uploadedFiles', struct( ...
                        'hash', {}, ...
                        'system', {}, ...
                        'issue', {}, ...
                        'status', {}, ...
                        'timestamp', {} ...
                    ), ...
                    'ui', struct( ...
                        'system', '', ...
                        'unit',   '',  ...
                        'issue',  -1,  ...
                        'templates', {{}}, ...
                        'reportModel', '',  ...
                        'reportVersion', 'Preliminar', ...
                        'entityTypes', {{}},  ...
                        'entity', struct( ...
                            'type', '', ...
                            'name', '', ...
                            'id',   '', ...
                            'status', false ...
                        ) ...
                    ) ...
                );

                obj.modules.(context).ui.entityTypes = generalSettings.ui.typeOfEntity.options;
                obj.modules.(context).ui.entity.type = generalSettings.ui.typeOfEntity.default;
            end

            ReadReportTemplates(obj, obj.rootFolder)
        end

        %-----------------------------------------------------------------%
        function updateNeeded = checkIfUpdateNeeded(obj, ecdObj)
            updateNeeded = false;
            
            if ~isempty(obj.name)
                currentPrjHash = model.ProjectBase.computeProjectHash(obj.name, obj.file, ecdObj, obj.issueDetails, obj.entityDetails);
                updateNeeded   = ~isequal(obj.hash, currentPrjHash);
            end
        end

        %-----------------------------------------------------------------%
        % ## SAVE ##
        %-----------------------------------------------------------------%
        function save(obj, ecdObj, prjName, prjFile, outputFileCompressionMode)
            arguments
                obj
                ecdObj
                prjName
                prjFile
                outputFileCompressionMode
            end

            source    = class.Constants.appName;
            type      = 'ProjectData';
            version   = 2;
            userData  = [];

            prjHash  = model.ProjectBase.computeProjectHash(prjName, prjFile, ecdObj, obj.issueDetails, obj.entityDetails);
            variables = struct( ...
                'name',    prjName, ...
                'hash',    prjHash, ...
                'modules', obj.modules, ...
                'issueDetails', obj.issueDetails, ...
                'entityDetails', obj.entityDetails, ...
                'ecdData', ecdObj ...
            );

            compressionMode = '';
            if strcmp(outputFileCompressionMode, 'Não')
                compressionMode = '-nocompression';
            end

            save(prjFile, 'source', 'type', 'version', 'variables', 'userData', '-mat', '-v7', compressionMode)

            obj.name = prjName;
            obj.file = prjFile;
            obj.hash = prjHash;
        end

        %-----------------------------------------------------------------%
        % ## LOAD ##
        %-----------------------------------------------------------------%
        function [ecdObj, msg] = load(obj, ecdObj, fileName, generalSettings)
            % Em 10/12/2025, a versão 1 do projeto contempla instâncias das 
            % classes model.ECD e model.projectLib. Ao ler um arquivo .mat, 
            % usando função "load", o MATLAB realiza validações simples, como
            % adicionar novas propriedades (com valores padrão) ou remover 
            % outras que não existem mais (independentemente do seu conteúdo). 

            % A seguir lista com principais propriedades de cada classe.
            % • model.ECD
            %   "FileName", "FileFullName", "Size", "Hash", "Encoding", "EncodingInfo", 
            %   "Content", "Layout", "Table", "CompanyName", "CompanyId", "CompanyInfo", 
            %   "State", "Period", "PeriodMerged", "Sources" e "GUI".            
            % • model.projectLib
            %   "name", "file", "report", "modules" e "INSS".

            % A alteração da forma de organização da informação no app pode 
            % demandar a criação de outras versões (2, 3...) do arquivo de 
            % projeto (.mat), o que deve vir acompanhado de parsers para manter 
            % compatibilidade, caso viável.

            try
                required = {'source', 'version', 'variables'};
                varsInFile = who('-file', fileName);
                if any(~ismember(required, varsInFile))
                    missing = setdiff(required, varsInFile);
                    error('Missing required variables: %s', strjoin(missing, ', '))
                end
                
                prjData = load(fileName, '-mat', required{:});
                
                if ~strcmp(class.Constants.appName, source)
                    error('File generated by a different application. Expected: %s. Found: %s.', class.Constants.appName, appName)
                end
    
                switch prjData.version
                    case 1
                        obj.name = prjData.name;
                        obj.file = fileName;
                        obj.hash = prjData.hash;
    
                        context = prjData.context;

                        if isfile(prjData.generatedFiles.lastZIPFullPath)
                            try
                                unzipFiles = unzip(prjData.generatedFiles.lastZIPFullPath, generalSettings.fileFolder.tempPath);
                                for ii = 1:numel(unzipFiles)
                                    [~, ~, unzipFileExt] = fileparts(unzipFiles{ii});

                                    switch lower(unzipFileExt)
                                        case '.html'
                                            obj.modules.(context).generatedFiles.lastHTMLDocFullPath = unzipFiles{ii};
                                        case '.json'
                                            obj.modules.(context).generatedFiles.lastTableFullPath   = unzipFiles{ii};
                                    end
                                end
                                
                                obj.modules.(context).generatedFiles.id              = prjData.generatedFiles.id;
                                obj.modules.(context).generatedFiles.lastZIPFullPath = prjData.generatedFiles.lastZIPFullPath;
                            catch 
                            end
                        end

                        obj.modules.(context).ui.system       = prjData.ui.system;
                        obj.modules.(context).ui.unit         = prjData.ui.unit;
                        obj.modules.(context).ui.issue        = prjData.ui.issue;
                        obj.modules.(context).ui.issueDetails = prjData.ui.issueDetails;
    
                        reportModel = prjData.ui.reportModel;
                        if ismember(reportModel, obj.modules.(context).ui.templates)
                            obj.modules.(context).ui.reportModel = reportModel;
                        end

                        % Pode ocorrer uma coincidência de fluxos que compõem
                        % o projeto e fluxos já lidos. Se evidenciado, serão
                        % mantidos os fluxos do projeto.
                        idx = ismember({ecdObj.Hash}, {ecdData.Hash});
                        if any(idx)
                            delete(ecdObj(idx))
                            ecdObj(idx) = [];
                        end
    
                        ecdObj = [ecdObj, ecdData];
    
                    otherwise
                        error('UnexpectedVersion')
                end
                msg = '';

            catch ME
                msg = ME.message;
            end
        end

        %-----------------------------------------------------------------%
        % ## INSS ##
        %-----------------------------------------------------------------%
        function [rate, msgError] = calculateInssRate(obj, state, period, rateType, numDecimals)
            arguments
                obj
                state    char {mustBeMember(state, {'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO'})}
                period   datetime
                rateType char {mustBeMember(rateType, {'mean', 'eomonth'})} = 'mean'
                numDecimals double = 3
            end
            
            Year = year(period);
            Month = month(period);
            endOfMonthDay = eomday(Year, Month);

            % Identifica limites do período sob análise:
            beginOfPeriod = datetime([Year, Month, 1]);
            endOfPeriod   = datetime([Year, Month, endOfMonthDay]);

            try    
                % Identifica registros relacionados à UF indicada:
                indexes = find(strcmp(obj.inss.("UF"), state) & obj.inss.("Vigência") <= endOfPeriod);            
                if isempty(indexes)
                    error('Não identificado registro que possibilite calcular a alíquota vigente de INSS')
                end
    
                refINSSTable = obj.inss(indexes, :);
                switch rateType
                    case 'mean'
                        refNumDays = endOfMonthDay;            
                        rate = 0;
                        for ii = height(refINSSTable):-1:1
                            numDays    = refNumDays - day(max(refINSSTable.("Vigência")(ii), beginOfPeriod)) + 1;
                            rate   = rate + numDays * refINSSTable.("Alíquota máxima")(ii);
                            refNumDays = refNumDays - numDays;
                            if refNumDays <= 0
                                break
                            end
                        end
                        rate = rate/endOfMonthDay;
    
                    case 'eomonth'
                        rate = refINSSTable.("Alíquota máxima")(end);
                end
                msgError = '';

            catch ME
                index = find(strcmp(obj.inss.("UF"), state), 1);
                rate = obj.inss.("Alíquota máxima")(index);
                msgError = sprintf('[INSS Fallback] ∄ alíquota no domínio (%s, %s) ⇒ %.1f%%', state, endOfPeriod, 100 * rate);
            end

            rate = round(rate, numDecimals);
        end

        %-----------------------------------------------------------------%
        % ## VALIDATION ##
        %-----------------------------------------------------------------%
        function status = validateReportRequirements(obj, context, requirement)
            arguments
                obj 
                context 
                requirement {mustBeMember(requirement, {'issue', 'unit', 'reportModel', 'entity'})}
            end
            switch requirement
                case 'issue'
                    issue  = obj.modules.(context).ui.issue;
                    status = (issue > 0) && (issue < inf);
                case 'unit'
                    status = ~isempty(obj.modules.(context).ui.unit);
                case 'reportModel'
                    status = ~isempty(obj.modules.(context).ui.reportModel);
                case 'entity'
                    entity = obj.modules.(context).ui.entity;
                    status = ~isempty(entity.type) && ~isempty(entity.name) && (strcmp(entity.type, 'Importador') || entity.status);
            end
        end

        %-----------------------------------------------------------------%
        % ## UPDATE ##
        %-----------------------------------------------------------------%
        function updateGeneratedFiles(obj, context, id, rawFiles, htmlFile, jsonFile, tableFile, zipFile)
            arguments
                obj
                context   (1,:) char {mustBeMember(context, {'FILE', 'ECD'})}
                id        char = ''
                rawFiles  cell = {}
                htmlFile  char = ''
                jsonFile  char = ''
                tableFile char = ''
                zipFile   char = ''
            end

            obj.modules.(context).generatedFiles.id                  = id;
            obj.modules.(context).generatedFiles.rawFiles            = rawFiles;
            obj.modules.(context).generatedFiles.lastHTMLDocFullPath = htmlFile;
            obj.modules.(context).generatedFiles.lastJSONFullPath    = jsonFile;
            obj.modules.(context).generatedFiles.lastTableFullPath   = tableFile;
            obj.modules.(context).generatedFiles.lastZIPFullPath     = zipFile;
        end

        %-----------------------------------------------------------------%
        function updateUploadedFiles(obj, context, system, issue, status)
            arguments
                obj
                context (1,:) char {mustBeMember(context, {'FILE', 'ECD'})}
                system
                issue
                status
            end

            obj.modules.(context).uploadedFiles(end+1) = struct( ...
                'hash', model.ProjectBase.computeUploadedFileHash(system, issue, status), ...
                'system', system, ...
                'issue', issue, ...
                'status', status, ...
                'timestamp', datestr(now) ...
            );
        end

        %-----------------------------------------------------------------%
        function updateUiInfo(obj, context, fieldName, fieldValue)
            arguments
                obj
                context    (1,:) char {mustBeMember(context, {'self', 'FILE', 'ECD'})}
                fieldName  (1,:) char
                fieldValue
            end

            switch fieldName
                case {'name', 'file', 'hash'}
                    obj.(fieldName) = fieldValue;

                case 'issueDetails'
                    [~, issueIndex] = ismember(fieldValue.issue, [obj.issueDetails.issue]);
                    if ~issueIndex
                        issueIndex = numel(obj.issueDetails) + 1;
                    end                    
                    obj.issueDetails(issueIndex) = fieldValue;

                case 'entityDetails'
                    [~, entityIdIndex] = ismember(fieldValue.id, {obj.entityDetails.id});
                    if ~entityIdIndex
                        entityIdIndex = numel(obj.entityDetails) + 1;
                    end                    
                    obj.entityDetails(entityIdIndex) = fieldValue;

                otherwise
                    obj.modules.(context).ui.(fieldName) = fieldValue;
            end
        end

        %-----------------------------------------------------------------%
        % ## GET ##
        %-----------------------------------------------------------------%
        function fileName = getGeneratedDocumentFileName(obj, fileExt, context)
            arguments
                obj
                fileExt (1,:) char {mustBeMember(fileExt, {'.html', '.xlsx', '.zip'})}
                context (1,:) char {mustBeMember(context, {'FILE', 'ECD'})}
            end

            switch fileExt
                case '.html'
                    fileName = obj.modules.(context).generatedFiles.lastHTMLDocFullPath;
                case '.json'
                    fileName = obj.modules.(context).generatedFiles.lastJSONFullPath;
                case '.xlsx'
                    fileName = obj.modules.(context).generatedFiles.lastTableFullPath;
                case '.zip'
                    fileName = obj.modules.(context).generatedFiles.lastZIPFullPath;
            end

            if ismember(fileExt, {'.html', '.zip'}) && ~isempty(fileName) && ~isfile(fileName)
                fileName = '';
                updateGeneratedFiles(obj, context)
            end
        end

        %-----------------------------------------------------------------%
        function uploadedFiles = getUploadedFiles(obj, context, system, issue)
            arguments
                obj
                context (1,:) char {mustBeMember(context, {'FILE', 'ECD'})}
                system
                issue
            end

            uploadedFiles = obj.modules.(context).uploadedFiles;
            if ~isempty(uploadedFiles)
                uploadedFiles = uploadedFiles(strcmp({uploadedFiles.system}, system) & [uploadedFiles.issue] == issue);
            end
        end

        %-----------------------------------------------------------------%
        function details = getIssueDetailsFromCache(obj, system, issue)
            detailsIndex = find(strcmp({obj.issueDetails.system}, system) & [obj.issueDetails.issue] == issue, 1);
            
            if ~isempty(detailsIndex)
                details  = obj.issueDetails(detailsIndex).details;
            else
                details  = '';
            end
        end

        %-----------------------------------------------------------------%
        function details = getEntityDetailsFromCache(obj, id)
            [~, entityIndex] = ismember(id, {obj.entityDetails.id});
            
            if entityIndex
                details = obj.entityDetails(entityIndex).details;
            else
                details = '';      
            end
        end

        %-----------------------------------------------------------------%
        % ## GET/FETCH ##
        %-----------------------------------------------------------------%
        function [details, msgError] = getOrFetchIssueDetails(obj, system, issue, eFiscalizaObj)
            details  = getIssueDetailsFromCache(obj, system, issue);
            msgError = '';

            if isempty(details)
                try
                    env = strsplit(system);
                    if isscalar(env)
                        env = 'PD';
                    else
                        env = env{2};
                    end
    
                    issueInfo = struct( ...
                        'type', 'ATIVIDADE DE INSPEÇÃO', ...
                        'id', issue ...
                    );
                    
                    response = run(eFiscalizaObj, env, 'queryIssue', issueInfo);
                    if isstruct(response)
                        details = struct( ...
                            'system', system, ...
                            'issue', issue, ...
                            'details', response, ...
                            'timestamp', datestr(now) ...
                        );
                        updateUiInfo(obj, 'self', 'issueDetails', details)
    
                    else
                        error(response)
                    end    
                catch ME
                    msgError = ME.message;
                end              
            end
        end

        %-----------------------------------------------------------------%
        function [details, msgError] = getOrFetchEntityDetails(obj, id)
            details  = getEntityDetailsFromCache(obj, id);
            msgError = '';

            if isempty(details)
                [entityId, ~, details, msgError] = checkCNPJOrCPF(id, 'PublicAPI');

                if ~isempty(details)
                    updateUiInfo(obj, 'self', 'entityDetails', struct('id', entityId, 'details', details, 'timestamp', datestr(now)))
                end                
            end
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function ReadReportTemplates(obj, rootFolder)
            [projectFolder, ...
             programDataFolder] = appEngine.util.Path(class.Constants.appName, rootFolder);
            projectFilePath  = fullfile(projectFolder,     'ReportTemplates.json');
            externalFilePath = fullfile(programDataFolder, 'ReportTemplates.json');

            try
                if ~isdeployed()
                    error('ForceDebugMode')
                end
                obj.report.templates = jsondecode(fileread(externalFilePath));
            catch
                obj.report.templates = jsondecode(fileread(projectFilePath));
            end

            % Identifica lista de templates por módulo...
            contextList = fieldnames(obj.modules);
            templateNameList = {obj.report.templates.Name};

            for ii = 1:numel(contextList)
                templateIndexes = ismember({obj.report.templates.Module}, contextList(ii));
                obj.modules.(contextList{ii}).ui.templates = [{''}, templateNameList(templateIndexes)];
            end
        end
    end
    
end