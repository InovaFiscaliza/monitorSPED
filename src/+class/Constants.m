classdef (Abstract) Constants

    properties (Constant)
        %-----------------------------------------------------------------%
        appName       = 'monitorSPED'
        appRelease    = 'R2024a'
        appVersion    = '0.01.0'

        windowSize    = [1244, 660]
        windowMinSize = [ 950, 660]
    end

    
    methods (Static = true)
        %-----------------------------------------------------------------%
        function fileName = DefaultFileName(userPath, Prefix, Issue)
            fileName = fullfile(userPath, sprintf('%s_%s', Prefix, datestr(now,'yyyy.mm.dd_THH.MM.SS')));

            if Issue > 0
                fileName = sprintf('%s_%d', fileName, Issue);
            end
        end

        %-----------------------------------------------------------------%
        function d = english2portuguese()
            names  = ["FileName", ...
                      "Period", ...
                      "Content", ...
                      "Table"];
            values = ["Arquivo", ...
                      "Período", ...
                      "Conteúdo", ...
                      "Tabela"];
        
            d = dictionary(names, values);
        end

        %-----------------------------------------------------------------%
        function winMinSize = WindowMinSize(auxiliarApp)
            switch auxiliarApp
                case 'CONFIG'
                    winMinSize = [760, 588];
            end
        end
    end
end