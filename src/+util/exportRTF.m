function [rtfFiles, msgError] = exportRTF(ecdObj, generalSettins)
    rtfFiles    = {};
    msgError    = {};
    
    rtfTableIds = {'J800', 'J801'};
    parseTableAndAddToCache(ecdObj, rtfTableIds)
    
    tempName    = appEngine.util.DefaultFileName(generalSettins.fileFolder.tempPath, 'monitorSPED');
    fileCount   = 0;
    
    for ii = 1:numel(rtfTableIds)
        rtfTableField = ['x' rtfTableIds{ii}];
    
        if isfield(ecdObj.Table, rtfTableField) && ~isempty(ecdObj.Table.(rtfTableField))
            for jj = 1:height(ecdObj.Table.(rtfTableField))
                fileCount = fileCount+1;
                fileName  = sprintf('%s_%d.rtf', tempName, fileCount);
    
                try
                    util.recreateRTF(ecdObj.Table.(rtfTableField).('ARQ_RTF'){jj}, fileName)
                    rtfFiles{end+1} = fileName;
    
                catch ME
                    msgError{end+1} = ME.message;
                end
            end
        end
    end

    msgError = strjoin(msgError, '\n\n');
end