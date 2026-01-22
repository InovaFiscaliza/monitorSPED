function hashHex = calculateFileHash(content, encoding, terminator)
    arguments
        content
        encoding   (1,:) char  = 'ISO-8859-1'
        terminator (1,2) uint8 = [13, 10]
    end

    splitContent  = splitlines(content);
    lastLineIndex = find(startsWith(splitContent, '|9999|'), 1);
    if isempty(lastLineIndex)
        error('Register 9999 not found')
    end

    splitContent = strjoin(splitContent(1:lastLineIndex), char(terminator));
    byteArray = [unicode2native(splitContent, encoding), terminator];
    hashHex = Hash.sha1(byteArray);
end

% Arquivo vazio                                                                                                    - Hash da39a3ee5e6b4b0d3255bfef95601890afd80709
% Arquivo com "abc" como conteúdo                                                                                  - Hash a9993e364706816aba3e25717850c26c9cd0d89d
% Arquivo "74280256000136-35212923462-20190501-20190531-G-CAB2051CB96BB920AF24744EBF11536A8EFA2A6F-1-SPED-ECD.txt" - Hash cab2051cb96bb920af24744ebf11536a8efa2a6f
% Arquivo "74280256000136-35212923462-20190601-20190630-G-7577C549809DA24A3508D48248BED730A12995C9-1-SPED-ECD.txt" - Hash 7577c549809da24a3508d48248bed730a12995c9
% Arquivo "74280256000136-35212923462-20190701-20190731-G-50EF46F529C38D288A84CF9C51F85D679A6A9370-1-SPED-ECD.txt" - Hash 50ef46f529c38d288a84cf9c51f85d679a6a9370
% Arquivo "74280256000136-35212923462-20190801-20190831-G-0745F1FA8F48B26A291E90BB5AD531D3D3C8A735-1-SPED-ECD.txt" - Hash 0745f1fa8f48b26a291e90bb5ad531d3d3c8a735

