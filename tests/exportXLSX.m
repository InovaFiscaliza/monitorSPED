function msgError = exportXLSX(obj, generalSettings, fileName)
    
    % Deixado o genérico "obj" porque poderá servir tanto o model.ECD quanto
    % model.EFD, quando criado.

    msgError = {};
    try
        if ismethod(obj, 'parseTableAndAddToCache')
            parseTableAndAddToCache(obj, {'all'}, generalSettings)
        end

        tableIdFields = fieldnames(obj.Table);

        if ~isempty(tableIdFields)
            for ii = 1:numel(tableIdFields)
                tableId = tableIdFields{ii};

                tableData = obj.Table.(tableId);
                if ~isempty(tableData.Properties.RowNames)
                    tableData = [table(tableData.Properties.RowNames, 'VariableName', {'TIPO'}), tableData];
                end

                if ii == 1
                    writeMode = 'replacefile';
                else
                    writeMode = 'append';
                end
                writetable(tableData, fileName, "Sheet", tableId(2:end), "WriteMode", writeMode)
            end
        end

    catch ME
        msgError{end+1} = ME.message;
    end
end