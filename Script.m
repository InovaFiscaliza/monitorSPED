a = model.ECDBase({'C:\P&D\monitorSPED\tests\resources\SPED-ECD 2022.txt'});
parseTableAndAddToCache(a);
leftTable = table_I150_I155_I350_I355(a);
tableDinamica = tableDinamica_I150_I155_I350_I355(a, leftTable);