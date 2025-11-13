classdef (Abstract) datatip

    methods (Static = true)
        %-----------------------------------------------------------------%
        function Template(dtParent, dtType, varargin)
            arguments
                dtParent
                dtType char {mustBeMember(dtType, {'Value'})}
            end

            arguments (Repeating)
                varargin
            end

            if isempty(dtParent)
                return
            elseif ~isprop(dtParent, 'DataTipTemplate')
                % 'images.roi.line' e 'images.roi.Rectangle' não suportam DataTip
                try
                    dt = datatip(dtParent, Visible = 'off');
                catch
                    return
                end
            end

            set(dtParent.DataTipTemplate, FontName='Calibri', FontSize=10)

            switch dtType
                case 'Value'
                    dtParent.DataTipTemplate.DataTipRows(1).Label  = 'Mês:';
                    dtParent.DataTipTemplate.DataTipRows(2).Label  = '';
                    dtParent.DataTipTemplate.DataTipRows(2).Format = 'R$ %.2f';
            end

            if exist('dt', 'var')
                delete(dt)
            end
        end
    end
    
end