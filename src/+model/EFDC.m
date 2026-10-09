classdef EFDC < model.SPED

    % SINTAXE:
    % >> efdcObj = model.EFDC.empty;
    % >> efdcObj = addFiles(efdcObj, {'Filename1.txt', 'Filename2.txt'});
    %
    % EFD Contribuições (EFDC): Escritura Fiscal Digital da Contribuição para o PIS/PASEP,
    % da COFINS e da Contribuição Previdenciária sobre a Receita Bruta (CPRB).
    % Layout 1.35+ (versão do guia prático de junho 2021)

    properties
        %-----------------------------------------------------------------%
        GUI = struct( ...
            'isRead', false,  ...
            'hasValidStatus', false, ...
            'hasValidPeriod', false, ...
            'warnings', {{}}, ...
            'tableIds', {{}}, ...
            'tableView', struct( ...
                'id', {}, ...
                'filter', {}, ...
                'style', {}, ...
                'sort', {}, ...
                'width', {} ...
            ), ...
            'loadedFile', struct('Name', '', 'Index', -1) ...
        )
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        function [obj, msg] = addFiles(obj, fileNameList, generalSettings, receitaFederalObj)
            if ~iscellstr(fileNameList)
                fileNameList = cellstr(fileNameList);
            end

            msg = {};

            for ii = 1:numel(fileNameList)
                fileFullName = fileNameList{ii};
                [~, fileName, fileExt] = fileparts(fileFullName);
                fileName = [fileName, fileExt];

                if any(arrayfun(@(x) isequal(x.FileName, fileName), obj))
                    continue
                end

                idx = numel(obj)+1;                

                try
                    obj(idx) = model.EFDC(); % constrói explicitamente
                    obj(idx).FileName = fileName;
                    obj(idx).FileFullName = fileFullName;
                    obj(idx).FileType = 'EFDC'; % 'EFD CONTRIBUIÇÕES'

                    util.fileread_EFDC(obj(idx), fileFullName, generalSettings);
                    initializeCompanyContext(obj(idx), generalSettings, receitaFederalObj)

                catch ME
                    struct2table(ME.stack)
                    delete(obj(idx))
                    obj(idx) = [];
                    msg{end+1} = ME.message;
                end
            end

            msg = strjoin(msg, '\n');
        end

        %-----------------------------------------------------------------%
        function parseTableAndAddToCache(obj, tableIdList, generalSettings)
            arguments
                obj
                tableIdList cell {mustBeText}
                generalSettings
            end

            if isequal(tableIdList, {'all'})
                isRead = true;
                tableIdList = model.EFDCBase.getImplementedTableIds();
            end

            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};
                    tableIdField = ['x' tableId];
                    
                    if isfield(obj(ii).Table, tableIdField) && istable(obj(ii).Table.(tableIdField))
                        continue
                    end

                    parseTable(obj(ii), tableId, generalSettings);
                    if isfield(obj(ii).Table, tableIdField) && ~isempty(obj(ii).Table.(tableIdField))
                        obj.Table.(tableIdField) = model.ECDBase.normalizeStringColumns(obj.Table.(tableIdField));
                    end
                end

                if exist('isRead', 'var')
                    obj(ii).GUI.isRead = isRead;
                end
            end
        end

        %-----------------------------------------------------------------%
        function status = isTableRead(obj, tableIdList, generalSettings)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
                generalSettings
            end

            status = false;
            for ii = 1:numel(obj)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};
                    tableIdStatus = isfield(obj(ii).Table, ['x' tableId]) && istable(obj(ii).Table.(['x' tableId]));

                    if ~tableIdStatus
                        status = true;
                        parseTableAndAddToCache(obj(ii), {tableId}, generalSettings)
                    end
                end
            end
        end

        %-----------------------------------------------------------------%
        function columnsSpec = getColumnSpecifications(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
            end

            checkIfScalar(obj)

            for ii = 1:numel(tableIdList)
                tableId = tableIdList{ii};
                definition = model.EFDCBase.(['x' tableId]);
                layoutIdx = find(cellfun(@(x) ismember(obj.Layout, x), definition(:, 1)), 1);
                if isempty(layoutIdx)
                    layoutIdx = size(definition, 1);
                end

                required = definition{layoutIdx, 2};
                optional = definition{layoutIdx, 3};
                complete = [required, optional];

                columnsSpec(ii) = struct( ...
                    'id', tableId, ...
                    'required', {required}, ...
                    'optional', {optional}, ...
                    'complete', {complete} ...
                );
            end
        end

        %-----------------------------------------------------------------%
        function [status, msg] = validateReportGenerationRequirements(obj)
            % placeholder for EFDC
            status = true;
            msg = '';
        end

        %-----------------------------------------------------------------%
        function update(obj, propertyName, updateType, varargin)
            arguments
                obj
                propertyName char {mustBeMember(propertyName, { 'GUI.TableIds'; 'Table.NonEssentialFiles' })}
                updateType
            end

            arguments (Repeating)
                varargin
            end

            checkIfScalar(obj)

            switch propertyName
                case 'GUI.TableIds'
                    generalSettings = varargin{1};
                    sheetsSorted = extractAfter(fieldnames(obj.Table), 'x');
                    if ~isempty(obj.Content)
                        sheetsSorted = [sheetsSorted; generalSettings.context.EFDC.customTables.expected];
                    end
                    sheetsSorted = unique(sheetsSorted);
                    obj.GUI.tableIds = sheetsSorted;

                case 'Table.NonEssentialFiles'
                    switch updateType
                        case 'onCacheCleanup'
                            if isempty(varargin{1})
                                return
                            end
                            tableIdList = strcat({'x'}, varargin{1});
                            tableIdList = tableIdList(isfield(obj.Table, tableIdList));
                            obj.Table = rmfield(obj.Table, tableIdList);

                        otherwise
                            error('model:EFDC:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                otherwise
                    error('model:EFDC:UnexpectedPropertyName', 'Unexpected property name "%s".', propertyName);
            end
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function initializeCompanyContext(obj, generalSettings, receitaFederalObj)
            if isfield(obj.Table, 'x0000') && ~isempty(obj.Table.x0000)
                obj.Table.x0000 = sortrows(obj.Table.x0000, 'DT_INI');
                
                obj.CompanyName = upper(strtrim(obj.Table.x0000.NOME{end}));
                obj.CompanyId = checkCNPJOrCPF(obj.Table.x0000.CNPJ{end}, 'NumberValidation');
                obj.CompanyInfo(1) = struct( ...
                    'CNPJ', obj.Table.x0000.CNPJ{end}, ...
                    'IE', '', ...
                    'IM', '', ...
                    'NIRE', '', ...
                    'UF', obj.Table.x0000.UF{end}, ...
                    'City', obj.Table.x0000.COD_MUN{end} ...
                );

                obj.State = obj.CompanyInfo.UF;
                if isdatetime(obj.Table.x0000.DT_INI) && isdatetime(obj.Table.x0000.DT_FIN)
                    obj.Period = [min(obj.Table.x0000.DT_INI), max(obj.Table.x0000.DT_FIN)];
                    obj.Period.Format = 'dd/MM/yyyy';
                end
            end

            if ~isempty(receitaFederalObj)
                checkFileStatus(obj, receitaFederalObj, generalSettings.context.FILE.encodingList);
            end

            obj.GUI.hasValidPeriod = checkIfValidPeriod(obj);
            obj.GUI.hasValidStatus = checkIfValidStatus(obj);
        end
    end


    methods (Access = protected)
        %-----------------------------------------------------------------%
        function parseTable(obj, tableId, generalSettings)
            checkIfScalar(obj)

            compositeSheets = model.EFDCBase.efdcCompositeSheets();
            compositeField  = ['x' tableId];
            if isfield(compositeSheets, compositeField)
                recordIds = compositeSheets.(compositeField);
            else
                recordIds = {tableId};
            end

            util.fileread_EFDC(obj, obj.FileFullName, generalSettings, false, recordIds)
        end
    end
end
