%% Geração da planilhas de Análises das ECD
ecdObj = model.ECD.empty;
ecdObj = addFiles(ecdObj, 'D:\sample-files\monitorSPED\inputs\SEA TELECOM.txt');
parseTableAndAddToCache(ecdObj, {'all'});
strjoin(fieldnames(ecdObj.Table), ', ')

% Não parece essencial a mesclagem dos conjuntos de registros "C050-C051-C052" e
% "I050-I051-I052".
parseTableAndAddToCache(ecdObj, {'C050_C051_C052', 'I050_I051_I052', 'I200_I250'})

% Registros de fatos contáveis, além do balancete mensal e, por fim, do
% balancete das contas de resultados.
model.TableGenerator.SummaryByAccount(ecdObj);
model.TableGenerator.SummaryByAccountType(ecdObj, accountMonthlySummary, '04');

ecdObj.Table.mC050_C051_C052
ecdObj.Table.mI050_I051_I052
ecdObj.Table.mI200_I250
ecdObj.Table.mAccountSummary
ecdObj.Table.mAccountSummary_04


%% Exporta saída para Excel
outFile = [tempname, '.xlsx'];

writetable(accountMonthlySummary, outFile, "Sheet", "Balancete_TodasContas")
writetable(resultAccountSummary,  outFile, "Sheet", "Balancete_ContasDeResultado", "WriteMode", "append")

winopen(outFile)