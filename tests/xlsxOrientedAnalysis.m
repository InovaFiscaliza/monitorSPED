%% Geração da planilhas de Análises das ECD
ecdObj = model.ECD.empty;
ecdObj = addFiles(ecdObj, 'D:\sample-files\monitorSPED\inputs\SEA TELECOM.txt');
parseTableAndAddToCache(ecdObj, {'all'});
strjoin(fieldnames(ecdObj.Table), ', ')

% Não parece essencial a mesclagem dos conjuntos de registros "I050-I051-I052"
% e "C050-C051-C052".
parseTableAndAddToCache(ecdObj, {'I050_I051_I052', 'I200_I250', 'C050_C051_C052'})

% Registros de fatos contáveis, além do balancete mensal e, por fim, do
% balancete das contas de resultados.
ecdObj.Table.mBALANCETE_GERAL = model.TableGenerator.SummaryByAccount(ecdObj);
ecdObj.Table.mBALANCETE_RESULTADO = model.TableGenerator.SummaryByAccountType(ecdObj, '04');


ecdObj.Table.mI050_I051_I052
ecdObj.Table.mI200_I250
ecdObj.Table.mC050_C051_C052
ecdObj.Table.mBALANCETE_GERAL
ecdObj.Table.mBALANCETE_RESULTADO

%% Exporta saída para Excel
outFile = [tempname, '.xlsx'];

writetable(ecdObj.Table.mI050_I051_I052,      outFile, "Sheet", "mI050_I051_I052")
writetable(ecdObj.Table.mI200_I250,           outFile, "Sheet", "mI200_I250",          "WriteMode", "append")
writetable(ecdObj.Table.mC050_C051_C052,      outFile, "Sheet", "mC050_C051_C052",     "WriteMode", "append")
writetable(ecdObj.Table.mBALANCETE_GERAL,     outFile, "Sheet", "BALANCETE_GERAL",     "WriteMode", "append")
writetable(ecdObj.Table.mBALANCETE_RESULTADO, outFile, "Sheet", "BALANCETE_RESULTADO", "WriteMode", "append")

winopen(outFile)