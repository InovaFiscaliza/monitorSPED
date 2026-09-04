%% AtualizarIBGEMunicipios
% Inclui o codigo IBGE (COD_MUN) como primeira coluna da tabela em IBGE.mat.

csvPath = "C:\InovaFiscaliza\monitorSPED\src\config\DataBase\IBGE_Municipios.csv";
matPath = "C:\InovaFiscaliza\SupportPackages\src\General\resources\IBGE.mat";
backupPath = matPath + ".backup";

if ~isfile(csvPath)
    error("Arquivo CSV nao encontrado: %s", csvPath);
end

if ~isfile(matPath)
    error("Arquivo MAT nao encontrado: %s", matPath);
end

options = detectImportOptions(csvPath, "VariableNamingRule", "preserve");
options = setvartype(options, "COD_MUN", "string");
municipiosCsv = readtable(csvPath, options);

requiredColumns = ["COD_MUN", "MUNICIPIO"];
if ~all(ismember(requiredColumns, string(municipiosCsv.Properties.VariableNames)))
    error("O CSV deve conter as colunas COD_MUN e MUNICIPIO.");
end

matData = load(matPath);
variableNames = string(fieldnames(matData));
tableVariables = variableNames(cellfun(@istable, struct2cell(matData)));

if numel(tableVariables) ~= 1
    error("O arquivo MAT deve conter exatamente uma tabela; foram encontradas %d.", ...
        numel(tableVariables));
end

tableVariableName = tableVariables(1);
ibgeTable = matData.(tableVariableName);

if width(ibgeTable) == 0
    error("A tabela no arquivo MAT nao possui colunas.");
end

municipiosMatComUf = string(ibgeTable{:, 1});
municipiosMatComUf = municipiosMatComUf(:);
[municipiosMat, ufsMatNoNome] = separarMunicipioUf(municipiosMatComUf);
municipiosMatKey = normalizarMunicipio(municipiosMat);
municipiosCsvKey = normalizarMunicipio(string(municipiosCsv.MUNICIPIO));
municipiosCsvKey = municipiosCsvKey(:);

matVariableNames = string(ibgeTable.Properties.VariableNames);
if ismember("UF", matVariableNames)
    municipiosMatLookupKey = municipiosMatKey + "|" + ...
        upper(strtrim(string(ibgeTable.UF(:))));
elseif any(ufsMatNoNome ~= "")
    municipiosMatLookupKey = municipiosMatKey + "|" + ufsMatNoNome;
else
    municipiosMatLookupKey = municipiosMatKey;
end

if ismember("UF", matVariableNames) || any(ufsMatNoNome ~= "")
    municipiosCsvLookupKey = municipiosCsvKey + "|" + ...
        upper(strtrim(string(municipiosCsv.UF(:))));
else
    municipiosCsvLookupKey = municipiosCsvKey;
end

[uniqueMunicipiosCsvKey, firstSourceIndex] = unique(municipiosCsvLookupKey, ...
    "stable");
if numel(uniqueMunicipiosCsvKey) ~= height(municipiosCsv)
    warning("Chaves de municipios duplicadas no CSV serao resolvidas pelo primeiro registro.");
end

[found, uniqueIndex] = ismember(municipiosMatLookupKey, uniqueMunicipiosCsvKey);
sourceIndex = zeros(size(uniqueIndex));
sourceIndex(found) = firstSourceIndex(uniqueIndex(found));

if any(~found)
    missingMunicipalities = unique(municipiosMat(~found));
    warning("%d municipios nao foram encontrados no CSV; COD_MUN sera vazio nessas linhas:\n%s", ...
        numel(missingMunicipalities), strjoin(missingMunicipalities, newline));
end

codMun = strings(height(ibgeTable), 1);
codMun(found) = string(municipiosCsv.COD_MUN(sourceIndex(found)));
codMun = codMun(:);

if ismember("COD_MUN", string(ibgeTable.Properties.VariableNames))
    ibgeTable.COD_MUN = codMun;
else
    ibgeTable = addvars(ibgeTable, codMun, Before=1, ...
        NewVariableNames="COD_MUN");
end

if ~isfile(backupPath)
    copyfile(matPath, backupPath);
end

matData.(tableVariableName) = ibgeTable;
save(matPath, "-struct", "matData", "-v7.3");

fprintf("Arquivo atualizado: %s\n", matPath);
fprintf("Municipios com COD_MUN inserido: %d\n", height(ibgeTable));
fprintf("Backup: %s\n", backupPath);

function municipalityKey = normalizarMunicipio(municipalityName)
    municipalityKey = upper(string(municipalityName));
    accentedCharacters = [char(192:197), char(199), char(200:203), ...
        char(204:207), char(209), char(210:214), char(217:220)];
    replacementCharacters = 'AAAAAACEEEEIIIINOOOOOUUUU';
    for characterIndex = 1:numel(accentedCharacters)
        municipalityKey = replace(municipalityKey, ...
            string(accentedCharacters(characterIndex)), ...
            replacementCharacters(characterIndex));
    end
    municipalityKey = regexprep(municipalityKey, "[^A-Z0-9]", "");
end

function [municipalityName, uf] = separarMunicipioUf(municipalityWithUf)
    municipalityWithUf = strtrim(string(municipalityWithUf(:)));
    parts = split(municipalityWithUf, "/");
    municipalityName = strtrim(parts(:, 1));
    uf = strings(size(municipalityWithUf));

    hasUf = size(parts, 2) >= 2;
    if hasUf
        uf = upper(strtrim(parts(:, end)));
        uf(strlength(uf) ~= 2) = "";
    end
end
