classdef (Abstract) ProjectBase

    % ## model.ProjectBase ##      
    % - *.*
    %   ├── computeProjectHash (Static)
    %   └── ...
    %       └── ...

    properties (Constant)
    %---------------------------------------------------------------------%
    % ...
    end


    methods (Static = true)
        %-----------------------------------------------------------------%
        function data = readInssReferenceData(rootFolder)
            [projectFolder, ...
             localCacheFolder] = appEngine.util.Path(class.Constants.appName, rootFolder);
            projectFilePath    = fullfile(projectFolder,    'DataBase', 'INSS.xlsx');
            localCacheFilePath = fullfile(localCacheFolder, 'DataBase', 'INSS.xlsx');

            try
                if ~isdeployed()
                    error('ForceDebugMode')
                end
                data = readtable(localCacheFilePath, 'UseExcel', false, 'VariableNamingRule', 'preserve');
            catch
                data = readtable(projectFilePath,    'UseExcel', false, 'VariableNamingRule', 'preserve');
            end
        end

        %-----------------------------------------------------------------%
        function hash = computeReportFileInventoryHash(ecdObj)
            hash = strjoin(sort({ecdObj.Hash}), ' - ');
        end

        %-----------------------------------------------------------------%
        function hash = computeReportAnalysisResultsHash(ecdObj)
            hash = model.ProjectBase.computeProjectHash('', '', ecdObj, [], []);
        end

        %-----------------------------------------------------------------%
        function hash = computeProjectHash(prjName, prjFile, ecdObj, issueDetails, entityDetails)
            hashList = sort({ecdObj.Hash});

            annotationTable = [];
            for ii = 1:numel(ecdObj)
                if isfield(ecdObj(ii).Table, 'x_CONTAS_ANOTACAO') && ~isempty(ecdObj(ii).Table.x_CONTAS_ANOTACAO)
                    if isempty(annotationTable)
                        annotationTable = ecdObj(ii).Table.x_CONTAS_ANOTACAO;
                    else
                        annotationTable = [annotationTable; ecdObj(ii).Table.x_CONTAS_ANOTACAO];
                    end
                end
            end

            if ~isempty(annotationTable)
                annotationTable = sortrows(annotationTable, 'COD_CTA');
            end

            hash = Hash.sha1(sprintf('%s - %s - %s - %s - %s - %s', prjName, prjFile, strjoin(hashList, ' - '), jsonencode(annotationTable), jsonencode(issueDetails), jsonencode(entityDetails)));
        end
    end
    
end