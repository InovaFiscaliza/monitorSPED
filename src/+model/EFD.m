classdef EFD < handle

    % SINTAXE:
    % >> efdObj = model.EFD.empty;
    % >> efdObj = addFiles(efdObj, {'Filename1.txt', 'Filename2.txt'});

    properties
        %-----------------------------------------------------------------%
        FileName = ''
        FileFullName = ''

        Size
        Hash = ''
        Encoding = ''
        EncodingInfo = ''

        Content = ''
        Layout = 1
        Table

        CompanyName
        CompanyId % CNPJ
        CompanyInfo = struct( ...
            'CNPJ', {}, ...
            'IE', {}, ...
            'IM', {}, ...
            'NIRE', {}, ...
            'UF', {}, ...
            'City', {} ...
        )
        
        State
        Period
        PeriodMerged = false

        Sources = struct( ...
            'file', {}, ...
            'period', {}, ...
            'encoding', {}, ...
            'terminator', {}, ...
            'hash', {}, ...
            'validationMessage', {}, ...
            'validationStatus', {} ... % -2 (Erro) | -1 (Diverge) | 0 (Pendente) | 1 (Coincide)
        )
        
        Enable = true
        UUID = char(matlab.lang.internal.uuid())
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        function [obj, msg] = addFiles(obj, projectData, generalSettings, fileNameList, receitaFederalObj)
            arguments
                obj
                projectData
                generalSettings
                fileNameList
                receitaFederalObj = []
            end

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
                    % ...

                catch ME
                    delete(obj(idx))
                    obj(idx) = [];
                    msg{end+1} = ME.message;
                end
            end

            msg = strjoin(msg, '\n');
        end
    end
end