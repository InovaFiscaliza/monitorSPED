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

    md5 = java.security.MessageDigest.getInstance('MD5');
    md5.update(typecast(byteArray, 'int8')); % reinterpreta os bits, sem saturar valores >= 128
    hashHex = lower(sprintf('%02x', typecast(md5.digest(), 'uint8')));
end

