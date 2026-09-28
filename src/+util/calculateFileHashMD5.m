function hashHex = calculateFileHashMD5(fileFullName)
    arguments
        fileFullName (1,:) char
    end

    % Lê os bytes brutos do arquivo, sem qualquer conversão de codificação
    % ou normalização de quebra de linha, para reproduzir o hash MD5 do
    % conteúdo exatamente como armazenado em disco.
    fid = fopen(fileFullName, 'rb');
    if fid == -1
        error('util:calculateFileHashMD5:FileNotFound', 'Could not open file "%s".', fileFullName)
    end
    byteArray = fread(fid, Inf, '*uint8');
    fclose(fid);

    hashHex = Hash.md5(byteArray);
end

