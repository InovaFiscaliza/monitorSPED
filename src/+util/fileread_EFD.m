function fileread_EFD(obj, fileFullName, generalSettings, isInitialLoad, recordIds)
    arguments
        obj             (1,1) model.EFD
        fileFullName    (1,:) char
        generalSettings (1,1) struct
        isInitialLoad   (1,1) logical = true
        recordIds       (1,:) cell = {'0000', '0100', '0150', '0200', '0400', '0450', '0460', '0500', '0600', '1400', ...
                                      'C100', 'C170', 'C190', 'D500', 'D510', 'D590', 'D695', 'D696', 'D697', ...
                                      'D700', 'D730', 'D731', 'D735', 'D737', 'D750', 'D760', 'D761'}
    end

    compositeSheets = struct( ... % %#ok<NASGU>
        'xC100_C170_C190', {{'C100', 'C170', 'C190'}}, ...
        'xD500_D510_D590', {{'D500', 'D510', 'D590'}}, ...
        'xD695_D696_D697', {{'D695', 'D696', 'D697'}}, ...
        'xD700_E_FILHOS',  {{'D700', 'D730', 'D731', 'D735', 'D737'}}, ...
        'xD750_D760_D761', {{'D750', 'D760', 'D761'}} ...
    );
    targetRegs = unique([recordIds, {'9900'}]);

    payloads = loadPayloads(fileFullName);
    if isempty(payloads)
        error('util:fileread_EFD:EmptyPayload', 'No readable EFD payload was found in "%s".', fileFullName)
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
        obj.Table.(['x' reg]) = tbl;
    end

    obj.Table.x9900 = initialize9900(totalCounts);
    obj.Table.x_RESULTADOS = initializeSummaryTable(summaryRows);

    for ii = 1:numel(compositeNames)
        compositeName = compositeNames{ii};
        obj.Table.(compositeName) = initializeCompositeTable(obj, compositeSheets.(compositeName), compositeEvents.(compositeName));
    end
end


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


function bytes = readFileBytes(fileFullName)
    fileID = fopen(fileFullName, 'r');
    if fileID == -1
        error('util:fileread_EFD:FileNotFound', 'File not found: %s', fileFullName)
    end
    bytes = fread(fileID, [1, inf], 'uint8=>uint8');
    fclose(fileID);
end


function cleanupFolder(folderName)
    if isfolder(folderName)
        rmdir(folderName, 's')
    end
end


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
        numSpecialChars = cellfun(@(x) numel(strfind(rawDecoded, x)), textAnalysis.specialMain);
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


function countsMap = incrementCount(countsMap, key, increment)
    if isKey(countsMap, key)
        countsMap(key) = countsMap(key) + increment;
    else
        countsMap(key) = increment;
    end
end


function [tbl, userData] = initializeOrdinaryTable(obj, recordId, rows, lineNumbers)
    userData = lineNumbers;

    if isempty(rows)
        columnSpec = localGetColumnSpecification(obj, recordId, []);
        columnTypes = model.EFDBase.getFieldSpecification(columnSpec.complete, 'DataType');
        tbl = table('Size', [0, numel(columnSpec.complete)], 'VariableNames', columnSpec.complete, 'VariableTypes', columnTypes);
        return
    end

    rowWidths = cellfun(@numel, rows);
    fieldCount = max(rowWidths);
    columnSpec = localGetColumnSpecification(obj, recordId, fieldCount);

    normalizedRows = cellfun(@(x) [x, repmat({''}, 1, fieldCount - numel(x))], rows, 'UniformOutput', false);
    mergedRows = vertcat(normalizedRows{:});
    tbl = model.EFDBase.cellToTable(mergedRows, columnSpec);
    tbl = convertOrdinaryTableTypes(tbl, columnSpec.complete);
end


function columnSpec = localGetColumnSpecification(obj, recordId, fieldCount)
    definition = model.EFDBase.(['x' recordId]);
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


function tbl = convertOrdinaryTableTypes(tbl, variableNames)
    for ii = 1:numel(variableNames)
        variableName = variableNames{ii};
        if ~ismember(variableName, tbl.Properties.VariableNames)
            continue
        end

        switch model.EFDBase.getFieldSpecification(variableName, 'DataType')
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
    tbl = model.EFDBase.cellToTable(rows, columnSpec);
    tbl = convertOrdinaryTableTypes(tbl, columnSpec.complete);
end


function tbl = initializeSummaryTable(summaryRows)
    allRegs = {};
    for ii = 1:numel(summaryRows)
        allRegs = union(allRegs, summaryRows(ii).Counts.keys, 'stable'); %#ok<AGROW>
    end
    allRegs = sort(allRegs);

    variableNames = matlab.lang.makeValidName([{'ARQ_IDX', 'ARQUIVO_ZIP_INTERNO', 'PAYLOAD'}, strcat('COUNT_', allRegs')]);
    variableTypes = [{'double', 'cell', 'cell'}, repmat({'double'}, 1, numel(allRegs))];
    tbl = table('Size', [numel(summaryRows), numel(variableNames)], 'VariableNames', variableNames, 'VariableTypes', variableTypes);

    for ii = 1:numel(summaryRows)
        tbl.ARQ_IDX(ii) = summaryRows(ii).FileIndex;
        tbl.ARQUIVO_ZIP_INTERNO{ii} = summaryRows(ii).SourceFile;
        tbl.PAYLOAD{ii} = summaryRows(ii).PayloadName;
        for jj = 1:numel(allRegs)
            if isKey(summaryRows(ii).Counts, allRegs{jj})
                tbl{ii, 3 + jj} = summaryRows(ii).Counts(allRegs{jj});
            else
                tbl{ii, 3 + jj} = 0;
            end
        end
    end
end


function tbl = initializeCompositeTable(obj, regs, events)
    metadata = getCompositeMetadata(obj, regs, events);
    variableNames = {'CHAVE_PAI'};
    variableTypes = {'double'};

    for ii = 1:numel(regs)
        reg = regs{ii};
        variableNames = [variableNames, strcat(reg, '_', metadata.(reg).FieldNames), {[reg, '_ARQ_IDX'], [reg, '_LINHA_TXT']}]; %#ok<AGROW>
        variableTypes = [variableTypes, repmat({'cell'}, 1, numel(metadata.(reg).FieldNames)), {'double', 'double'}]; %#ok<AGROW>
    end

    tbl = table('Size', [numel(events), numel(variableNames)], 'VariableNames', matlab.lang.makeValidName(variableNames), 'VariableTypes', variableTypes);

    for ii = 1:height(tbl)
        tbl.CHAVE_PAI(ii) = events(ii).parentKey;
    end

    for rowIndex = 1:numel(events)
        event = events(rowIndex);
        reg = event.reg;
        fieldNames = metadata.(reg).FieldNames;
        values = normalizeCompositeValues(event.fields, fieldNames);
        prefixedFieldNames = matlab.lang.makeValidName(strcat(reg, '_', fieldNames));

        for colIndex = 1:numel(prefixedFieldNames)
            tbl.(prefixedFieldNames{colIndex}){rowIndex} = values{colIndex};
        end

        tbl.([reg, '_ARQ_IDX'])(rowIndex) = event.fileIndex;
        tbl.([reg, '_LINHA_TXT'])(rowIndex) = event.sourceLine;
    end
end


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


function values = normalizeCompositeValues(fields, fieldNames)
    values = cell(1, numel(fieldNames));
    paddedFields = [fields, repmat({''}, 1, numel(fieldNames) - numel(fields))];
    for ii = 1:numel(fieldNames)
        rawValue = paddedFields{ii};
        if isempty(rawValue)
            values{ii} = '';
            continue
        end

        dataType = model.EFDBase.getFieldSpecification(fieldNames{ii}, 'DataType');
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