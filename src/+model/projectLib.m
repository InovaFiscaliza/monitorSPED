classdef projectLib < handle

    properties
        %-----------------------------------------------------------------%
        name  (1,:) char
        file  (1,:) char
        issue (1,1) double
        unit  (1,:) char

        documentType {mustBeMember(documentType, {'Relatório de Atividades', 'Relatório de Fiscalização', 'Informe'})} = 'Relatório de Atividades'
        documentModel
        documentScript
        generatedFiles

        INSS
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        mainApp
        rootFolder
        defaultFilePreffix = 'monitorSPED'
    end


    methods
        %-----------------------------------------------------------------%
        function obj = projectLib(mainApp, generalSettings)            
            obj.mainApp    = mainApp;
            obj.rootFolder = mainApp.rootFolder;

            Restart(obj)
            ReadINSSReferenceTable(obj, generalSettings)
        end

        %-----------------------------------------------------------------%
        function Restart(obj)
            obj.name           = '';
            obj.file           = '';
            obj.issue          = -1;
            obj.unit           = '';

            obj.documentType   = 'Relatório de Atividades';
            obj.documentScript = [];
            obj.generatedFiles = [];
        end

        %-----------------------------------------------------------------%
        function ReadReportTemplates(obj)
            [projectFolder, ...
             programDataFolder] = appUtil.Path(class.Constants.appName, obj.rootFolder);
            projectFilePath  = fullfile(projectFolder,     'ReportTemplates.json');
            externalFilePath = fullfile(programDataFolder, 'ReportTemplates.json');

            try
                if ~isdeployed()
                    error('ForceDebugMode')
                end
                obj.documentModel = jsondecode(fileread(externalFilePath));
            catch
                obj.documentModel = jsondecode(fileread(projectFilePath));
            end
        end

        %-----------------------------------------------------------------%
        function ReadINSSReferenceTable(obj, generalSettings)
            % ...
        end
    end
    
end