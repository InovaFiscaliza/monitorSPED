function hashHex = calculateFileHash(data)
    import System.Security.Cryptography.*
    sha1Provider = SHA1Managed();
    
    bytes = numel(data);
    index = 0;
    
    while index < bytes
        idx1 = index + 1;
        idx2 = min(index + 65536, bytes);
        
        tempData = data(idx1:idx2);
        sha1Provider.TransformBlock(tempData, 0, numel(tempData), tempData, 0);
        
        index = idx2;
    end

    sha1Provider.TransformFinalBlock(uint8([]), 0, 0);    

    hashBytes = uint8(sha1Provider.Hash);
    hashHex   = lower(sprintf('%02x', hashBytes));
end

% 96 - 74280256000136-35212923462-20190501-20190531-G-CAB2051CB96BB920AF24744EBF11536A8EFA2A6F-1-SPED-ECD.txt - Hash cab2051cb96bb920af24744ebf11536a8efa2a6f
% 97 - 74280256000136-35212923462-20190601-20190630-G-7577C549809DA24A3508D48248BED730A12995C9-1-SPED-ECD.txt - Hash 7577c549809da24a3508d48248bed730a12995c9
% 98 - 74280256000136-35212923462-20190701-20190731-G-50EF46F529C38D288A84CF9C51F85D679A6A9370-1-SPED-ECD.txt - Hash 50ef46f529c38d288a84cf9c51f85d679a6a9370
% 99 - 74280256000136-35212923462-20190801-20190831-G-0745F1FA8F48B26A291E90BB5AD531D3D3C8A735-1-SPED-ECD.txt - Hash 0745f1fa8f48b26a291e90bb5ad531d3d3c8a735
% abc.txt - Hash a9993e364706816aba3e25717850c26c9cd0d89d
% vazio.txt - Hash da39a3ee5e6b4b0d3255bfef95601890afd80709