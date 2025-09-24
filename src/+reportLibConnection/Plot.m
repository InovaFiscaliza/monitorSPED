classdef (Abstract) Plot

    methods (Static = true)
        %-----------------------------------------------------------------%
        function imgFileName = Controller(reportInfo, analyzedData, imgSettings)
            arguments
                reportInfo
                analyzedData
                imgSettings
            end

            generalSettings = reportInfo.Settings;
            measTable       = analyzedData.InfoSet.measTable;
            refPointsTable  = analyzedData.InfoSet.stationTable;

            % Container
            hFigure    = reportInfo.App.UIFigure;
            hContainer = findobj(hFigure, 'Tag', 'reportGeneratorContainer');
            if isempty(hContainer)
                hContainer = reportLibConnection.Plot.ContainerCreation(hFigure);
            end

            if ~isempty(hContainer.Children)
                delete(hContainer.Children)
            end

            %... !! PENDENTE !!
        end

        %-----------------------------------------------------------------%
        function hContainer = ContainerCreation(hFigure)
            xWidth     = class.Constants.windowSize(1);
            yHeight    = class.Constants.windowSize(2);    
            hContainer = uipanel(hFigure, AutoResizeChildren='off',          ...
                                          Position=[100 100 xWidth yHeight], ...
                                          BorderType='none',                 ...
                                          BackgroundColor=[0 0 0],           ...
                                          Visible=0,                         ...
                                          Tag="reportGeneratorContainer");
        end
    end

end