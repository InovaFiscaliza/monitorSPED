# monitorSPED  [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/InovaFiscaliza/monitorSPED)


O monitorSPED é uma ferramenta de pós-processamento de arquivos contábeis de empresas que atuam no mercado de telecomunicações. Para cada arquivo, procede-se ao cálculo do respectivo *hash* e à validação por meio de webservice disponibilizado pela Receita Federal, de modo a verificar se o arquivo coincide com o registrado em sua base de dados. Além disso, cria-se ambiente para que fiscal apure os valores devidos ao FUST e ao FUNTTEL.

<img width="1920" height="1032" src="https://github.com/user-attachments/assets/7729cbcd-c829-4088-aa98-f8352727a6a5" />

#### COMPATIBILIDADE  
A ferramenta foi desenvolvida em **MATLAB** e possui uma versão *desktop*, que pode ser utilizada em ambiente *offline*, e uma versão *webapp*, acessível na intranet. O monitorSPED é compatível com as versões mais recentes do MATLAB (ex.: *R2024a* e *R2025b*). A versão compilada — seja *desktop* ou *webapp* — é executada sobre a máquina virtual do MATLAB, o MATLAB Runtime.  

#### EXECUÇÃO NO AMBIENTE DO MATLAB  
Caso o aplicativo seja executado diretamente no MATLAB, é necessário:  
1. Clonar o presente repositório.
2. Clonar também o repositório [SupportPackages](https://github.com/InovaFiscaliza/SupportPackages), adicionando ao *path* do MATLAB as seguintes pastas deste repositório:  
```
.\src\Anatel
.\src\General
```

3. Abrir o projeto **monitorSPED.prj**.
4. Executar **winMonitorSPED.mlapp**.  

#### OUTRAS INFORMAÇÕES
🔗 [InovaFiscaliza/monitorSPED](https://anatel365.sharepoint.com/sites/InovaFiscaliza/SitePages/monitorSPED.aspx)  
