classdef EFD < model.SPED

    % SINTAXE:
    % >> efdObj = model.EFD.empty;
    % >> efdObj = addFiles(efdObj, {'Filename1.txt', 'Filename2.txt'});

    properties
        %-----------------------------------------------------------------%
        GUI = struct( ...
            'isRead', false,  ...
            'hasTransactions', false, ...
            'hasValidStatus', false, ...
            'hasValidPeriod', false, ...
            'warnings', {{}}, ...
            'icmsRate', struct( ...
                'source', 'default', ... % 'default' | 'manual'
                'default', struct('mode', 'auto', 'rate', []), ...
                'current', struct('mode', 'auto', 'rate', []) ...
            ), ...
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
                    obj(idx).FileName = fileName;
                    obj(idx).FileFullName = fileFullName;
                    obj(idx).FileType = 'EFDI'; % 'EFD ICMS/IPI'

                    util.fileread_EFD(obj(idx), fileFullName, generalSettings);
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
                tableIdList = model.EFDBase.getImplementedTableIds();
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

                    % Valida se foi lido o número de linhas esperado...
                    expectedRows = expectedRowsByTableId(obj, tableId);
                    if ~isempty(expectedRows) && expectedRows > 0
                        readRows = height(obj(ii).Table.(['x' tableId]));                            
                        if expectedRows ~= readRows
                            obj(ii).GUI.warnings{end+1} = matlab.jsonencode(struct( ...
                                'id', tableId, ...
                                'message', sprintf('expectedRows: %d, readRows: %d', expectedRows, readRows) ...
                            ));
                        end
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
                definition = model.EFDBase.(['x' tableId]);
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
        function expectedRows = expectedRowsByTableId(obj, tableId)
            checkIfScalar(obj)

            expectedRows = [];
            if isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                tableIdIndex = find(strcmp(obj.Table.x9900.('REG_BLC'), tableId));
                if ~isempty(tableIdIndex)
                    expectedRows = sum(obj.Table.x9900.('QTD_REG_BLC')(tableIdIndex));
                end
            end
        end

        %-----------------------------------------------------------------%
        function exportMacroLikeWorkbook(obj, outputFile)
            arguments
                obj (1,1) model.EFD
                outputFile (1,:) char
            end

            checkIfScalar(obj)

            sheetMap = {
                '0000',            'x0000';
                '0100',            'x0100';
                '0150',            'x0150';
                '0200',            'x0200';
                '0400',            'x0400';
                '0450',            'x0450';
                '0460',            'x0460';
                '0500',            'x0500';
                '0600',            'x0600';
                '1400',            'x1400';
                'C100_C170_C190',  'xC100_C170_C190';
                'D500_D510_D590',  'xD500_D510_D590';
                'D695_D696_D697',  'xD695_D696_D697';
                'D700_E_FILHOS',   'xD700_E_FILHOS';
                'D750_D760_D761',  'xD750_D760_D761'
            };

            if isfile(outputFile)
                delete(outputFile)
            end

            for ii = 1:size(sheetMap, 1)
                sheetName = sheetMap{ii, 1};
                fieldName = sheetMap{ii, 2};

                if ~isfield(obj.Table, fieldName) || ~istable(obj.Table.(fieldName))
                    continue
                end

                writetable(obj.Table.(fieldName), outputFile, 'Sheet', sheetName, 'WriteMode', 'overwritesheet', 'UseExcel', false)
            end
        end

        %-----------------------------------------------------------------%
        function update(obj, propertyName, updateType, varargin)
            arguments
                obj
                propertyName char {mustBeMember(propertyName, { 'GUI.TableIds';
                                                                'GUI.TableView.Filter';
                                                                'GUI.TableView.Style';
                                                                'GUI.TableView.Sort';
                                                                'GUI.TableView.Width';
                                                                'GUI.IcmsRate';
                                                                'Table.NonEssentialFiles';
                                                                'Table.x_CONTAS_ANOTACAO';
                                                                'Table.x_APURACAO_GERAL'; ...
                                                                'Table.x_CONCILIACAO' })}
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
                        sheetsSorted = [sheetsSorted; getTableIds(obj); generalSettings.context.EFD.customTables.expected];
                    end
                    sheetsSorted = unique(sheetsSorted);
                    sheetsSorted = [sheetsSorted(startsWith(sheetsSorted, '_')); sheetsSorted(~startsWith(sheetsSorted, '_'))];
                    
                    obj.GUI.tableIds = sheetsSorted;

                case 'GUI.TableView.Filter'
                    switch updateType
                        case 'createFilteringObject'
                            tableId = varargin{1};
                            filterIdx = varargin{2};
                            obj.GUI.tableView(filterIdx).id     = tableId;
                            obj.GUI.tableView(filterIdx).filter = tableFiltering;

                        otherwise
                            error('model:EFD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'GUI.TableView.Style'
                    switch updateType
                        case 'addStyle'
                            tableId = varargin{1};
                            styleIdx = varargin{2};
                            styleConfig = varargin{3};
                            obj.GUI.tableView(styleIdx).id = tableId;
                            obj.GUI.tableView(styleIdx).style = styleConfig;

                        case 'removeSelectedCellStyle'
                            styleIdx = varargin{1};
                            styleConfig = varargin{2};
                            obj.GUI.tableView(styleIdx).style = styleConfig;

                        case 'removeTableStyle'
                            styleIdx = varargin{1};                            
                            obj.GUI.tableView(styleIdx).style = {};

                        otherwise
                            error('model:EFD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'GUI.TableView.Sort'
                    tableId = varargin{1};
                    [~, displayIdx] = ismember(tableId, {obj.GUI.tableView.id});

                    switch updateType
                        case 'applySort'
                            if ~displayIdx
                                displayIdx = numel(obj.GUI.tableView) + 1;
                            end

                            columnName = varargin{2};
                            dataIdxs = varargin{3};

                            obj.GUI.tableView(displayIdx).id   = tableId;
                            obj.GUI.tableView(displayIdx).sort = struct( ...
                                'columnName', columnName, ...
                                'dataIdxs', dataIdxs ...
                            );

                        case 'clearSort'
                            if displayIdx
                                obj.GUI.tableView(displayIdx).sort = [];
                            end

                        otherwise
                            error('model:EFD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end

                case 'GUI.TableView.Width'
                    tableId = varargin{1};
                    [~, widthIdx] = ismember(tableId, {obj.GUI.tableView.id});

                    switch updateType
                        case 'updateColumnWidths'
                            displayedColumnCount = varargin{2};
                            columnWidthUpdates = varargin{3};

                            if widthIdx && isfield(obj.GUI.tableView(widthIdx), 'width') && ~isempty(obj.GUI.tableView(widthIdx).width)
                                widthCells = obj.GUI.tableView(widthIdx).width;
                                if numel(widthCells) ~= displayedColumnCount
                                    widthCells = repmat({'auto'}, 1, displayedColumnCount);
                                end

                            else
                                widthIdx = numel(obj.GUI.tableView) + 1;
                                widthCells = repmat({'auto'}, 1, displayedColumnCount);
                            end

                            widths = str2double(extractBefore({columnWidthUpdates.width}, 'px'));
                            widthCells([columnWidthUpdates.idx]) = num2cell(widths);

                            widthCells(cellfun(@(x) isequal(x, 10), widthCells)) = {'1x'};
                            widthCells(cellfun(@(x) isequal(x, 75), widthCells)) = {'auto'};

                            obj.GUI.tableView(widthIdx).id    = tableId;
                            obj.GUI.tableView(widthIdx).width = widthCells;

                        case 'resetColumnWidths'
                            if widthIdx
                                obj.GUI.tableView(widthIdx).width = [];
                            end

                        otherwise
                            error('model:EFD:UnexpectedUpdateType', 'Unexpected update type "%s" for property "%s".', updateType, propertyName);
                    end
            end
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function initializeCompanyContext(obj, generalSettings, receitaFederalObj)
            if isfield(obj.Table, 'x0000') && ~isempty(obj.Table.x0000)
                obj.Table.x0000 = sortrows(obj.Table.x0000, 'DT_INI');
                obj.CompanyName = upper(strtrim(obj.Table.x0000.NOME{end}));
                obj.CompanyId = obj.Table.x0000.CNPJ{end};
                obj.CompanyInfo(1) = struct( ...
                    'CNPJ', obj.Table.x0000.CNPJ{end}, ...
                    'IE', obj.Table.x0000.IE{end}, ...
                    'IM', obj.Table.x0000.IM{end}, ...
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

            if isfield(obj.Table, 'x_RESULTADOS') && ~isempty(obj.Table.x_RESULTADOS)
                sourceFiles = obj.Table.x_RESULTADOS.ARQUIVO_ZIP_INTERNO;
                payloadNames = obj.Table.x_RESULTADOS.PAYLOAD;
                for ii = 1:height(obj.Table.x_RESULTADOS)
                    obj.Sources(end+1) = struct( ...
                        'file', sourceFiles{ii}, ...
                        'period', obj.Period, ...
                        'encoding', obj.Encoding, ...
                        'terminator', obj.TERMINATOR, ...
                        'hash', obj.Hash, ...
                        'validationMessage', payloadNames{ii}, ...
                        'validationStatus', 0 ...
                    ); %#ok<AGROW>
                end
            end

            if ~isempty(receitaFederalObj)
                checkFileStatus(obj, receitaFederalObj, generalSettings.context.FILE.encodingList);
            end
        end
    end
end