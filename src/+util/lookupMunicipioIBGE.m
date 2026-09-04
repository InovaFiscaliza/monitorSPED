function label = lookupMunicipioIBGE(codMun)
    arguments
        codMun (1,:) char
    end

    persistent municipioMap
    if isempty(municipioMap)
        municipioMap = loadMunicipioMap();
    end

    label = '';
    codMun = strtrim(codMun);
    if isempty(codMun) || ~isKey(municipioMap, codMun)
        return
    end
    label = municipioMap(codMun);
end

%-------------------------------------------------------------------------%
function municipioMap = loadMunicipioMap()
    municipioMap = containers.Map('KeyType', 'char', 'ValueType', 'char');

    matPath = 'C:\InovaFiscaliza\SupportPackages\src\General\resources\IBGE.mat';
    if ~isfile(matPath)
        return
    end

    matData = load(matPath);
    variableNames = fieldnames(matData);
    tableNames = variableNames(cellfun(@istable, struct2cell(matData)));
    if numel(tableNames) ~= 1
        return
    end

    tbl = matData.(tableNames{1});
    variableNames = string(tbl.Properties.VariableNames);
    if ~ismember("COD_MUN", variableNames)
        return
    end

    labelColumnIndex = find(variableNames ~= "COD_MUN", 1, 'first');
    if isempty(labelColumnIndex)
        return
    end

    codes = strtrim(string(tbl.COD_MUN));
    labels = strtrim(string(tbl{:, labelColumnIndex}));
    for ii = 1:height(tbl)
        if ismissing(codes(ii)) || codes(ii) == ""
            continue
        end
        municipioMap(char(codes(ii))) = char(labels(ii));
    end
end
