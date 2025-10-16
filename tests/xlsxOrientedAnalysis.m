%% Geração da planilhas de Análises das ECD

ecdObj = model.ECD.empty;
ecdObj = addFiles(ecdObj, 'D:\sample-files\monitorSPED\inputs\SEA TELECOM.txt');
parseTableAndAddToCache(ecdObj, {'all'});
strjoin(fieldnames(ecdObj.Table), ', ')

%% *Aba #1: C050 + C051 + C052*
% (Replica planilhas de análise constantes no arquivo .xlsx enviado por Enilsio)

% |C050|05022009|01|S|1|1||ATIVO|
% |C050|16012007|01|S|2|1.1|1|CIRCULANTE|
% |C050|19072018|01|S|3|1.1.01|1.1|CAIXA E EQUIVALENTES DE CAIXA|
% |C050|19072018|01|S|4|1.1.01.001|1.1.01|CAIXA|
% |C050|17042017|01|A|5|1.1.01.001.5|1.1.01.001|CAIXA|
% |C051||1.01.01.01.01|
% |C052||1.1.01.001|
% |C050|19072018|01|S|4|1.1.01.002|1.1.01|BANCOS CONTA MOVIMENTO|
% |C050|16012007|01|A|5|1.1.01.002.9|1.1.01.002|BANCO BRADESCO S/A|
% |C051||1.01.01.02.01|
% |C052||1.1.01.002|

customMergedTablesRowOriented( ...
    ecdObj, ...
    'C050', ...
    {'C051', 'C052'}, ...
    'COD_CCUS' ...
)
ecdObj.Table.x_C050_C051_C052_RowOriented

%% *Aba #2: I050 + I051 + I052*

% |I050|05022009|01|S|1|1||ATIVO|
% |I050|16012007|01|S|2|1.1|1|CIRCULANTE|
% |I050|19072018|01|S|3|1.1.01|1.1|CAIXA E EQUIVALENTES DE CAIXA|
% |I050|19072018|01|S|4|1.1.01.001|1.1.01|CAIXA|
% |I050|17042017|01|A|5|1.1.01.001.5|1.1.01.001|CAIXA|
% |I051||1.01.01.01.01|
% |I052||1.1.01.001|
% |I050|19072018|01|S|4|1.1.01.002|1.1.01|BANCOS CONTA MOVIMENTO|
% |I050|16012007|01|A|5|1.1.01.002.9|1.1.01.002|BANCO BRADESCO S/A|
% |I051||1.01.01.02.01|
% |I052||1.1.01.002|

customMergedTablesRowOriented( ...
    ecdObj, ...
    'I050', ...
    {'I051', 'I052'}, ...
    'COD_CCUS' ...
)
ecdObj.Table.x_I050_I051_I052_RowOriented

%% *Aba #3: I250 + COLUNA "VL_COM_SINAL" + DATA EXTRAÍDA DE I200* 🛑⚠️❗

% |I200|8976521|01012023|1643,85|N||
% |I250|2.1.07.001.4985||1643,85|C||350|ESTORNO DE VALOR LANﾇADO INDEVIDAMENTE||
% |I250|1.1.02.001.4883||1643,85|D||350|ESTORNO DE VALOR LANﾇADO INDEVIDAMENTE||
% |I200|8976522|01012023|11235,57|N||
% |I250|2.1.01.001.657620||11235,57|C|||NOTA DE DﾉBITO Nｺ 1260019543 - EQUINIX DO BRASIL SOLUCOES DE TECNOLOGIA EM INFORM||
% |I250|3.7.03.015.4540||11235,57|D|||NOTA DE DﾉBITO Nｺ 1260019543 - EQUINIX DO BRASIL SOLUCOES DE TECNOLOGIA EM INFORM||
% |I200|8976523|01012023|2145,06|N||
% |I250|2.1.01.001.657620||2145,06|C|||NOTA DE DﾉBITO Nｺ 1250052946 - EQUINIX DO BRASIL SOLUCOES DE TECNOLOGIA EM INFORM||
% |I250|3.7.03.015.4540||2145,06|D|||NOTA DE DﾉBITO Nｺ 1250052946 - EQUINIX DO BRASIL SOLUCOES DE TECNOLOGIA EM INFORM||

mergedTable_I250_I200 = model.TableGenerator.parseSplitLineOthers(ecdObj, {'I250' 'I200'});
mergedTable_I250_I200.("VL_DC_COM_SINAL") = mergedTable_I250_I200.("VL_DC");
negativeValueIndexes = find(strcmp(mergedTable_I250_I200.("IND_DC"), 'D'));
mergedTable_I250_I200.("VL_DC_COM_SINAL")(negativeValueIndexes) = -mergedTable_I250_I200.("VL_DC_COM_SINAL")(negativeValueIndexes);
mergedTable_I250_I200

%% *Aba #4: I350 + COLUNA "VL_COM_SINAL" + DATA EXTRAÍDA DE I300* 🛑⚠️❗

% |I350|31032023|
% |I355|3.1.01.005.001.2703||65793,42|C|
% |I355|3.1.01.005.001.2704||18632888,05|C|
% |I355|3.1.01.005.001.2705||7863554,29|C|
% |I355|3.1.03.005.2827||1204826,12|D|
% |I355|3.1.03.005.2828||3255|D|
% |I355|3.1.03.005.2829||298753,43|D|
% |I355|3.1.03.005.2830||1379818,59|D|
% |I355|3.1.03.005.2832||54833,86|D|
% |I355|3.1.03.005.5103||64538,64|D|
% |I355|3.1.03.005.5104||32078,43|D|
% |I355|3.1.05.001.2858||4559,86|C|
% |I355|3.1.05.001.2860||327428,4|C|
% |I355|3.1.05.001.4852||383,11|C|

mergedTable_I355_I350 = model.TableGenerator.tableTypes1And3(ecdObj, 3, {'I150', 'I155', 'I350', 'I355'});
mergedTable_I355_I350.REG = strcat(mergedTable_I355_I350.REG, '-', ecdObj.Table.('xI355').REG);
mergedTable_I355_I350 = [mergedTable_I355_I350, removevars(ecdObj.Table.('xI355'), 'REG')];

mergedTable_I355_I350.("VL_CTA_COM_SINAL") = mergedTable_I355_I350.("VL_CTA");
negativeValueIndexes = find(strcmp(mergedTable_I355_I350.("IND_DC"), 'D'));
mergedTable_I355_I350.("VL_CTA_COM_SINAL")(negativeValueIndexes) = -mergedTable_I355_I350.("VL_CTA_COM_SINAL")(negativeValueIndexes);
mergedTable_I355_I350

%% Aba #5: J150 + COLUNA "VL_COM_SINAL" + DATAS INÍCIO E FIM 🛑⚠️❗

mergedTable_J150_J005 = model.TableGenerator.parseSplitLineOthers(ecdObj, {'J150' 'J005'});
mergedTable_J150_J005.("VL_CTA_FIN_COM_SINAL") = mergedTable_J150_J005.("VL_CTA_FIN");
negativeValueIndexes = find(strcmp(mergedTable_J150_J005.("IND_DC_CTA_FIN"), 'D'));
mergedTable_J150_J005.("VL_CTA_FIN_COM_SINAL")(negativeValueIndexes) = -mergedTable_J150_J005.("VL_CTA_FIN_COM_SINAL")(negativeValueIndexes);
mergedTable_J150_J005

%% Aba #6: I155 + COLUNAS "VL_COM_SINAL" e "RESULTADO_COM_SINAL" + DATAS INÍCIO E FIM 🛑⚠️❗

refTable_I150_I155 = model.TableGenerator.tableTypes1And3(ecdObj, 1, {'I150', 'I155', 'I350', 'I355'});
refTable_I150_I155.REG = strcat(refTable_I150_I155.REG, '-', ecdObj.Table.('xI155').REG);       % PRECISA DISSO MESMO?
refTable_I150_I155 = [refTable_I150_I155, removevars(ecdObj.Table.('xI155'), 'REG')];
refTable_I150_I155 = model.TableGenerator.inseriCodCTA(ecdObj, refTable_I150_I155);

refTable_I150_I155.("VL_SLD_FIN_COM_SINAL") = refTable_I150_I155.("VL_SLD_FIN");
negativeValueIndexes = find(strcmp(refTable_I150_I155.("VL_SLD_FIN_COM_SINAL"), 'D'));
refTable_I150_I155.("VL_SLD_FIN_COM_SINAL")(negativeValueIndexes) = -refTable_I150_I155.("VL_SLD_FIN_COM_SINAL")(negativeValueIndexes);

refTable_I150_I155.("VL_RESULTADO_COM_SINAL") = refTable_I150_I155.("VL_CRED") - refTable_I150_I155.("VL_DEB");
refTable_I150_I155

%% Abas #7 e #8: TABELA DINÂMICA I155 + I355 E BALANCETE 🛑⚠️❗
 
% * Sumariza resultados da planilha I155 por conta na HOR e mês na VERT.
% * O somatório do resultado de todas as contas por mês deve ser igual a zero.
% * COD_CTA | JAN | FEV | ... | DEZ | TOTAL

Table_I150_I155_I350_I355 = model.TableGenerator.parseSplitLine(ecdObj)
accountMonthlySummary     = model.TableGenerator.SummaryByAccount(ecdObj, Table_I150_I155_I350_I355, mergedTable_I250_I200)
analyticalMonthlySummary  = model.TableGenerator.SummaryByAnalyticalAccount(ecdObj, accountMonthlySummary, '04')

%% Exporta saída para Excel
outFile = [tempname, '.xlsx'];

writetable(ecdObj.Table.x_C050_C051_C052_RowOriented, outFile, "Sheet", "C050-C051-C052")
writetable(ecdObj.Table.x_I050_I051_I052_RowOriented, outFile, "Sheet", "I050-I051-I052",                "WriteMode", "append")
writetable(mergedTable_I250_I200,                     outFile, "Sheet", "I250_I200",                     "WriteMode", "append")
writetable(mergedTable_I355_I350,                     outFile, "Sheet", "I355-I350",                     "WriteMode", "append")
writetable(mergedTable_J150_J005,                     outFile, "Sheet", "J150-J005",                     "WriteMode", "append")
writetable(refTable_I150_I155,                        outFile, "Sheet", "I150-I155",                     "WriteMode", "append")
writetable(accountMonthlySummary,                     outFile, "Sheet", "Balancete",                     "WriteMode", "append")
writetable(analyticalMonthlySummary,                  outFile, "Sheet", "Balancete - ContasDeResultado", "WriteMode", "append")

winopen(outFile)