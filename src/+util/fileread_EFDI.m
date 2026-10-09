function fileread_EFDI(obj, fileFullName, generalSettings, isInitialLoad, recordIds)
    arguments
        obj             (1,1) model.EFDI
        fileFullName    (1,:) char
        generalSettings (1,1) struct
        isInitialLoad   (1,1) logical = true
        recordIds       (1,:) cell = {'0000', '0100', '0150', '0200', '0400', '0450', '0460', '0500', '0600', '1400', ...
                                      'C100', 'C170', 'C190', 'D500', 'D510', 'D590', 'D695', 'D696', 'D697', ...
                                      'D700', 'D730', 'D731', 'D735', 'D737', 'D750', 'D760', 'D761'}
    end

    compositeSheets = model.EFDIBase.efdiCompositeSheets();
    targetRegs = unique([recordIds, {'9900'}]);

    payloads = loadPayloads(fileFullName);
    if isempty(payloads)
        error('util:fileread_EFDI:EmptyPayload', 'No readable EFDI payload was found in "%s".', fileFullName)
    end

    totalCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    occurrences = struct();
    occurrenceLines = struct();
    for ii = 1:numel(targetRegs)
        reg = targetRegs{ii};
        occurrences.(['x' reg]) = {};
        occurrenceLines.(['x' reg]) = [];
    end

    compositeEvents = struct();
    compositeNames = fieldnames(compositeSheets);
    for ii = 1:numel(compositeNames)
        compositeEvents.(compositeNames{ii}) = struct('parentKey', {}, 'reg', {}, 'fields', {}, 'fileIndex', {}, 'sourceLine', {});
    end

    summaryRows = struct('FileIndex', {}, 'SourceFile', {}, 'PayloadName', {}, 'Counts', {});
    layout = [];
    contentParts = {};
    allBytes = uint8([]);
    encoding = '';
    encodingJson = '';

    for fileIndex = 1:numel(payloads)
        payloadBytes = payloads(fileIndex).Bytes;
        allBytes = [allBytes, payloadBytes]; %#ok<AGROW>

        if isempty(encoding)
            [encoding, encodingJson] = detectEncoding(payloadBytes, generalSettings);
        end

        payloadText = native2unicode(payloadBytes, encoding);
        contentParts{end+1} = payloadText; %#ok<AGROW>

        counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
        [fileOccurrences, fileLines, fileEvents, counts, fileLayout] = parsePayload(payloadText, fileIndex, compositeSheets, targetRegs, counts); %#ok<ASGLU>

        if isempty(layout) && ~isempty(fileLayout)
            layout = fileLayout;
        end

        occurrenceRegs = fieldnames(fileOccurrences);
        for ii = 1:numel(occurrenceRegs)
            regField = occurrenceRegs{ii};
            if ~startsWith(regField, 'x')
                regField = ['x' regField];
            end
            regCountKey = regexprep(regField, '^x', '');

            if isempty(fileOccurrences.(regField))
                continue
            end

            occurrences.(regField) = [occurrences.(regField), fileOccurrences.(regField)]; %#ok<AGROW>
            occurrenceLines.(regField) = [occurrenceLines.(regField); fileLines.(regField)]; %#ok<AGROW>

            if isKey(counts, regCountKey)
                totalCounts = incrementCount(totalCounts, regCountKey, counts(regCountKey));
            end
        end

        for ii = 1:numel(compositeNames)
            compositeName = compositeNames{ii};
            compositeEvents.(compositeName) = [compositeEvents.(compositeName), fileEvents.(compositeName)]; %#ok<AGROW>
        end

        summaryRows(end+1) = struct( ...
            'FileIndex', fileIndex, ...
            'SourceFile', payloads(fileIndex).SourceFile, ...
            'PayloadName', payloads(fileIndex).PayloadName, ...
            'Counts', counts ...
        ); %#ok<AGROW>
    end

    if isempty(layout)
        layout = 1;
    end
    obj.Layout = layout;

    if isInitialLoad
        largeFileThreshold = min([generalSettings.context.FILE.largeFileThresholdBytes, 2^30-1]);
        obj.Size = numel(allBytes);
        obj.Hash = Hash.sha1(allBytes);
        obj.Encoding = encoding;
        obj.EncodingInfo = encodingJson;

        if numel(allBytes) > largeFileThreshold
            obj.Content = '';
        else
            obj.Content = strjoin(contentParts, sprintf('\r\n'));
        end
    end

    ordinaryRegs = setdiff(targetRegs, {'9900'});
    for ii = 1:numel(ordinaryRegs)
        reg = ordinaryRegs{ii};

        [tbl, userData] = initializeOrdinaryTable(obj, reg, occurrences.(['x' reg]), occurrenceLines.(['x' reg]));
        tbl.Properties.UserData = userData;
        
        if ~isempty(tbl)
            obj.Table.(['x' reg]) = tbl;
        end
    end

    % Assim como as tabelas compostas, o x9900 só é reconstruído numa carga
    % inicial completa; numa releitura parcial (recordIds restrito), "totalCounts"
    % refletiria apenas os registros solicitados, sobrescrevendo o x9900
    % cacheado com uma contagem incompleta.
    if isInitialLoad
        obj.Table.x9900 = initialize9900(totalCounts);
    end

    for ii = 1:numel(compositeNames)
        compositeName = compositeNames{ii};

        % Numa releitura parcial (recordIds restrito, ex.: recuperação de um
        % único registro removido do cache), só reconstrói a tabela composta
        % se TODOS os registros que a compõem fizerem parte de targetRegs;
        % caso contrário, preserva a tabela composta já cacheada.
        if ~all(ismember(compositeSheets.(compositeName), targetRegs))
            continue
        end

        tbl = initializeCompositeTable(obj, compositeSheets.(compositeName), compositeEvents.(compositeName));
        tbl = enrichCompositeTable(obj, tbl, compositeSheets.(compositeName));
        obj.Table.(compositeName) = mergeCompositeColumnNames(obj, tbl, compositeSheets.(compositeName));
    end
end

%-------------------------------------------------------------------------%
function payloads = loadPayloads(fileFullName)
    payloads = struct('SourceFile', {}, 'PayloadName', {}, 'Bytes', {});
    [~, ~, fileExt] = fileparts(fileFullName);
    fileExt = lower(fileExt);

    switch fileExt
        case {'.zip', '.sped'}
            tempFolder = tempname;
            mkdir(tempFolder)
            folderCleanup = onCleanup(@() cleanupFolder(tempFolder));
            extractedPaths = unzip(fileFullName, tempFolder);

            payloadIdx = 0;
            for ii = 1:numel(extractedPaths)
                currentPath = extractedPaths{ii};
                if isfolder(currentPath)
                    continue
                end

                [~, name, ext] = fileparts(currentPath);
                if startsWith(name, 'ESCRITURACAO-')
                    payloadIdx = payloadIdx + 1;
                    payloads(payloadIdx) = struct( ...
                        'SourceFile', fileFullName, ...
                        'PayloadName', [name, ext], ...
                        'Bytes', readFileBytes(currentPath) ...
                    ); %#ok<AGROW>
                elseif any(strcmpi(ext, {'.zip', '.sped'}))
                    nestedPayloads = loadPayloads(currentPath);
                    if isempty(nestedPayloads)
                        continue
                    end

                    payloads = [payloads, nestedPayloads]; %#ok<AGROW>
                elseif any(strcmpi(ext, {'.txt', '.rec'}))
                    if ~isempty(payloads)
                        continue
                    end
                    payloadIdx = payloadIdx + 1;
                    payloads(payloadIdx) = struct( ...
                        'SourceFile', fileFullName, ...
                        'PayloadName', [name, ext], ...
                        'Bytes', readFileBytes(currentPath) ...
                    ); %#ok<AGROW>
                end
            end
            clear folderCleanup

        otherwise
            payloads = struct( ...
                'SourceFile', {fileFullName}, ...
                'PayloadName', {fileFullName}, ...
                'Bytes', {readFileBytes(fileFullName)} ...
            );
    end
end

%-------------------------------------------------------------------------%
function bytes = readFileBytes(fileFullName)
    fileID = fopen(fileFullName, 'r');
    if fileID == -1
        error('util:fileread_EFDI:FileNotFound', 'File not found: %s', fileFullName)
    end
    bytes = fread(fileID, [1, inf], 'uint8=>uint8');
    fclose(fileID);
end

%-------------------------------------------------------------------------%
function cleanupFolder(folderName)
    if isfolder(folderName)
        rmdir(folderName, 's')
    end
end

%-------------------------------------------------------------------------%
function [encoding, encodingJson] = detectEncoding(byteArray, generalSettings)
    encodingInfo = table( ...
        'Size', [0, 3], ...
        'VariableTypes', {'cell', 'double', 'double'}, ...
        'VariableNames', {'Encoding', 'SpecialCharsTypeCount', 'SpecialCharsCount'} ...
    );

    encodingList = generalSettings.context.FILE.encodingList;
    detectionBytes = min([numel(byteArray), generalSettings.context.FILE.encodingDetectionBytes]);

    for ii = 1:numel(encodingList)
        rawDecoded = lower(native2unicode(byteArray(1:detectionBytes), encodingList{ii}));
        numSpecialChars = cellfun(@(x) numel(strfind(rawDecoded, x)), textAnalysis.commonAccentedChars);
        encodingInfo(end+1, :) = {encodingList{ii}, sum(numSpecialChars > 0), sum(numSpecialChars)}; %#ok<AGROW>
    end
    encodingInfo = sortrows(encodingInfo, {'SpecialCharsTypeCount', 'SpecialCharsCount'}, 'descend');
    encodingJson = matlab.jsonencode(encodingInfo);

    if ~isempty(generalSettings.context.FILE.encodingOverride)
        encoding = generalSettings.context.FILE.encodingOverride;
    else
        encoding = encodingInfo.Encoding{1};
    end
end

%-------------------------------------------------------------------------%
function [occurrences, occurrenceLines, compositeEvents, counts, layout] = parsePayload(payloadText, fileIndex, compositeSheets, targetRegs, counts)
    lines = splitlines(string(payloadText));
    targetRegs = setdiff(targetRegs, {'9900'});
    occurrences = struct();
    occurrenceLines = struct();
    for ii = 1:numel(targetRegs)
        reg = targetRegs{ii};
        occurrences.(['x' reg]) = {};
        occurrenceLines.(['x' reg]) = [];
    end

    compositeNames = fieldnames(compositeSheets);
    compositeEvents = struct();
    currentParentKeys = struct();
    parentCounters = struct();
    childLookup = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for ii = 1:numel(compositeNames)
        compositeName = compositeNames{ii};
        regs = compositeSheets.(compositeName);
        compositeEvents.(compositeName) = struct('parentKey', {}, 'reg', {}, 'fields', {}, 'fileIndex', {}, 'sourceLine', {});
        currentParentKeys.(compositeName) = [];
        parentCounters.(compositeName) = 0;

        for jj = 2:numel(regs)
            childLookup(regs{jj}) = compositeName;
        end
    end

    layout = [];
    for lineIndex = 1:numel(lines)
        currentLine = strtrim(lines(lineIndex));
        if strlength(currentLine) == 0 || currentLine{1}(1) ~= '|'
            continue
        end

        currentLine = regexprep(currentLine{1}, '\r$', '');
        if currentLine(end) == '|'
            currentLine = currentLine(1:end-1);
        end

        % Preserve empty fields so record width matches layout definitions.
        fieldsSplit = split(string(currentLine(2:end)), '|');
        fields = cellstr(fieldsSplit)';
        reg = fields{1};
        counts = incrementCount(counts, reg, 1);

        if strcmp(reg, '0000') && isempty(layout) && numel(fields) >= 2
            layout = str2double(fields{2});
        end

        if isfield(occurrences, ['x' reg])
            occurrences.(['x' reg]){end+1} = fields; %#ok<AGROW>
            occurrenceLines.(['x' reg])(end+1, 1) = lineIndex; %#ok<AGROW>
        end

        for ii = 1:numel(compositeNames)
            compositeName = compositeNames{ii};
            regs = compositeSheets.(compositeName);

            if strcmp(reg, regs{1})
                parentCounters.(compositeName) = parentCounters.(compositeName) + 1;
                currentParentKeys.(compositeName) = parentCounters.(compositeName);
                compositeEvents.(compositeName)(end+1) = struct( ...
                    'parentKey', currentParentKeys.(compositeName), ...
                    'reg', reg, ...
                    'fields', {fields}, ...
                    'fileIndex', fileIndex, ...
                    'sourceLine', lineIndex ...
                ); %#ok<AGROW>
                break
            end
        end

        if isKey(childLookup, reg)
            compositeName = childLookup(reg);
            compositeEvents.(compositeName)(end+1) = struct( ...
                'parentKey', currentParentKeys.(compositeName), ...
                'reg', reg, ...
                'fields', {fields}, ...
                'fileIndex', fileIndex, ...
                'sourceLine', lineIndex ...
            ); %#ok<AGROW>
        end
    end
end

%-------------------------------------------------------------------------%
function countsMap = incrementCount(countsMap, key, increment)
    if isKey(countsMap, key)
        countsMap(key) = countsMap(key) + increment;
    else
        countsMap(key) = increment;
    end
end

%-------------------------------------------------------------------------%
function [tbl, userData] = initializeOrdinaryTable(obj, recordId, rows, lineNumbers)
    userData = lineNumbers;

    if isempty(rows)
        columnSpec = localGetColumnSpecification(obj, recordId, []);
        columnTypes = model.EFDIBase.getFieldSpecification(columnSpec.complete, 'DataType');
        tbl = table('Size', [0, numel(columnSpec.complete)], 'VariableNames', columnSpec.complete, 'VariableTypes', columnTypes);
        return
    end

    rowWidths = cellfun(@numel, rows);
    fieldCount = max(rowWidths);
    columnSpec = localGetColumnSpecification(obj, recordId, fieldCount);

    normalizedRows = cellfun(@(x) [x, repmat({''}, 1, fieldCount - numel(x))], rows, 'UniformOutput', false);
    mergedRows = vertcat(normalizedRows{:});
    tbl = model.SPED.createTableFromRecords(mergedRows, columnSpec);
    tbl = convertOrdinaryTableTypes(tbl, columnSpec.complete);
end

%-------------------------------------------------------------------------%
function columnSpec = localGetColumnSpecification(obj, recordId, fieldCount)
    definition = model.EFDIBase.(['x' recordId]);
    layoutIdx = [];

    if ~isempty(fieldCount)
        for ii = 1:size(definition, 1)
            required = definition{ii, 2};
            optional = definition{ii, 3};
            complete = [required, optional];

            if fieldCount == numel(required) || fieldCount == numel(complete)
                layoutIdx = ii;
                break
            end
        end
    end

    if isempty(layoutIdx)
        layoutIdx = find(cellfun(@(x) ismember(obj.Layout, x), definition(:, 1)), 1);
    end
    if isempty(layoutIdx)
        layoutIdx = size(definition, 1);
    end

    required = definition{layoutIdx, 2};
    optional = definition{layoutIdx, 3};
    columnSpec = struct( ...
        'id', recordId, ...
        'required', {required}, ...
        'optional', {optional}, ...
        'complete', {[required, optional]} ...
    );
end

%-------------------------------------------------------------------------%
function tbl = convertOrdinaryTableTypes(tbl, variableNames)
    for ii = 1:numel(variableNames)
        variableName = variableNames{ii};
        if ~ismember(variableName, tbl.Properties.VariableNames)
            continue
        end

        switch model.EFDIBase.getFieldSpecification(variableName, 'DataType')
            case 'double'
                if ~isa(tbl.(variableName), 'double')
                    emptyIndexes = cellfun(@isempty, tbl.(variableName));
                    if any(emptyIndexes)
                        tbl.(variableName)(emptyIndexes) = {'0'};
                    end
                    tbl.(variableName) = sscanf(strjoin(strrep(tbl.(variableName), ',', '.')), '%f');
                end

            case 'datetime'
                if ~isa(tbl.(variableName), 'datetime')
                    try
                    tbl.(variableName) = datetime(tbl.(variableName), 'InputFormat', 'ddMMyyyy');
                    catch me
                        me
                    end
                end
        end
    end
end

%-------------------------------------------------------------------------%
function tbl = initialize9900(totalCounts)
    regNames = sort(totalCounts.keys);
    rows = cell(numel(regNames), 3);
    for ii = 1:numel(regNames)
        rows(ii, :) = {'9900', regNames{ii}, totalCounts(regNames{ii})};
    end

    columnSpec = struct( ...
        'id', '9900', ...
        'required', {{'REG', 'REG_BLC', 'QTD_REG_BLC'}}, ...
        'optional', {{}}, ...
        'complete', {{'REG', 'REG_BLC', 'QTD_REG_BLC'}} ...
    );
    tbl = model.SPED.createTableFromRecords(rows, columnSpec);
    tbl = convertOrdinaryTableTypes(tbl, columnSpec.complete);
end

%-------------------------------------------------------------------------%
function tbl = initializeCompositeTable(obj, regs, events)
    metadata = getCompositeMetadata(obj, regs, events);
    variableNames = {'CHAVE_PAI'};
    variableTypes = {'double'};

    for ii = 1:numel(regs)
        reg = regs{ii};
        fieldNames = metadata.(reg).FieldNames;
        prefixedFieldNames = strcat(reg, '_', fieldNames);

        % Além do valor "vencedor" (1º não vazio) por campo, mantém-se em
        % colunas "..._VALUES" o CONJUNTO de valores distintos vistos por
        % campo/registro-pai, para os campos NÃO monetários (classificatórios,
        % como CST_ICMS/CFOP/ALIQ_ICMS) — usado por mergeCompositeColumnNames
        % para comparar por conjunto, já que esses campos podem legitimamente
        % ter múltiplos valores por documento (um por item).
        isMonetary = startsWith(fieldNames, 'VL_');
        valueSetNames = strcat(prefixedFieldNames(~isMonetary), '_VALUES');

        variableNames = [variableNames, prefixedFieldNames, valueSetNames, {[reg, '_ARQ_IDX'], [reg, '_LINHA_TXT']}]; %#ok<AGROW>
        variableTypes = [variableTypes, repmat({'cell'}, 1, numel(fieldNames) + numel(valueSetNames)), {'double', 'double'}]; %#ok<AGROW>
    end

    if isempty(events)
        tbl = table('Size', [0, numel(variableNames)], 'VariableNames', matlab.lang.makeValidName(variableNames), 'VariableTypes', variableTypes);
        return
    end

    parentKeys = [events.parentKey];
    uniqueParentKeys = unique(parentKeys, 'stable');
    tbl = table('Size', [numel(uniqueParentKeys), numel(variableNames)], 'VariableNames', matlab.lang.makeValidName(variableNames), 'VariableTypes', variableTypes);
    tbl.CHAVE_PAI = uniqueParentKeys';

    for eventIndex = 1:numel(events)
        event = events(eventIndex);
        rowIndex = find(uniqueParentKeys == event.parentKey, 1);
        reg = event.reg;
        fieldNames = metadata.(reg).FieldNames;
        values = normalizeCompositeValues(event.fields, fieldNames);
        prefixedFieldNames = matlab.lang.makeValidName(strcat(reg, '_', fieldNames));

        for colIndex = 1:numel(prefixedFieldNames)
            columnName = prefixedFieldNames{colIndex};
            value = values{colIndex};
            if isempty(value)
                continue
            end

            currentValue = tbl.(columnName){rowIndex};

            % Campos "VL_*" (valores monetários) são somados entre múltiplos
            % registros-filho do mesmo pai (ex.: vários D510/itens ou vários
            % D590/resumos por CST-CFOP-alíquota de um mesmo D500) — do
            % contrário, apenas o 1º filho seria considerado, subestimando o
            % total e gerando falsa divergência com o valor agregado do D500.
            % Demais campos (códigos, identificadores, alíquotas) mantêm o
            % comportamento original de "primeiro valor não vazio", além de
            % acumular o conjunto completo de valores em "..._VALUES".
            if startsWith(fieldNames{colIndex}, 'VL_') && isnumeric(value)
                if isempty(currentValue)
                    currentValue = 0;
                end
                tbl.(columnName){rowIndex} = currentValue + value;

            else
                if isempty(currentValue)
                    tbl.(columnName){rowIndex} = value;
                end

                valueSetColumn = [columnName, '_VALUES'];
                valueSet = tbl.(valueSetColumn){rowIndex};
                if ~iscell(valueSet)
                    valueSet = {};
                end
                if ~any(cellfun(@(x) isequal(x, value), valueSet))
                    valueSet{end+1} = value; %#ok<AGROW>
                end
                tbl.(valueSetColumn){rowIndex} = valueSet;
            end
        end

        sourceFileColumn = [reg, '_ARQ_IDX'];
        sourceLineColumn = [reg, '_LINHA_TXT'];
        if tbl.(sourceFileColumn)(rowIndex) == 0
            tbl.(sourceFileColumn)(rowIndex) = event.fileIndex;
            tbl.(sourceLineColumn)(rowIndex) = event.sourceLine;
        end
    end

    hasRecord = false(height(tbl), 1);
    for ii = 1:numel(regs)
        reg = regs{ii};
        fieldNames = metadata.(reg).FieldNames;
        fieldNames = fieldNames(~strcmp(fieldNames, 'REG'));
        prefixedFieldNames = matlab.lang.makeValidName(strcat(reg, '_', fieldNames));
        hasRecord = hasRecord | any(~cellfun(@isempty, tbl{:, prefixedFieldNames}), 2);
    end
    tbl = tbl(hasRecord, :);
end

%-------------------------------------------------------------------------%
function metadata = getCompositeMetadata(obj, regs, events)
    metadata = struct();
    for ii = 1:numel(regs)
        reg = regs{ii};
        regEvents = events(strcmp({events.reg}, reg));
        if isempty(regEvents)
            columnSpec = localGetColumnSpecification(obj, reg, []);
        else
            maxFields = max(cellfun(@numel, {regEvents.fields}));
            columnSpec = localGetColumnSpecification(obj, reg, maxFields);
        end
        metadata.(reg) = struct('FieldNames', {columnSpec.complete});
    end
end

%-------------------------------------------------------------------------%
function values = normalizeCompositeValues(fields, fieldNames)
    values = cell(1, numel(fieldNames));
    paddedFields = [fields, repmat({''}, 1, numel(fieldNames) - numel(fields))];
    for ii = 1:numel(fieldNames)
        rawValue = paddedFields{ii};
        if isempty(rawValue)
            values{ii} = '';
            continue
        end

        dataType = model.EFDIBase.getFieldSpecification(fieldNames{ii}, 'DataType');
        if strcmp(dataType, 'datetime') || startsWith(fieldNames{ii}, 'DT_')
            if numel(rawValue) == 8 && all(isstrprop(rawValue, 'digit'))
                values{ii} = sprintf('%s/%s/%s', rawValue(1:2), rawValue(3:4), rawValue(5:8));
            else
                values{ii} = rawValue;
            end
        elseif strcmp(dataType, 'double')
            values{ii} = str2double(strrep(rawValue, ',', '.'));
        else
            values{ii} = rawValue;
        end
    end
end

%-------------------------------------------------------------------------%
function tbl = mergeCompositeColumnNames(obj, tbl, regs)
    % Remove o prefixo "<REG>_" dos nomes das colunas mescladas (CHAVE_PAI e
    % as colunas de rastreio *_ARQ_IDX/*_LINHA_TXT/*_VALUES permanecem como
    % estão, ou são descartadas ao final, no caso de *_VALUES).
    % Quando o mesmo campo aparece em mais de um registro de origem (ex.:
    % CST_ICMS em C170 e C190), mantém-se uma única coluna, com o primeiro
    % valor não vazio (na ordem de "regs"); divergências entre os valores
    % de origem são registradas em obj.GUI.warnings.
    variableNames = tbl.Properties.VariableNames;
    reservedMask  = endsWith(variableNames, {'_ARQ_IDX', '_LINHA_TXT', '_VALUES'}) | strcmp(variableNames, 'CHAVE_PAI');

    bareNames  = {};
    sourceCols = {};

    for ii = 1:numel(regs)
        reg = regs{ii};
        prefix = matlab.lang.makeValidName([reg '_']);
        regColumnIdxs = find(startsWith(variableNames, prefix) & ~reservedMask);

        for jj = regColumnIdxs
            columnName = variableNames{jj};
            bareName = extractAfter(columnName, prefix);

            [~, bareIdx] = ismember(bareName, bareNames);
            if bareIdx == 0
                bareNames{end+1}  = bareName; %#ok<AGROW>
                sourceCols{end+1} = {columnName}; %#ok<AGROW>
            else
                sourceCols{bareIdx}{end+1} = columnName;
            end
        end
    end

    for ii = 1:numel(bareNames)
        bareName = bareNames{ii};
        cols = sourceCols{ii};

        mergedValues = tbl.(cols{1});
        conflictCount = 0;

        % Campos classificatórios (não monetários) têm uma coluna irmã
        % "..._VALUES" com o conjunto completo de valores vistos por linha;
        % quando presente para TODAS as colunas-fonte, a comparação usa esse
        % conjunto em vez do valor único "vencedor" — um documento pode ter
        % legitimamente vários itens com CST_ICMS/CFOP/ALIQ_ICMS distintos,
        % e comparar só o "1º valor" de cada registro-filho geraria falsa
        % divergência sempre que a ordem dos itens não coincidisse entre os
        % registros de origem (ex.: C170 x C190).
        valueSetCols  = strcat(cols, '_VALUES');
        useValueSets  = all(ismember(valueSetCols, variableNames));
        if useValueSets
            mergedValueSet = tbl.(valueSetCols{1});
        end

        for jj = 2:numel(cols)
            otherValues = tbl.(cols{jj});
            emptyMask = cellfun(@isempty, mergedValues);

            if useValueSets
                otherValueSet = tbl.(valueSetCols{jj});
                hasBothSets = ~cellfun(@isempty, mergedValueSet) & ~cellfun(@isempty, otherValueSet);
                conflictMask = hasBothSets & ~cellfun(@compositeValueSetsMatch, mergedValueSet, otherValueSet);
                mergedValueSet = cellfun(@unionCompositeValues, mergedValueSet, otherValueSet, 'UniformOutput', false);
            else
                % Campos monetários ("VL_*") somados a partir de múltiplos
                % itens (ver initializeCompositeTable) podem diferir do
                % total do documento por até poucos centavos, por
                % arredondamento por item; compareCompositeValues tolera
                % essa diferença, sinalizando só divergências materiais.
                conflictMask = ~emptyMask & ~cellfun(@isempty, otherValues) & ~cellfun(@compareCompositeValues, mergedValues, otherValues);
            end

            conflictCount = conflictCount + sum(conflictMask);
            mergedValues(emptyMask) = otherValues(emptyMask);
        end

        % "REG" sempre diverge entre os registros de origem por definição
        % (identifica o próprio tipo do registro: D500, D510, D590 etc.) —
        % não é uma divergência de dado, então não gera warning.
        if conflictCount > 0 && ~strcmp(bareName, 'REG')
            obj.GUI.warnings{end+1} = matlab.jsonencode(struct( ...
                'id', 'CompositeColumnMerge', ...
                'message', sprintf('Campo "%s": %d linha(s) com valores divergentes entre %s; mantido o valor do registro de maior prioridade.', bareName, conflictCount, strjoin(cols, ', ')) ...
            ));
        end

        % A remoção do prefixo não pode falhar por causa de uma conversão de
        % tipo inesperada (ex.: tabela mesclada vazia); se normalizeMergedColumn
        % falhar, mantém-se o valor como texto simples.
        try
            columnData = normalizeMergedColumn(bareName, mergedValues);
        catch
            columnData = cellfun(@(x) char(string(x)), mergedValues, 'UniformOutput', false);
        end

        tbl = removevars(tbl, cols);
        tbl.(bareName) = columnData;
    end

    % Colunas "..._VALUES" são bookkeeping interno (comparação de conjuntos);
    % nunca devem aparecer na tabela composta final exposta à UI/relatório.
    valueSetColumns = tbl.Properties.VariableNames(endsWith(tbl.Properties.VariableNames, '_VALUES'));
    if ~isempty(valueSetColumns)
        tbl = removevars(tbl, valueSetColumns);
    end
    valueSetColumns = tbl.Properties.VariableNames(endsWith(tbl.Properties.VariableNames, '_PAI'));
    if ~isempty(valueSetColumns)
        tbl = removevars(tbl, valueSetColumns);  
    end
    valueSetColumns = tbl.Properties.VariableNames(endsWith(tbl.Properties.VariableNames, '_LINHA_TXT'));
    if ~isempty(valueSetColumns)
        tbl = removevars(tbl, valueSetColumns);  
    end
    valueSetColumns = tbl.Properties.VariableNames(endsWith(tbl.Properties.VariableNames, '_ARQ_IDX'));
    if ~isempty(valueSetColumns)
        tbl = removevars(tbl, valueSetColumns);
    end
    tbl.REG(:) = {strjoin(regs,'_')};
end

%-------------------------------------------------------------------------%
function tf = compareCompositeValues(a, b)
    % Valores numéricos toleram diferença de até 2 centavos (arredondamento
    % por item ao somar múltiplos D510/D590 de um mesmo D500); demais tipos
    % exigem igualdade exata.
    if isequal(a, b)
        tf = true;
    elseif isa(a, 'double') && isa(b, 'double') && ~isempty(a) && ~isempty(b)
        tf = abs(a - b) < 0.02;
    else
        tf = false;
    end
end

%-------------------------------------------------------------------------%
function tf = compositeValueSetsMatch(setA, setB)
    % Células nunca preenchidas ficam como "[]" (double, valor padrão de
    % coluna "cell" em table()), não "{}" — cellfun exige um cell array de
    % verdade, então normaliza-se antes de compará-los.
    if ~iscell(setA)
        setA = {};
    end
    if ~iscell(setB)
        setB = {};
    end

    % Dois conjuntos de valores são equivalentes quando todo elemento de um
    % tem correspondente (via compareCompositeValues) no outro, nos dois
    % sentidos — independe de ordem, duplicatas ou de qual registro-filho
    % apareceu primeiro no arquivo.
    tf = all(cellfun(@(a) any(cellfun(@(b) compareCompositeValues(a, b), setB)), setA)) && ...
         all(cellfun(@(b) any(cellfun(@(a) compareCompositeValues(a, b), setA)), setB));
end

%-------------------------------------------------------------------------%
function merged = unionCompositeValues(setA, setB)
    if ~iscell(setA)
        setA = {};
    end
    if ~iscell(setB)
        setB = {};
    end

    merged = setA;
    for ii = 1:numel(setB)
        if ~any(cellfun(@(x) compareCompositeValues(x, setB{ii}), merged))
            merged{end+1} = setB{ii}; %#ok<AGROW>
        end
    end
end

%-------------------------------------------------------------------------%
function columnData = normalizeMergedColumn(bareName, values)
    % Garante um único formato por coluna, dentre os aceitos por
    % ui.Table.hasCustomizableColumnFormat (cellstr, double etc.). Células
    % nunca preenchidas ficam como "[]" (double, valor padrão de coluna
    % "cell" em table()); aqui são substituídas pelo valor padrão do tipo
    % real do campo, e a coluna é convertida para esse tipo único. Campos de
    % data (DataType "datetime") são tratados como texto, pois
    % normalizeCompositeValues já os grava como string formatada "dd/mm/aaaa".
    try
        dataType = model.EFDIBase.getFieldSpecification(bareName, 'DataType');
    catch
        dataType = 'cell';
    end

    missingMask = cellfun(@(x) isa(x, 'double') && isempty(x), values);

    switch dataType
        case 'double'
            values(missingMask) = {model.SPED.getMissingValue('double')};
            columnData = cell2mat(values);

        otherwise % texto ('cell' ou 'datetime', armazenado como string formatada)
            values(missingMask) = {''};
            nonCharMask = ~cellfun(@ischar, values);
            values(nonCharMask) = cellfun(@(x) char(string(x)), values(nonCharMask), 'UniformOutput', false);
            columnData = values;
    end
end

%-------------------------------------------------------------------------%
function tbl = enrichCompositeTable(obj, tbl, regs)
    % Adiciona a descrição textual (entre parênteses) aos campos codificados
    % das composite sheets, no mesmo formato usado no relatório de referência
    % "Análise_Sped_EFD_ICMS_IPI" (COD_PART/COD_ITEM ligados aos registros
    % 0150/0200, e campos de domínio do Guia Prático EFD ICMS/IPI).
    for ii = 1:numel(regs)
        reg = regs{ii};
        tbl = enrichCodPart(obj, tbl, reg);
        tbl = enrichCodItem(obj, tbl, reg);
        tbl = enrichDomainField(tbl, reg, 'COD_SIT', domainTable('COD_SIT'));
        tbl = enrichDomainField(tbl, reg, 'IND_PGTO', domainTable('IND_PGTO'));
        tbl = enrichDomainField(tbl, reg, 'TP_ASSINANTE', domainTable('TP_ASSINANTE'));
        tbl = enrichDomainField(tbl, reg, 'CST_IPI', domainTable('CST_IPI'));
        tbl = enrichDomainField(tbl, reg, 'CST_ICMS', domainTable('CST_ICMS'), @(code) code(max(1, end-1):end));
    end
end

%-------------------------------------------------------------------------%
function tbl = enrichCodPart(obj, tbl, reg)
    columnName = matlab.lang.makeValidName([reg, '_COD_PART']);
    if ~ismember(columnName, tbl.Properties.VariableNames) || ~isfield(obj.Table, 'x0150') || isempty(obj.Table.x0150)
        return
    end

    part = obj.Table.x0150;
    for rowIndex = 1:height(tbl)
        code = tbl.(columnName){rowIndex};
        if isempty(code)
            continue
        end

        matchIndex = find(strcmp(part.COD_PART, code), 1);
        if isempty(matchIndex)
            continue
        end

        codMunLabel = part.COD_MUN{matchIndex};
        municipio = gpsLib.lookupMunicipioIBGE(codMunLabel);
        if ~isempty(municipio)
            codMunLabel = sprintf('%s (%s)', codMunLabel, municipio);
        end

        tbl.(columnName){rowIndex} = sprintf('%s (%s); CNPJ: %s; CPF: %s; %s; End.: %s; Núm.: %s; Compl.: %s; Bairro: %s', ...
            code, part.NOME{matchIndex}, part.CNPJ{matchIndex}, part.CPF{matchIndex}, codMunLabel, ...
            part.END{matchIndex}, part.NUM{matchIndex}, part.COMPL{matchIndex}, part.BAIRRO{matchIndex});
    end
end

%-------------------------------------------------------------------------%
function tbl = enrichCodItem(obj, tbl, reg)
    columnName = matlab.lang.makeValidName([reg, '_COD_ITEM']);
    if ~ismember(columnName, tbl.Properties.VariableNames) || ~isfield(obj.Table, 'x0200') || isempty(obj.Table.x0200)
        return
    end

    item = obj.Table.x0200;
    for rowIndex = 1:height(tbl)
        code = tbl.(columnName){rowIndex};
        if isempty(code)
            continue
        end

        matchIndex = find(strcmp(item.COD_ITEM, code), 1);
        if isempty(matchIndex)
            continue
        end

        tbl.(columnName){rowIndex} = sprintf('%s (%s); Tipo_item: %s; Alíq_ICMS: %s', ...
            code, item.DESCR_ITEM{matchIndex}, item.TIPO_ITEM{matchIndex}, num2str(item.ALIQ_ICMS(matchIndex)));
    end
end

%-------------------------------------------------------------------------%
function tbl = enrichDomainField(tbl, reg, fieldName, domainMap, keyExtractor)
    if nargin < 5 || isempty(keyExtractor)
        keyExtractor = @(code) code;
    end

    columnName = matlab.lang.makeValidName([reg, '_', fieldName]);
    if ~ismember(columnName, tbl.Properties.VariableNames) || isempty(domainMap)
        return
    end

    for rowIndex = 1:height(tbl)
        code = tbl.(columnName){rowIndex};
        if isempty(code)
            continue
        end

        key = keyExtractor(code);
        if ~isKey(domainMap, key)
            continue
        end
        tbl.(columnName){rowIndex} = sprintf('%s (%s)', code, domainMap(key));
    end
end

%-------------------------------------------------------------------------%
function domainMap = domainTable(fieldName)
    % Tabelas de domínio do Guia Prático da EFD ICMS/IPI (Receita Federal).
    switch fieldName
        case 'COD_SIT'
            entries = { ...
                '00', 'Regular'; ...
                '01', 'Extemporâneo'; ...
                '02', 'Extemporâneo (não emitido por Doc. Fiscal Eletrônico)'; ...
                '03', 'Cancelado'; ...
                '04', 'Denegado'; ...
                '05', 'Numeração inutilizada'; ...
                '06', 'Não circulou/serviço não realizado'; ...
                '07', 'Regime Especial/Norma Específica'; ...
                '08', 'Documento complementar' ...
            };

        case 'IND_PGTO'
            entries = { ...
                '0', 'À Vista'; ...
                '1', 'A Prazo'; ...
                '2', 'Outros' ...
            };

        case 'TP_ASSINANTE'
            entries = { ...
                '1', 'Com./Ind.'; ...
                '2', 'Residencial'; ...
                '3', 'Rural'; ...
                '4', 'Poder Público'; ...
                '5', 'Tarifa Reduzida'; ...
                '6', 'Rede de Telecomunicação'; ...
                '7', 'Teleassinatura Especial'; ...
                '9', 'Outros' ...
            };

        case 'CST_ICMS' % dois últimos dígitos do código (tributação), ignorando o dígito de origem
            entries = { ...
                '00', 'Trib. integralmente'; ...
                '10', 'Trib. c/ cobrança do ICMS por ST'; ...
                '20', 'Com redução de base de cálculo'; ...
                '30', 'Isenta/não trib. c/ cobrança do ICMS por ST'; ...
                '40', 'Isenta'; ...
                '41', 'Não tributada'; ...
                '50', 'Suspensão'; ...
                '51', 'Diferimento'; ...
                '60', 'ICMS cobrado anteriormente por ST'; ...
                '70', 'Redução de BC c/ cobrança do ICMS por ST'; ...
                '90', 'Outras' ...
            };

        case 'CST_IPI'
            entries = { ...
                '00', 'Entrada c/ recuperação de crédito'; ...
                '01', 'Entrada trib. c/ alíquota zero'; ...
                '02', 'Entrada isenta'; ...
                '03', 'Entrada não tributada'; ...
                '04', 'Entrada imune'; ...
                '05', 'Entrada com suspensão'; ...
                '49', 'Outras entradas'; ...
                '50', 'Saída tributada'; ...
                '51', 'Saída trib. c/ alíquota zero'; ...
                '52', 'Saída isenta'; ...
                '53', 'Saída não tributada'; ...
                '54', 'Saída imune'; ...
                '55', 'Saída com suspensão'; ...
                '99', 'Outras saídas' ...
            };

        otherwise
            entries = {};
    end

    domainMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for ii = 1:size(entries, 1)
        domainMap(entries{ii, 1}) = entries{ii, 2};
    end
end