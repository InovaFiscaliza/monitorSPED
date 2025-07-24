#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Validador Tributario: 
Valida diversos arquivos tributários recebidos em uma pasta.
O App procura por todos arquivos recursivamente, inclusive compactados ou em formato backup da receita, identificando e classificando por conteúdo.

Usage: 
  ValidadorTributario.py PASTA-DE-ENTRADA CNPJ-MATRIZ ANO-FISCAL UUID
  ValidadorTributario.py --log UUID
  ValidadorTributario.py --query QUERY  
  ValidadorTributario.py --dir PATH-INI
  ValidadorTributario.py --file ARQUIVO 
  ValidadorTributario.py --relatorios 

Arguments:
  JSON-RPC          Requisição não implementada
  PASTA-DE-ENTRADA  Pasta de origem dos arquivos [default: --dir PATH-INI]
  CNPJ-MATRIZ       CNPJ da Matriz
  ANO-FISCAL        Ano Fiscal 
  UUID              Identificação para o relatório gerado [default: UUID]
  PATH-INI          Pasta inicial para listagem de conteudo
  ARQUIVO           Arquivo de relatório anterior

Options:
  -h --help             Show this screen.
  -v --version          Show version.
  --log                 Mostra último registro do progresso da validação
  --query               Obtém detalhe a partir de dataframes
  --file                Lê resultado anterior (relatório, dataframe, template, imagem, etc)
  --relatorios          Lista resultados anteriores
  --dir                 Lista arquivos da pasta a partir de PATH-INI ou default

"""
from docopt import docopt
from schema import And
from schema import Or
from schema import Schema
from schema import SchemaError
from schema import Use
from pandasql import sqldf
import base64
import subprocess
import uuid 
from subprocess import check_output, Popen
import sys
import os
import io
import time
import shutil
from urllib.parse import urlparse, unquote
import mimetypes
from pathlib import Path
import platform
from time import sleep
import random
import re
import chardet
from charset_normalizer import detect
import py7zr
import zipfile
import json
from nbformat import read, write, NO_CONVERT
from datetime import datetime
import calendar
import hashlib
import pycpfcnpj.cnpj
import pycpfcnpj.compatible
import pycpfcnpj.cpfcnpj
import requests
import xml.etree.ElementTree as ET
import pandas as pd
import pycpfcnpj
import unicodedata
from markdownify import markdownify as md
#from pycpfcnpj import cnpj.CNPJClient
#from pycpfcnpj import cpfcnpj
#from pycpfcnpj import mask

### Autores
###
### - Sérgio S Q 
###
### - Elio A B
###
### <!-- LICENSE -->
### # Licenças
### Distributed under the GNU General Public License (GPL), version 3. See [`LICENSE`](\LICENSE.md) for more information.
### For additional information, please check <https://www.gnu.org/licenses/quick-guide-gplv3.html>
### This license model was selected with the idea of enabling collaboration of anyone interested in projects listed within this group.
### It is in line with the **Brazilian Public Software directives**, as published at: <https://softwarepublico.gov.br/social/articles/0004/5936/Manual_do_Ofertante_Temporario_04.10.2016.pdf>
###

### Versão beta .01 reorganizando o código: usar css do SEI, bug tempo excessivo na leitura de alguns arquivos, muito poluído e poucos comentários, códigos soltos e duplicados, eliminar variáveis globais e declarações desnecessárias, usar classes e oo, eliminar prints, funções não testadas, diferenciar matriz e filiais, organizar páginas, views, etc ..


### O python instalou localmente a partir da loja, não foi necessário instalar versão "portable":
### pip install -r requirements.txt
### pip install PyInstaller
### Opção de interface nativa do SO ou WEB na linha final
### Gerando de forma simples um arquivo único executável distribuível:
### C:\Users\sergiosq\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.12_qbz5n2kfra8p0\LocalCache\local-packages\Python312\Scripts\flet pack main.py
### É necessário instalar o Flutter para gerar aplicativo instalável e publicar na Microsoft Store.
### https://flet.dev/ ; https://flutter.dev/ 

nomeapp = "Validador Tributário"

descapp = "Valida diversos arquivos tributários recebidos em uma pasta"


appver = "Versão beta "

txtwarn = "O App procura por todos arquivos recursivamente, inclusive compactados ou em formato backup da receita, identificando e classificando por conteúdo.\n"


# relatório
relatorio_final = {}
# informações básicas
relatorio_final['cnpj-matriz'] = ""
relatorio_final['ano-fiscal'] = ""
relatorio_final['razao-social'] = ""
relatorio_final['data-da-consulta'] = ""
# configuração dos módulos    
relatorio_final['modulos-srf'] = {}
relatorio_final['modulos-srf']['ECD'] = {}
relatorio_final['modulos-srf']['ECD']['descricao'] = "Escrituração Contábil Digital"
relatorio_final['modulos-srf']['ECD']['obrigacao'] = "A Escrituração Contábil Digital (ECD) é uma obrigação acessória que substitui a escrituração em papel dos livros contábeis pela versão digital. Nela, são registrados todos os dados contábeis das empresas, como o Livro Diário, o Livro Razão, os Balancetes Diários e as Demonstrações Financeiras, sendo enviada eletronicamente à Receita Federal. A ECD é fundamental para assegurar a transparência e a integridade das informações contábeis, além de facilitar a fiscalização e o acompanhamento das obrigações tributárias e contábeis das empresas."
relatorio_final['modulos-srf']['ECD']['apresentacao'] = "A ECD pode ser apurada em frequências diferentes, sendo comum a apuração trimestral e anual. Via de regra, a ECD deve ser centralizada na matriz; no entanto, casos excepcionais permitem que algumas filiais com escrituração própria enviem suas ECDs de forma independente."
relatorio_final['modulos-srf']['ECD']['ufs-avaliadas'] = ['--']
relatorio_final['modulos-srf']['ECF'] = {}
relatorio_final['modulos-srf']['ECF']['descricao'] = "Escrituração Contábil Fiscal"
relatorio_final['modulos-srf']['ECF']['obrigacao'] = "A Escrituração Contábil Fiscal (ECF) é uma obrigação acessória prevista na legislação brasileira, que tem como objetivo consolidar e registrar as informações contábeis e fiscais das empresas em um único documento. A ECF foi instituída pela Instrução Normativa RFB nº 1.422/2013 e substitui a antiga Declaração de Informações Econômico-Fiscais da Pessoa Jurídica (DIPJ)."
relatorio_final['modulos-srf']['ECF']['apresentacao'] = "A ECF deve ser apresentada anualmente, com prazo de entrega até o último dia útil de julho do ano seguinte ao ano-calendário a que se refere a escrituração. Via de regra, a ECF deve ser centralizada na matriz; no entanto, casos excepcionais permitem que algumas filiais com escrituração própria enviem suas ECFs de forma independente."
relatorio_final['modulos-srf']['ECF']['ufs-avaliadas'] = ['--']
relatorio_final['modulos-srf']['EFD ICMS-IPI'] = {}
relatorio_final['modulos-srf']['EFD ICMS-IPI']['descricao'] = "Escrituração Fiscal Digital do ICMS e IPI"
relatorio_final['modulos-srf']['EFD ICMS-IPI']['obrigacao'] = "A Escrituração Fiscal Digital do ICMS e IPI (EFD-ICMS IPI) é uma obrigação acessória que integra o Sistema Público de Escrituração Digital (SPED) e tem como finalidade registrar e controlar as operações que envolvem o Imposto sobre Circulação de Mercadorias e Serviços (ICMS) e o Imposto sobre Produtos Industrializados (IPI). A EFD-ICMS IPI visa facilitar a fiscalização e o cumprimento das obrigações tributárias pelas empresas."
relatorio_final['modulos-srf']['EFD ICMS-IPI']['apresentacao'] = "A EFD-ICMS IPI deve ser apresentada <u>mensalmente</u>, até o 15º dia do mês seguinte ao da apuração. Via de regra, a&nbsp;EFD-ICMS IPI <u>deve ser apresentada tanto pela matriz quanto pelas filiais em cada unidade da federação onde operam.</u>"
relatorio_final['modulos-srf']['EFD ICMS-IPI']['ufs-avaliadas'] = ['--', 'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO']
relatorio_final['modulos-srf']['EFD-Contribuições'] = {}
relatorio_final['modulos-srf']['EFD-Contribuições']['descricao'] = "Escrituração Fiscal Digital das Contribuições"
relatorio_final['modulos-srf']['EFD-Contribuições']['obrigacao'] = "A Escrituração Fiscal Digital das Contribuições (EFD-Contribuições) é uma obrigação acessória que faz parte do Sistema Público de Escrituração Digital (SPED) e é destinada a empresas que recolhem contribuições para o PIS/Pasep e a Cofins. Instituída pela Instrução Normativa RFB nº 1.252/2012, a EFD-Contribuições tem como objetivo registrar e controlar as operações de receita e as contribuições devidas, facilitando a fiscalização por parte da Receita Federal do Brasil."
relatorio_final['modulos-srf']['EFD-Contribuições']['apresentacao'] = "A EFD-Contribuições deve ser apresentada <u>mensalmente</u>, até o 15º dia do mês seguinte ao da apuração.&nbsp;Via de regra, a ECF deve ser centralizada na matriz; no entanto, casos excepcionais permitem que algumas filiais com escrituração própria enviem suas EFD-Contribuições de forma independente."
relatorio_final['modulos-srf']['EFD-Contribuições']['ufs-avaliadas'] = ['--', 'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO']
relatorio_final['modulos-srf']['LFPD'] = {}
relatorio_final['modulos-srf']['LFPD']['descricao'] = "Leiaute Fiscal de Processamento de Dados (Ato Cotepe nº 35/05  e Ato Cotepe nº 70/05- Livro de Brasília e Pernambuco)"
relatorio_final['modulos-srf']['LFPD']['obrigacao'] = "A LFPD é uma obrigação acessória instituída pelo CONFAZ que dispõe sobre as especificações técnicas para a geração, o armazenamento e o envio de arquivos em meio digital relativos aos registros de documentos fiscais, livros fiscais, lançamentos contábeis, demonstrações contábeis, documentos de informação econômico-fiscais e outras informações de interesse do fisco,&nbsp;que e tem como finalidade registrar e controlar as operações que envolvem o Imposto sobre Circulação de Mercadorias e Serviços (ICMS).&nbsp; A LFPD visa facilitar a fiscalização e o cumprimento das obrigações tributárias pelas empresas."
relatorio_final['modulos-srf']['LFPD']['apresentacao'] = "A LFPD deve ser apresentada <u>mensalmente, e </u><u>deve ser apresentada tanto pela matriz quanto pelas filiais nas operações nos estados do Distrito Federal e Pernambuco.</u>"
relatorio_final['modulos-srf']['LFPD']['ufs-avaliadas'] = ['--', 'DF','PE']
# diversos
relatorio_final['conexao-srf'] = False    
relatorio_final['resultados-uteis'] = False
relatorio_final['encontrados-outros'] = False






maxpath = 254
maxbufff = 4096
cntanon0 = 0
cntanon = 0


cnpj_ = ""
ano_ = ""
prest_ = ""
data_ = ""
iduuid = "debug"


pastaTemp = str(Path(str(Path.home())).as_posix()) + "/tmp" 
pasta_in = str(Path(str(Path.home())).as_posix()) + "/tmp/in"

log_ = str(Path(str(Path.home())).as_posix()) + "/AppOut" # redefinido na linha de comando
pastaRaiz = str(Path(str(Path.home())).as_posix()) # redefinido na linha de comando
pasta_ok = log_ + "/ARQS_SIT_OK" # redefinido na linha de comando
pasta_nok = log_ + "/ARQS_SIT_NOT_OK" # redefinido na linha de comando
pathprestok = ""

# fica aqui por conta de um sintoma específico em um ambiente testado
Path(log_).mkdir(parents=True, exist_ok=True)
with open(f"{log_}/debug.log", 'a', encoding="utf-8") as file: # 
    file.write(f"\n{os.environ}") 
    
relpre = "RelatorioValidatorTributario_"    


arquivosenha = "corrigir_este_codigo.txt"


sshenv = ""
if "SSH_CLIENT" in os.environ:
    sshenv = os.environ['SSH_CLIENT']

ddeep = 256
vpcnt = -1
tcodec = 0

cnpj_ = ""
ano_ = ""
prest_ = ""
data_ = ""

errcon = False
dict_rs = {}
validados = False
listatemporaria = [] # eliminar variáveis globais, criar classes , etc ..

# # tabela bruta validada expandida (eliminar)
# res_val = pd.DataFrame(columns=["Ano Fiscal","Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro","Jan inválidos","Fev inválidos","Mar inválidos","Abr inválidos","Mai inválidos","Jun inválidos","Jul inválidos","Ago inválidos","Set inválidos","Out inválidos","Nov inválidos","Dez inválidos","Prestadora","CNPJ","Tipo","UF","Data Inicial","Data Final","Resultado da Validação","Origem do Arquivo"])
# # último resultado anterior (eliminar)
# res_val_r = pd.DataFrame()

# dados brutos validados
res_brutos = pd.DataFrame()
# tabela filtrada
filtrada = pd.DataFrame()
# tabela expandida
expandida = pd.DataFrame()


estados = ['--', 'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO']



# path origem
vpath =  pd.DataFrame(columns=["origem","destino"]) 




tipos = ['ECD','ECF','EFD ICMS-IPI','EFD-Contribuições','LFPD']

meses = ["Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro",]

meserr = ["Jan inválidos","Fev inválidos","Mar inválidos","Abr inválidos","Mai inválidos","Jun inválidos","Jul inválidos","Ago inválidos","Set inválidos","Out inválidos","Nov inválidos","Dez inválidos"]

fmt = {
        'index': {
                'width': '40'
                },
        'Ano Fiscal': {
                'width': '40'
                },
        'UF': {
                'width': '25'
                },
        'CNPJ': {
                'width': '140'
                },
        'Tipo': {
                'width': '100'
                },
        'cnt': {
                'width': '20'
                },
        'Janeiro': {
                'txt': 'JAN',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Fevereiro': {
                'txt': 'FEV',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Março': {
                'txt': 'MAR',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Abril': {
                'txt': 'ABR',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Maio': {
                'txt': 'JAN',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Junho': {
                'txt': 'JUN',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Julho': {
                'txt': 'JUL',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Agosto': {
                'txt': 'AGO',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Setembro': {
                'txt': 'SET',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Outubro': {
                'txt': 'OUT',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Novembro': {
                'txt': 'NOV',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Dezembro': {
                'txt': 'DEZ',
                'não': '#ff0000',
                '1': '#00ff00',
                '0': '#ffff00',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Jan inválidos': {
                'txt': 'JAN NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Fev inválidos': {
                'txt': 'FEV NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Mar inválidos': {
                'txt': 'MAR NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Abr inválidos': {
                'txt': 'ABR NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Mai inválidos': {
                'txt': 'MAI NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Jun inválidos': {
                'txt': 'JUN NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Jul inválidos': {
                'txt': 'JUL NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Ago inválidos': {
                'txt': 'AGO NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Set inválidos': {
                'txt': 'SET NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Out inválidos': {
                'txt': 'OUT NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Nov inválidos': {
                'txt': 'NOV NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
        'Dez inválidos': {
                'txt': 'DEZ NOK',
                '-1': '#ffff00',
                '1': '#ff0000',
                'ok': '#00ff00',
                '0': '0xeeeeee',
                'nan': '#ffff00',
                'width': '40',
                'click': True,
                },
    }



def debug(msg):

    Path(log_).mkdir(parents=True, exist_ok=True)
    with open(f"{log_}/debug.log", 'a', encoding="utf-8") as file: # 
        file.write(f"\n{msg}")    



#######################################################################################################
#  inicio copiado dos ipynbs Elio, com pequenas alterações
#######################################################################################################
    
def process_file(input_file, output_file, encoding='latin-1'):
    try:
        encoding = detect_encoding(input_file) # ajustes p/ ambientes nativos do Jupiterlab
        debug(f"*** Lendo ==> codificação: {encoding} arquivo: {input_file}")
        with open(input_file, 'r', encoding=encoding) as infile:
            lines = infile.readlines()
        
        with open(output_file, 'w', encoding=encoding) as outfile:
            for line in lines:
                outfile.write(line)
                if line.startswith('|9999|'):
                    break
    except UnicodeDecodeError as e:
        debug(f"Erro de codificação ao ler o arquivo: {e}")
    except Exception as e:
        debug(f"Erro ao processar o arquivo: {e}")


    
def calculate_md5(file_path):
    """Calcula o hash MD5 de um arquivo."""
    md5 = hashlib.md5()
    try:
        with open(file_path, 'rb') as f:
            while True:
                data = f.read(65536)  # Lê o arquivo em blocos de 64KB
                if not data:
                    break
                md5.update(data)
    except Exception as e:
        debug(f"Erro ao calcular o hash MD5: {e}")
    return md5.hexdigest()


def read_file_with_encoding(input_file, encodings=['latin-1', 'utf-8', 'utf-16']):
    """Tenta ler um arquivo com múltiplas codificações."""
    for encoding in encodings:
        try:
            encoding = detect_encoding(input_file) # ajustes p/ ambientes nativos do Jupiterlab
            debug(f"*** Lendo ==> codificação: {encoding} arquivo: {input_file}")
            with open(input_file, 'r', encoding=encoding) as infile:
                return infile.readlines()
        except UnicodeDecodeError as e:
            debug(f"Erro de codificação ao ler o arquivo com {encoding}: {e}")
    raise UnicodeDecodeError(f"Não foi possível ler o arquivo com as codificações fornecidas: {encodings}")


def extract_field_from_left(input_file, search_prefix='|0000|', delimiter='|', field_position=10):
    """Extrai um campo específico de uma linha que começa com um prefixo determinado."""
    try:
        lines = read_file_with_encoding(input_file)
        for line in lines:
            if line.startswith(search_prefix):
                fields = line.strip().split(delimiter)
                if len(fields) >= field_position:
                    return fields[field_position - 1]  # -1 porque índices são baseados em 0
                else:
                    return f"Menos de {field_position} campos na linha."
        return "Linha com o prefixo especificado não encontrada."
    except Exception as e:
        return f"Erro ao processar o arquivo: {e}"


def consultar_situacao_efdi(CNPJ, IE, file_id): # consultar_situacao_cif(CNPJ, IE, file_id):
    """Consulta a situação de uma escrituração fiscal via serviço web."""
    url = "http://www.sped.fazenda.gov.br/SpedFiscalServer/WSConsultasPVA/WSConsultasPVA.asmx"
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "Accept": "application/soap+xml, application/dime, multipart/related, text/*",
        "User-Agent": "Axis/1.4",
        "Host": "www.sped.fazenda.gov.br",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "SOAPAction": "\"http://br.gov.serpro.spedfiscalserver/consulta/consultarSituacaoEscrituracao\""
    }
    body = f"""<?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soapenv:Body>
            <consultarSituacaoEscrituracao xmlns='http://br.gov.serpro.spedfiscalserver/consulta'>
                <niContribuinte>{CNPJ}</niContribuinte>
                <ieContribuinte>{IE}</ieContribuinte>
                <identificacaoArquivo>{file_id}</identificacaoArquivo>
            </consultarSituacaoEscrituracao>
        </soapenv:Body>
    </soapenv:Envelope>"""

    response = requests.post(url, data=body, headers=headers)
    
    if response.status_code == 200:
        root = ET.fromstring(response.content)
        namespace = {'soap': 'http://schemas.xmlsoap.org/soap/envelope/', 'ns': 'http://br.gov.serpro.spedfiscalserver/consulta'}
        situacao = root.find('.//ns:Situacao', namespaces=namespace)
        if situacao is not None:
            situacao_text = situacao.text.strip()
            expected_message = "A escrituração visualizada encontra-se na base de dados do Sped e corresponde à última escrituração fiscal enviada."
            if situacao_text == expected_message:
                return "A escrituração visualizada se encontra na base de dados do SPED e corresponde à última escrituração fiscal enviada."
            else:
                return f"A escrituração visualizada não se encontra na base de dados do SPED. Mensagem encontrada: {situacao_text}"
        else:
            return "O campo 'situacao' não foi encontrado."
    else:
        return f"Erro na solicitação: {response.status_code}\n{response.text}"



def consultar_situacao_efdc(CNPJ, file_id):
    """
    Consulta a situação de uma escrituração e verifica a validade.

    :param NIRE: Número de Identificação do Registro de Escrituração.
    :param sha1_hash: Hash do arquivo.
    :return: Mensagem indicando a validade da escrituração.
    """
    # URL para a qual a solicitação será enviada
    #url = "http://www.sped.fazenda.gov.br/wsconsultasituacao/wsconsultasituacao.asmx"
    url = "http://www.sped.fazenda.gov.br/SPEDPISCofins/WSConsulta/WSConsulta.asmx"
    
    # Cabeçalhos da solicitação
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "Accept": "application/soap+xml, application/dime, multipart/related, text/*",
        "User-Agent": "Axis/1.4",
        "Host": "www.sped.fazenda.gov.br",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "SOAPAction": "\"http://br.gov.serpro.spedpiscofinsserver/consulta/consultarSituacaoEscrituracao\""

    }

    # Corpo da solicitação (arquivo XML)
    body = f"""<?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soapenv:Body>
            <consultarSituacaoEscrituracao
                xmlns='http://br.gov.serpro.spedpiscofinsserver/consulta'>
                    <niContribuinte>{CNPJ}</niContribuinte>
                    <identificacaoArquivo>{file_id}</identificacaoArquivo>
                </consultarSituacaoEscrituracao>
        </soapenv:Body>
    </soapenv:Envelope>"""

    # Enviando a solicitação POST
    response = requests.post(url, data=body, headers=headers)
    
    # Verificando o status da resposta
    if response.status_code == 200:
        # Analisando o conteúdo da resposta
        root = ET.fromstring(response.content)
        # Define namespace for searching
        namespace = {'soap': 'http://schemas.xmlsoap.org/soap/envelope/', 'ns': 'http://br.gov.serpro.spedpiscofinsserver/consulta'}

        # Find the 'situacao' element with namespace
        situacao = root.find('.//ns:situacao', namespaces=namespace)

        # Check if it contains the expected message
        expected_message = "A escrituração visualizada se encontra na base de dados do SPED."
        if situacao is not None:
            situacao_text = situacao.text.strip()
            if situacao_text == expected_message:
                return("A escrituração visualizada se encontra na base de dados do SPED.")
            else:
                return(f"A escrituração visualizada não se encontra na base de dados do SPED. Mensagem encontrada: {situacao_text}")
        else:
            debug("O campo 'situacao' não foi encontrado.")

    else:
        return f"Erro na solicitação: {response.status_code}\n{response.text}"


def consultar_situacao_ecd(NIRE, sha1_hash): # onsultar_situacao_ns(NIRE, sha1_hash): 
    """
    Consulta a situação de uma escrituração e verifica a validade.

    :param NIRE: Número de Identificação do Registro de Escrituração.
    :param sha1_hash: Hash do arquivo.
    :return: Mensagem indicando a validade da escrituração.
    """
    # URL para a qual a solicitação será enviada
    url = "http://www.sped.fazenda.gov.br/wsconsultasituacao/wsconsultasituacao.asmx"

    # Cabeçalhos da solicitação
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "Accept": "application/soap+xml, application/dime, multipart/related, text/*",
        "User-Agent": "Axis/1.4",
        "Host": "www.sped.fazenda.gov.br",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "SOAPAction": "http://tempuri.org/SituacaoEscrituracao"
    }

    # Corpo da solicitação (arquivo XML)
    body = f"""<?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soapenv:Body>
            <ns1:SituacaoEscrituracao soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://tempuri.org/">
                <ns1:NIRE xsi:type="xsd:string">{NIRE}</ns1:NIRE>
                <ns1:identificacaoArquivo xsi:type="xsd:string">{sha1_hash}</ns1:identificacaoArquivo>
                <ns1:versaoPVA xsi:type="xsd:string"></ns1:versaoPVA>
            </ns1:SituacaoEscrituracao>
        </soapenv:Body>
    </soapenv:Envelope>"""

    # Enviando a solicitação POST
    response = requests.post(url, data=body, headers=headers)

    # Verificando o status da resposta
    if response.status_code == 200:
        # Analisando o conteúdo da resposta
        root = ET.fromstring(response.content)
        
        # Encontrando o elemento 'SituacaoEscrituracaoResult' que contém o XML embutido
        situacao_result = root.find('.//{http://tempuri.org/}SituacaoEscrituracaoResult')
        if situacao_result is not None:
            # Extraindo o conteúdo do elemento 'SituacaoEscrituracaoResult'
            embedded_xml = ET.fromstring(situacao_result.text)

            # Encontrando o campo 'consSituacaoResult' no XML embutido
            consSituacaoResult = embedded_xml.find('.//{http://www.sped.fazenda.gov.br/SPEDContabil/RetornoConsultaSituacao}consSituacaoResult')
            
            if consSituacaoResult is not None and 'retVerif' in consSituacaoResult.attrib:
                # Verificando o valor do campo 'retVerif'
                if consSituacaoResult.attrib['retVerif'] == "A escrituração visualizada é a mesma que se encontra na base de dados do SPED.":
                    return "A escrituração é válida."
                else:
                    return "A escrituração não é válida."
            else:
                return "O campo 'retVerif' não foi encontrado no XML embutido."
        else:
            return "O elemento 'SituacaoEscrituracaoResult' não foi encontrado."
    else:
        return f"Erro na solicitação: {response.status_code}\n{response.text}"


def calculate_sha1(file_path):
    sha1 = hashlib.sha1()
    try:
        with open(file_path, 'rb') as f:
            while True:
                data = f.read(65536)  # Lê o arquivo em blocos de 64KB
                if not data:
                    break
                sha1.update(data)
    except Exception as e:
        debug(f"Erro ao calcular o hash SHA-1: {e}")
    return sha1.hexdigest()


def process_directory_cif(directory_path):
    """Processa todos os arquivos .txt em um diretório específico e exibe uma tabela com os resultados."""
    results = []
    for file_name in os.listdir(directory_path):
        if file_name.endswith('.txt'):
            input_file_path = os.path.join(directory_path, file_name)
            file_id = calculate_md5(input_file_path)
            debug(f'O hash MD5 do arquivo processado {file_name} é: {file_id}')

            CNPJ = extract_field_from_left(input_file_path, field_position=8)
            if 'Erro' in CNPJ or 'Linha' in CNPJ:
                debug(f"Erro ao extrair o CNPJ do arquivo {file_name}: {CNPJ}")
                CNPJ = "Erro"
            debug(f'O valor de CNPJ do arquivo {file_name} é: {CNPJ}')

            IE = extract_field_from_left(input_file_path, field_position=11)
            if 'Erro' in IE or 'Linha' in IE:
                debug(f"Erro ao extrair o IE do arquivo {file_name}: {IE}")
                IE = "Erro"
            debug(f'O valor de IE do arquivo {file_name} é: {IE}')

            resultado = consultar_situacao_efdi(CNPJ, IE, file_id)
            debug(f'Resultado da consulta para o arquivo {file_name}: {resultado}')

            results.append({
                'Origem do Arquivo': file_name,
                'Hash': file_id,
                'CNPJ': CNPJ,
                'IE': IE,
                'Resultado da Validação': resultado
            })

    df = pd.DataFrame(results)
    return df


def process_directory_efdc(directory_path): # process_directory_cf(directory_path):
    """
    Processa todos os arquivos .txt em um diretório específico e exibe uma tabela com os resultados.

    :param directory_path: Caminho do diretório contendo arquivos .txt.
    """
    results = []
    
    for file_name in os.listdir(directory_path):
        if file_name.endswith('.txt'):
            input_file_path = os.path.join(directory_path, file_name)
            

            # Calculando o hash SHA-1 do arquivo processado
            file_id = calculate_md5(input_file_path)
            debug(f'O hash MD5 do arquivo processado {file_name} é: {file_id}')

            # Extraindo o sétimo campo a partir da esquerda e armazenando na variável nire
            CNPJ = extract_seventh_field_from_left_cf(input_file_path)
            if 'Erro' in CNPJ or 'Linha' in CNPJ:
                debug(f"Erro ao extrair o CNPJ do arquivo {file_name}: {CNPJ}")
                CNPJ = "Erro"
            debug(f'O valor de CNPJ do arquivo {file_name} é: {CNPJ}')

            # Chamando a função e obtendo o resultado
            resultado = consultar_situacao_efdc(CNPJ, file_id) # resultado = consultar_situacao_cf(CNPJ, file_id)
            debug(f'Resultado da consulta para o arquivo {file_name}: {resultado}')

            # Adicionando os resultados à lista
            results.append({
                'Origem do Arquivo': file_name,
                'Hash': file_id,
                'CNPJ': CNPJ,
                'Resultado da Validação': resultado
            })

    # Criando um DataFrame com os resultados
    df = pd.DataFrame(results)
    return df


def process_directory_ns(directory_path):
    """
    Processa todos os arquivos .txt em um diretório específico e exibe uma tabela com os resultados.

    :param directory_path: Caminho do diretório contendo arquivos .txt.
    """
    results = []
    
    for file_name in os.listdir(directory_path):
        if file_name.endswith('.txt'):
            input_file_path = os.path.join(directory_path, file_name)
            output_file_path = os.path.join(directory_path, f"processed_{file_name}")

            # Processando o arquivo
            process_file(input_file_path, output_file_path)

            # Calculando o hash SHA-1 do arquivo processado
            sha1_hash = calculate_sha1(output_file_path)
            debug(f'O hash SHA-1 do arquivo processado {file_name} é: {sha1_hash}')

            # Extraindo o sétimo campo a partir da esquerda e armazenando na variável nire
            NIRE = extract_seventh_field_from_left(output_file_path)
            if 'Erro' in NIRE or 'Linha' in NIRE:
                debug(f"Erro ao extrair o NIRE do arquivo {file_name}: {NIRE}")
                NIRE = "Erro"
            debug(f'O valor de NIRE do arquivo {file_name} é: {NIRE}')

            # Chamando a função e obtendo o resultado
            resultado = consultar_situacao_ecd(NIRE, sha1_hash)
            debug(f'Resultado da consulta para o arquivo {file_name}: {resultado}')

            # Adicionando os resultados à lista
            results.append({
                'Origem do Arquivo': file_name,
                'Hash': sha1_hash,
                'NIRE': NIRE,
                'Resultado da Validação': resultado
            })



def extract_seventh_field_from_left_ns(input_file, search_prefix='|I030|', delimiter='|', field_position=8):
    try:
        encoding = detect_encoding(input_file) # ajustes p/ ambientes nativos do Jupiterlab
        debug(f"*** Lendo ==> codificação: {encoding} arquivo: {input_file}")
        with open(input_file, 'r', encoding=encoding) as infile:
            for line in infile:
                if line.startswith(search_prefix):
                    # Divide a linha pelo delimitador '|'
                    fields = line.strip().split(delimiter)
                    
                    # Verifica se há pelo menos 7 campos
                    if len(fields) >= field_position:
                        # Pega o sétimo campo a partir da esquerda
                        nire = fields[field_position - 1]  # -1 porque índices são baseados em 0
                        return nire
                    else:
                        return f"Menos de {field_position} campos na linha."
        
        return "Linha com o prefixo especificado não encontrada."
    except Exception as e:
        return f"Erro ao processar o arquivo: {e}"


def extract_seventh_field_from_left_cf(input_file, search_prefix='|0000|', delimiter='|', field_position=10):
    try:
        encoding = detect_encoding(input_file) # ajustes p/ ambientes nativos do Jupiterlab
        debug(f"*** Lendo ==> codificação: {encoding} arquivo: {input_file}")
        with open(input_file, 'r', encoding=encoding) as infile:
            for line in infile:
                if line.startswith(search_prefix):
                    # Divide a linha pelo delimitador '|'
                    fields = line.strip().split(delimiter)
                    
                    # Verifica se há pelo menos 7 campos
                    if len(fields) >= field_position:
                        # Pega o sétimo campo a partir da esquerda
                        cnpj = fields[field_position - 1]  # -1 porque índices são baseados em 0
                        return cnpj
                    else:
                        return f"Menos de {field_position} campos na linha."
        
        return "Linha com o prefixo especificado não encontrada."
    except Exception as e:
        return f"Erro ao processar o arquivo: {e}"


#######################################################################################################
#  fim copiado dos ipynbs Elio
#######################################################################################################

# def print_list_debug(lista):
#     print(f"print_list_debug\n")
#     for item in lista:
#         print(f"print_list_debug: {date_sort(item)} {item}")
#     print(f"\n\n")


def date_sort(filename):

    partes = re.search('.*_([0-9a-f]{32}).*', filename )
    if partes:
        u = partes.group(1)
    else:
        u = 0    
    try:
        t = uuid.UUID(u).time
    except:
        t = 0

    return  t   

def click_tabela(e):

    colunac = e.control.data[1]
    msg = "'" + colunac + "' :\n\n"
    msg += str(e.control.data[0]) + "\n\n"
    debug(f"click_tabela(e): \n{msg} {colunac}")

    tmp = res_val_r.loc[e.control.data[2]]  # resultado anterior data=[row[header],header,index],
    debug(f"tmp: {str(tmp)}")
    detalhe = res_val[(res_val['Origem do Arquivo'] != "") & (res_val['CNPJ'] == tmp['CNPJ']) & (res_val['UF'] == tmp['UF']) & (res_val['Tipo'] == tmp['Tipo']) ] # 

    msg += "\n" 
    #tmp = tmp.reset_index()
    for index, row in detalhe.iterrows():
        debug(f"detalhe.iterrows(): {index} {row[colunac]}")
        matchmes = re.search("^jan|^fev|^mar|^abr|^mai|^jun|^jul|^ago|^set|^out|^nov|^dez", colunac, re.IGNORECASE) 
        matchinv = re.search("inv", colunac, re.IGNORECASE) 
        if matchmes: #if(row[colunac] != 0): # tratar click diferenciado por colunas

            
            n1, n2 = respostaok(row['Resultado da Validação'])
            if n1 and not matchinv: 
                
                #idx = row['Origem do Arquivo'].split("-")
                msg += f"\n\n# Arquivo {row['index']}:\n\n"
                msg += row['Origem do Arquivo'] + " "
                msg += "\n\n"
                tmp = ""
                msg += tmp + row['Resultado da Validação'] + " "
                msg += "\n\n"
                msg += str(row['Data Inicial']) + " \n"
                msg += str(row['Data Final']) + " \n"
                msg += row['Prestadora'] + " \n"
                msg += str(row['CNPJ']) + " \n"
                msg += row['UF'] + " \n"
                msg += row['Tipo'] + " \n"
                msg += "\n\n"
                msg += "Parte inicial do arquivo:\n"
                msg += row['Início do Arquivo'] + "... tamanho: " + str(row['Tamanho do Arquivo']) + ' bytes'
                msg += "\n\n\n"

            if n2 and matchinv: 
                msg += f"\n# Arquivo {row['index']}:\n\n"
                msg += row['Origem do Arquivo'] + " "
                msg += "\n\n"
                tmp = "*** ERRO *** "
                msg += tmp + row['Resultado da Validação'] + " "
                msg += "\n\n"
                msg += str(row['Data Inicial']) + " \n"
                msg += str(row['Data Final']) + " \n"
                msg += row['Prestadora'] + " \n"
                msg += str(row['CNPJ']) + " \n"
                msg += row['UF'] + " \n"
                msg += row['Tipo'] + " "
                msg += "\n\n"
                msg += "Parte inicial do arquivo:\n"
                msg += row['Início do Arquivo'] + "... tamanho: " + str(row['Tamanho do Arquivo']) + ' bytes'
                msg += "\n\n\n"
        
    return msg    


def lista_relatorios():

    

    res = {}
    res['path'] = str(Path(log_).as_posix())
    res['args-last'] = json.loads(le_json('args-last'))
    res['relatorios'] = []
    
    filename = os.listdir(res['path'])

    filename.sort(key=date_sort)
    #filename.sort(key=os.path.getctime)
    filename.reverse()

    for entry in filename:
        if os.path.isfile(f"{res['path']}/{entry}"):

            partes = re.search(f'{relpre}(.*_[0-9a-f][0-9a-f]*).json', entry )

            if partes:
                tmp = {}

                with open(f"{res['path']}/{entry}", 'r', encoding="utf-8") as file:
                    item = json.loads(file.read())
                    
                    tmp['descricao'] = f"Relatório salvo de consulta na SRF feita em {item['data-da-consulta']} : Matriz {item['cnpj-matriz']} ({item['razao-social']}) - Ano Fiscal {item['ano-fiscal']}"
                    tmp['relatorio-html'] = {}
                    tmp['relatorio-json'] = []
                    tmp['dataframes'] = []
                    tmp['dataframes-template'] = f"template{partes.group(1)}.json"

                    #  
                    arq = {}
                    arq['descricao'] = f"Relatório Textual"
                    arq['mime-type'] = f"text/html"
                    arq['base64'] = f"{True}"
                    arq['arquivo'] = f"{relpre}{partes.group(1)}.html" 
                    tmp['relatorio-html'] = arq

                    arq = {}
                    arq['descricao'] = f"Relatório json"
                    arq['mime-type'] = f"application/json"
                    arq['base64'] = f"{True}"
                    arq['arquivo'] = f"{entry}"  
                    tmp['relatorio-json'] = arq

                    arq = {}
                    arq['descricao'] = f"Tabela filtrada"
                    arq['mime-type'] = f"application/json"
                    arq['base64'] = f"{True}"
                    arq['arquivo'] = f"dataframe-tabela-expandida_{partes.group(1)}.json"  
                    tmp['dataframes'].append(arq)

                    arq = {}
                    arq['descricao'] = f"Tabela bruta"
                    arq['mime-type'] = f"application/json"
                    arq['base64'] = f"{True}"
                    arq['arquivo'] = f"dataframe-tabela-bruta_{partes.group(1)}.json"  
                    tmp['dataframes'].append(arq)


                res['relatorios'].append(tmp)
    
    return json.dumps(res)      


def lista_pasta(pasta):

    res = {}
    res['path'] = {}
    res['dirs'] = []
    res['files'] = []

    if pasta == '':
        pasta = pastaRaiz

    try:
        os.listdir(pasta)
        res['path'] = str(Path(pasta).as_posix()) 
    except:
        res['path'] = str(Path(pastaRaiz).as_posix())

    
    if re.search(r"^[a-z]:/$", pasta, re.IGNORECASE):
        res['path'] = str(Path(pastaRaiz).as_posix())

    # dataparent = Path(res['path']).parent.absolute().as_posix()
    # res['dirs'].append(dataparent)

    for entry in os.listdir(res['path']): # for entry in os.listdir(directory):
        if os.path.isdir(f"{res['path']}/{entry}"):
            res['dirs'].append(entry)
        else:
            #mime_type, encoding = mimetypes.guess_type(f"{res['path']}/{entry}")
            res['files'].append(f"{entry}")
    
    return json.dumps(res)      

def get_file(file):

    f = open(f"{log_}/{file}", "rb")
    #print(f.read())

    b = base64.b64encode(f.read()) # bytes base64.b64decode(encodedStr)
    base64_str = b.decode('utf-8')

    return base64_str # f.read() # base64.b64encode(f.read())

def tail_log(uuidlog):

    res = {}
    res['file'] = str(Path(f"{log_}/{uuidlog}.log").as_posix()) 

    try:
        with open(res['file'], "r") as f:
            for line in f:
                pass

        res['tail'] = line
    except:
        res['tail'] = ""
    
    return json.dumps(res)    


def log(msg):

    r = True
    res = {}
    res['file'] = str(Path(f"{log_}/{iduuid}.log").as_posix()) 

    try:
        with open(res['file'], 'a', encoding="utf-8") as file: # Validando: {cntanon0} arquivos
            file.write(f"\n{msg}")
    except:
        r = False
    
    return r    



def fmtnome(name):

    ret = ""
    name0 = ''.join(ch for ch in unicodedata.normalize('NFKD', name) 
        if not unicodedata.combining(ch))

    tmp = re.sub(r"[^A-Za-z0-9_ ]", " ", name0)
    tmp = tmp.title()
    ret = re.sub(r"[^A-Za-z0-9_]", "", tmp)

    return ret

def sign_sha1(file_path): 

    sha1 = hashlib.sha1()
    fimtxt = False
    sig = " (sem assinatura) "
    data = bytearray()
    debug(f"type(data): {type(data)}")
    try:
        with open(file_path, 'rb') as f:
            Lines = f.readlines()
            for line in Lines:
                # debug(f"type(data): {type(data)}  type(line): {type(line)}")
                # debug(line)
                if line.startswith(b'|9999|'):
                    debug(f"9999 type(data): {type(data)}  type(line): {type(line)}")
                    debug(line)
                    data.extend(line)
                    fimtxt = True
                else:
                    if fimtxt: # próxima linha após fim
                        debug(f"fim type(data): {type(data)}  type(line): {type(line)}")
                        debug(line)
                        sig = " (detectada uma assinatura, verificação de autenticidade ainda não implementada) " # Tem alguma assinatura após final
                        sha1.update(data)
                        return sha1.hexdigest(), sig
                    else:    
                        data.extend(line)
                    

        

    except Exception as e:
        debug(f"Erro ao calcular o hash SHA-1: {e}")
        #  Erro ao calcular o hash SHA-1: argument should be integer or bytes-like object, not 'str'
    return "", sig


def salva_json(key, value):

    with open(log_+"/"+key + ".json", 'w', encoding="utf-8") as f:
        f.write(value)  
    return True


def le_json(key):

    value = "{}"
    path = log_+"/"+key + ".json"

    try:
        with open(path, 'r', encoding="utf-8") as file:
            value = file.read()
    except:
        debug(f"erro le_json: {key}")    

    return value

def remove_json(key):

    if os.path.isfile(log_+"/"+key + ".json"):
        os.remove(log_+"/"+key + ".json") 

    return True

def salva_offline(key, value):

    global nomeapp, pastaTemp
    #page.client_storage.set(str(key+nomeapp), value) # debug ?
    sha256 = hashlib.sha256()
    sha256.update(nomeapp.encode('utf-8'))
    Path(pastaTemp+"/"+sha256.hexdigest()).mkdir(parents=True, exist_ok=True)
    with open(pastaTemp+"/"+sha256.hexdigest()+"/"+key, 'w', encoding="utf-8") as f:
        f.write(value)  
    return True


def le_offline(key, default):

    debug(f"le_offline: {key}")
    global nomeapp, pastaTemp
    value = default
    # if await page.client_storage.contains_key_async(str(key+nomeapp)):  # debug ?
    #     value = await page.client_storage.get_async(str(key+nomeapp))
    # else:
    #     pass #await salva_offline(str(key), default)  
    
    sha256 = hashlib.sha256()
    sha256.update(nomeapp.encode('utf-8'))
    try:
        with open(pastaTemp+"/"+sha256.hexdigest()+"/"+key, 'r', encoding="utf-8") as file:
            value = file.read()
    except:
        pass 
        debug(f"erro le_offline: {pastaTemp}/{sha256.hexdigest()}/{key}")
    return value


def remove_offline(key):

    global nomeapp, pastaTemp
    #page.client_storage # shutil.rmtree(pastaTemp+"/out") # debug ?
    sha256 = hashlib.sha256()
    sha256.update(nomeapp.encode('utf-8'))
    if os.path.isfile(pastaTemp+"/"+sha256.hexdigest()+"/"+key):
        os.remove(pastaTemp+"/"+sha256.hexdigest()+"/"+key) 

    return True


def existe(key):

    global nomeapp, pastaTemp
    value = False
    # if await page.client_storage.contains_key_async(str(key+nomeapp)):  # debug ?
    #     value = True
    sha256 = hashlib.sha256()
    sha256.update(nomeapp.encode('utf-8'))
    value = os.path.isfile(pastaTemp+"/"+sha256.hexdigest()+"/"+key)

    return value

def detalha(idx, colunac):

    global res_brutos

    debug(f"click_tabela(e): \n{msg} {colunac}")

    tmp = res_val_r.loc[e.control.data[2]]  # resultado anterior data=[row[header],header,index],
    debug(f"tmp: {str(tmp)}")
    detalhe = res_val[(res_val['Origem do Arquivo'] != "") & (res_val['CNPJ'] == tmp['CNPJ']) & (res_val['UF'] == tmp['UF']) & (res_val['Tipo'] == tmp['Tipo']) ] # 

    msg += "\n" 
    #tmp = tmp.reset_index()
    for index, row in detalhe.iterrows():
        debug(f"detalhe.iterrows(): {index} {row[colunac]}")
        matchmes = re.search("^jan|^fev|^mar|^abr|^mai|^jun|^jul|^ago|^set|^out|^nov|^dez", colunac, re.IGNORECASE) 
        matchinv = re.search("inv", colunac, re.IGNORECASE) 
        if matchmes: #if(row[colunac] != 0): # tratar click diferenciado por colunas

            
            n1, n2 = respostaok(row['Resultado da Validação'])
            if n1 and not matchinv: 
                
                #idx = row['Origem do Arquivo'].split("-")
                msg += f"\n\n# Arquivo {row['index']}:\n\n"
                msg += row['Origem do Arquivo'] + " "
                msg += "\n\n"
                tmp = ""
                msg += tmp + row['Resultado da Validação'] + " "
                msg += "\n\n"
                msg += str(row['Data Inicial']) + " \n"
                msg += str(row['Data Final']) + " \n"
                msg += row['Prestadora'] + " \n"
                msg += str(row['CNPJ']) + " \n"
                msg += row['UF'] + " \n"
                msg += row['Tipo'] + " \n"
                msg += "\n\n"
                msg += "Parte inicial do arquivo:\n"
                msg += row['Início do Arquivo'] + "... tamanho: " + str(row['Tamanho do Arquivo']) + ' bytes'
                msg += "\n\n\n"

            if n2 and matchinv: 
                msg += f"\n# Arquivo {row['index']}:\n\n"
                msg += row['Origem do Arquivo'] + " "
                msg += "\n\n"
                tmp = "*** ERRO *** "
                msg += tmp + row['Resultado da Validação'] + " "
                msg += "\n\n"
                msg += str(row['Data Inicial']) + " \n"
                msg += str(row['Data Final']) + " \n"
                msg += row['Prestadora'] + " \n"
                msg += str(row['CNPJ']) + " \n"
                msg += row['UF'] + " \n"
                msg += row['Tipo'] + " "
                msg += "\n\n"
                msg += "Parte inicial do arquivo:\n"
                msg += row['Início do Arquivo'] + "... tamanho: " + str(row['Tamanho do Arquivo']) + ' bytes'
                msg += "\n\n\n"
        
        

def recuperavpath(path):

    global pastaRaiz, pasta_in, vpath


    while path.find(pasta_in) != -1: # se ainda não chegou na pasta de origem
        n1 = path[2+len(pasta_in):].find("/")
        n = 2+len(pasta_in) + n1
        path1 = path[:n]
        path2 = path[n:]
        #debug(f"recuperavpath: >{path1}< >{path2}<")        
        #tmp = os.path.dirname(path)
        ori = vpath[vpath['destino'] == path1]
        ori['origem'].iloc[0]
        debug(ori)
        debug(ori['origem'].iloc[0])
        path = ori['origem'].iloc[0] + path2

    n = len(pastaRaiz) + 1
    paths = str(path)
    pathf = paths[n:]
    pathf = unquote(pathf)
    debug(f"recuperavpath: >{pathf}< {n}<")
    return pathf


def str_field_from_left(line, field_position=10):
    """ Extrai um campo específico de uma string delimitada por | """
    fields = line.strip().split("|")
    if len(fields) >= field_position:
        return fields[field_position - 1]  # -1 porque índices são baseados em 0
    else:
        return f"*** Erro: Menos de {field_position} campos na linha."



def generate_password(length: int) -> str:
    #storing letters, numbers and special characters
    charset = "abcdefghijklmnopqrstuvwxyz01234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()?"
    #random sampling by joining the length of the password and the variables
    return "".join(random.sample(charset, length))


def linha1ascii(file_path): 
    enc = "ascii"
    with open(file_path, 'rb') as file: 
        for line in file: 
            try:    
                #if line.startswith(b'|0000|'):
                if re.search(r"0000", line.decode('ascii')): # 'ascii'
                    debug(f"l1 ok: {line.decode('ascii')}")
                    return line.decode('ascii')
                else:
                    return "desconsiderado por ausencia 0000 na primeira linha"
            except:   
                try:  
                    #if line.startswith(b'|9999|'):  
                    if re.search(r"0000", line.decode('latin-1')): # 'ascii'
                        debug(f"l1 ok: {line.decode('latin-1')}")
                        return line.decode('latin-1')
                    else:
                        return "desconsiderado por ausencia 0000 na primeira linha"
                except: 
                    debug("l1 nok") 
                    #if line.startswith(b'|9999|'):
                    if re.search(r"0000", str(line)):
                        debug(f"l1 : {str(line)}")
                        result = detect(line)
                        if result['encoding'] is not None:
                            debug('*** got', result['encoding'], 'as detected encoding')
                            return line.decode(result['encoding'])
                        else:
                            debug("*** encoding não identificado")    
                            return "desconsiderado por encoding não identificado"
                    else:
                        return "desconsiderado por ausencia 0000 na primeira linha"
            
    return "desconsiderado por divergência na primeira linha"


def detect_encoding(file_path): 
    global tcodec
    tini = datetime.now()
    with open(file_path, 'rb') as file: 
        detector = chardet.universaldetector.UniversalDetector() 
        n = 0
        for line in file: 
            n = n + 1
            if n == 1:
                try:    
                    if re.search(r"0000", line.decode('ascii')):
                        debug(f"l1 ok: {line.decode('ascii')}")
                except:   
                    debug("l1 nok") 
                    return None

            detector.feed(line) 
            if detector.done: 
                break
     
        detector.close() 

    # tfim = datetime.now()
    # tcodec = tcodec + (tfim - tini)
    # debug(f"encoding: {detector.result['encoding']} tempo para detecção: {tfim - tini}")     
    return detector.result['encoding'] 


def mostraraiz():
    global pastaRaiz
    try:
        raiz = str(Path(pastaRaiz).as_uri())
    except:
        raiz = "file:///"    
    return raiz
    
def headfile(fileuri):

    p = urlparse(fileuri) # urllib.parse.unquote(fileuri) # urlparse(fileuri)
    path = str(unquote(p.netloc + "/" + p.path)) #  str(unquote(os.path.join(p.netloc, p.path)))
    first_lines = ''

    try:
        # encoding = detect_encoding(path)
        # if path.find(".sped_") != -1: # gambiarra bug detecção 
        #         encoding = 'latin-1'
        # debug(encoding)
        # with open(path, "r", encoding=encoding) as f:
            
        #     for i in range(1):
        #         first_lines += f.readline(1024).strip('\n') + "\n"
        first_lines +=  '* Obs.: Visualização temporariamente desabilitada !  ' 

        # info = os.stat(path)
        first_lines +=  "... tamanho: " + str(os.path.getsize(path))  + ' bytes'

    except:
        first_lines = '* Obs.: Este arquivo temporário não está mais presente !'        

    return     first_lines

def confereDias(row, mes):

    global ano_ , meses

    val = 0
    if type(row) is not int: 
        val = row.count("dias")
        n = calendar.monthrange(int(ano_), mes )[1]
        for i in range(1, n+1):
            #tmp = row[row.name]
            if not row.find(str(i)) != -1:
                val = 0
                return val
    else:
        return 0

    return val

def meses_inclusos(ano , dataini, datafim, msg,m2):

    global meses

    debug(str(dataini))
    debug(str(datafim))
    debug(f"ano {ano}")


    ini = -1
    fim = -1

    res = []
    r2 = []
    for mes in range(1, 13):
        smes = str(mes)
        if(mes < 10):
            smes = "0" + str(mes)

        if ano == 0 or ano == "0": # aceitando string ou int aqui
            res.append(0)
            r2.append(0)
            #debug('meses inclusos ____')
        else:    

            n = calendar.monthrange(int(ano), int(smes))[1]
            ini = datetime.strptime(str(ano)+smes+"01",r'%Y%m%d')
            fim = datetime.strptime(str(ano)+smes+str(n),r'%Y%m%d')


            debug(f"meses_inclusos {ano} {dataini} (mes {ini} {fim}) {datafim} {msg} {m2} {datetime.strptime(dataini,r'%Y-%m-%d') <= fim and datetime.strptime(datafim,r'%Y-%m-%d') >= ini} {datetime.strptime(dataini,r'%Y-%m-%d') > ini and datetime.strptime(dataini,r'%Y-%m-%d') < fim} {datetime.strptime(datafim,r'%Y-%m-%d') > ini and datetime.strptime(datafim,r'%Y-%m-%d') < fim} ")

            if datetime.strptime(dataini,r'%Y-%m-%d') <= ini and datetime.strptime(datafim,r'%Y-%m-%d') >= fim: # r'%Y-%m-%d %H:%M:%S'
                r2.append(m2)
            elif datetime.strptime(dataini,r'%Y-%m-%d') > ini and datetime.strptime(dataini,r'%Y-%m-%d') < fim:
                dif = fim - datetime.strptime(dataini,r'%Y-%m-%d')
                r2.append(m2 * (dif.days)/n)
            elif datetime.strptime(datafim,r'%Y-%m-%d') > ini and datetime.strptime(datafim,r'%Y-%m-%d') < fim:
                dif = datetime.strptime(datafim,r'%Y-%m-%d') - ini
                r2.append(m2 * (dif.days)/n)
            else:
                r2.append(0)

            if datetime.strptime(dataini,r'%Y-%m-%d') <= ini and datetime.strptime(datafim,r'%Y-%m-%d') >= fim: # r'%Y-%m-%d %H:%M:%S'
                res.append(msg)
            else:
                #res.append(0)
                res.append(0)

                # if datetime.strptime(dataini,r'%Y-%m-%d') <= fim and datetime.strptime(datafim,r'%Y-%m-%d') >= ini: # r'%Y-%m-%d %H:%M:%S'
                #     #res.append(msg) ## res.append(meses[mes-1])
                #     r2.append(m2)
                # else:
                #     #res.append(0)
                #     r2.append(0)

            # else:
            #     res.append(0)
            #     r2.append(0)
            #     #debug('meses inclusos ____')

    debug(f"meses_inclusos {ano} {dataini} {datafim} {msg} {m2} ==> {res} {r2}")
    return res, r2

    
def prestref(cnpj, rs, ano):

    global dict_rs, cnpj_, prest_

    res = ""

    if cnpj_[:10] != cnpj[:10]:
        if cnpj == "":
            res = "Erro(formato de arquivo não tratado ou desconhecido)"    
        else:
            res = f"Erro(cnpj divergente {cnpj[:10]}-{rs})"
    elif ano != ano_: 
        res =  f"Erro(ano fiscal divergente {cnpj[:10]}-{rs})"       
    else:
        res = cnpj_
        if prest_ != "":
            res += f"({prest_})" # urllib.parse.quote('/', safe='')
    
    return res


def respostaok(res):

    # ajuste de parêmetros para contagens e cores
    res0 = res.split('(', 1)[0] # desconsiderar comentários do proprio script
    debug(f"respostaok: {res}")

    # if re.search(r"não", res0) or re.search(r"falha", res): ## resposta negativa da SRF ou falha
    #     debug("## resposta negativa da SRF ou falha")
    #     n1 = 0
    #     n2 = 1 
    if re.search(r"[a-zA-Z]", res0) and not re.search(r"não", res0): ## com resposta porém sem não da SRF
        debug("## com resposta porém sem não da SRF")
        n1 = 1
        n2 = 0
    elif not re.search(r"[a-zA-Z]", res): # sem resposta nenhuma
        debug("-c")
        n1 = 0
        n2 = 0
    else:
        debug("-c")
        n1 = 0
        n2 = 1

    #debug(f"respostaok(res) >{res}< {n1} {n1}")
    return n1, n2   

def trata_list_dir_recursive(directory,filtro,senha,level):

    global pastaRaiz, pastaTemp, pasta_in, vpath, vpcnt, errcon, pasta_nok, pasta_ok, cntanon, cntanon0, listatemporaria, res_val

    directory = str(Path(directory).as_posix())
    Path(pasta_in).mkdir(parents=True, exist_ok=True)

    if False:
        pg_ini("")

        dlg = ft.AlertDialog( title=ft.Text("Algum arquivo temporário foi apagado por outro aplicativo ou algum erro. \n\nSelecione e valide novamente os arquivos originais para extração dos arquivos validados."), scrollable=True, on_dismiss=lambda e: debug("Dialog dismissed!") )   
        e.control.page.dialog = dlg
        dlg.open = True
        e.control.page.update() 

    debug(f"=> entrou em {directory} {level} "  )
    
    # if directory.find(pastaRaiz) != -1: # cria pasta destino se estiver na pasta original
    #     Path(pasta_in+directory[len(pastaRaiz):]).mkdir(parents=True, exist_ok=True)

    for entry in os.listdir(directory):
        full_path = directory + "/" + entry # os.path.join(directory, entry)
        debug(f"=> entrou em directory: {directory} entry: {entry} "  )
        match7z = re.search("\\.7z$", full_path, re.IGNORECASE) # acrescentar outros formatos
        matchzip = re.search("\\.zip$|\\.sped$", full_path, re.IGNORECASE) 
        
        if os.path.isdir(full_path) and level > 0 : ## diretório
            if directory.find(pasta_nok) != -1 or directory.find(pasta_ok) != -1 : # exclui loop
                pass
            elif directory.find(pastaRaiz) != -1: # se ainda estiver nas pastas de origem
                vpcnt = vpcnt + 1
                path = pasta_in +"/"+ str(vpcnt) 
                #Path(path).mkdir(parents=True, exist_ok=True)
                path0 = full_path
                new_row = {"origem": path0, "destino": path}
                vpath = vpath._append(new_row, ignore_index=True)
                #Path(path).mkdir(parents=True, exist_ok=True)
                debug(f"shutil.copy(full_path, path ): shutil.copy({full_path}, {path} )")
                shutil.copytree(full_path, path )
                pass
            else:
                path = full_path
            trata_list_dir_recursive(path, filtro, senha, level - 1)

        elif match7z: ## compactado #
            vpcnt = vpcnt + 1
            # path = pasta_in+directory[len(pastaRaiz):]+"/"+entry 
            # path0 = path 
            #vpath.insert(vpcnt, path)
            path = pasta_in +"/"+ str(vpcnt) + "_"
            path0 = full_path
            new_row = {"origem": path0, "destino": path}
            vpath = vpath._append(new_row, ignore_index=True)
            if directory.find(pastaRaiz) != -1:
                shutil.copy(full_path, path + "._tmp_7z") 
            else:
                shutil.move(full_path, path + "._tmp_7z")
            archive = py7zr.SevenZipFile(path + "._tmp_7z", mode='r')
            archive.extractall(path=path) # , recursive=True
            archive.close()
            os.remove(path + "._tmp_7z")
            trata_list_dir_recursive(path , filtro, senha, level - 1)

        elif matchzip: ## compactado
            vpcnt = vpcnt + 1
            # path = pasta_in+directory[len(pastaRaiz):]+"/"+entry 
            # path0 = path
            #vpath.insert(vpcnt, path)
            path = pasta_in +"/"+ str(vpcnt) + "_"
            # debug(f"matchzip shutil.copy {full_path} {path}._tmp_zip")
            # debug(f"matchzip extract_nested_zip {path}._tmp_zip {path}_")
            path0 = full_path
            new_row = {"origem": path0, "destino": path}
            vpath = vpath._append(new_row, ignore_index=True)
            if directory.find(pastaRaiz) != -1:
                shutil.copy(full_path, path + "._tmp_zip")
            else:
                shutil.move(full_path, path + "._tmp_zip")
            #extract_nested_zip(path + "._tmp_zip", path )
            with zipfile.ZipFile(path + "._tmp_zip", 'r') as zfile:
                zfile.extractall(path=path)
            #debug(f" remove {zippedFile}")
            os.remove(path + "._tmp_zip")
            trata_list_dir_recursive(path , filtro, senha, level - 1)

        else:
            #global cntanon, cntanon0, listatemporaria, res_val

            if senha == "":
                cntanon0 = cntanon0 + 1 # só conta
                if directory.find(pastaRaiz) != -1: # se ainda estiver nas pastas de origem
                    path = pasta_in+"/00"+directory[len(pastaRaiz):]+"/"+entry 
                    Path(pasta_in+"/00").mkdir(parents=True, exist_ok=True)
                    shutil.copy(full_path, path )
                    debug(f"* shutil.copy( {full_path} , {path} )")
                    new_row = {"origem": full_path, "destino": pasta_in+"/00"}
                    vpath = vpath._append(new_row, ignore_index=True)
                    debug(f"* new_row {full_path} , {pasta_in}/00 )")
                else:
                    path = full_path
                    # new_row = {"origem": full_path, "destino": path}
                    # vpath = vpath._append(new_row, ignore_index=True)
                debug(f"cntanon0: {cntanon0}")
            else:    
                cntanon = cntanon + 1
                path = full_path

                mime_type, encoding = mimetypes.guess_type(path)

                
                with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file: # Validando: {cntanon0} arquivos
                    file.write(f"\nValidando: {int(100 * cntanon / cntanon0)}% de {cntanon0} arquivos")
                ###

                cnt = -1
                tipo = ""
                dataini = ""
                datafim = ""
                uf = "--"
                cnpj = ""
                rs = ""
                ano = 0
                tamanho = str(os.path.getsize(path))
                res = ""
                cass = ""

                #encoding = detect_encoding(path)
                first_line = linha1ascii(path)
                debug(f"linha1ascii: {first_line} ({path})")
                campos = first_line.split("|")

                for c in campos:
                    cnt = cnt +1
                    if re.search(r"^[0-9]{8}$", c):
                        #debug("data no campo " + str(cnt) + ": " + c)
                        if dataini == "":
                            try:
                                dataini = str(datetime.strptime(c,r'%d%m%Y'))[:10]
                                ano = c[4:8]
                            except:
                                pass
                        else:
                            try:
                                datafim = str(datetime.strptime(c,r'%d%m%Y'))[:10]
                            except:
                                pass   
                    if re.search(r"^[0-9]{14}$", c):
                        #debug("cnpj no campo " + str(cnt) + ": " + c) 
                        if pycpfcnpj.cnpj.validate(c):
                            cnpj = c[0:2] + "." + c[2:5] + "." + c[5:8] + "/" + c[8:12] + "-" + c[12:14] # 63.212.638/0361-35
                            #debug(f"c: {c} cnpj: {cnpj} tst: {tst}")
                            if cnt == 7:
                                tipo = "EFD ICMS-IPI"
                            if cnt == 9:
                                tipo = "EFD-Contribuições"
                    if re.search(r"^[A-Z]{2}$", c) :
                        #debug("uf no campo " + str(cnt) + ": " + c)  
                        uf = c # somente se encontrado
                    if re.search(r"^LECD$", c) :
                        #debug("LECD no campo " + str(cnt) + ": " + c)  
                        tipo = "ECD"
                    if re.search(r"^LECF$", c):
                        #debug("LECF no campo " + str(cnt) + ": " + c)  
                        tipo = "ECF"
                        res += "(ECF não implementado)"
                    if re.search(r"^LFPD$", c):
                        #debug("LFPD no campo " + str(cnt) + ": " + c)  
                        tipo = "LFPD"
                        res += "(LFPD não implementado)"
                    if re.search(r" ", c):
                        #debug("Prestadora no campo " + str(cnt) + ": " + c)  
                        rs = c

                
                
                ccnpj = pycpfcnpj.cpfcnpj.clear_punctuation(cnpj)

                if cnpj_[:10] == cnpj[:10]: # tipos = [,'ECF',','LFPD']
                    try:

                        if re.search(r"EFD-Contr", tipo) :
                            debug("* consulta srf")
                            file_id = calculate_md5(path)
                            sha1_hash, cass = sign_sha1(path) 
                            if sha1_hash == "":
                                res += "(não consultado)"
                            else:
                                res += consultar_situacao_efdc(ccnpj, file_id)
                            if res == "":
                                res += "(falha em consulta)"  
                            debug(f"* consultou >{path}< >{tipo}< >{res}< >{cnpj}< >{file_id}< *")

                        if re.search(r"EFD ICMS", tipo) :
                            debug("* consulta srf")
                            file_id = calculate_md5(path)
                            #IE = extract_field_from_left(path, field_position=11)  # verificar causa do erro
                            IE = str_field_from_left(first_line,field_position=11)
                            sha1_hash, cass = sign_sha1(path)  
                            if sha1_hash == "":
                                res += "(não consultado)"
                            else:
                                res += consultar_situacao_efdi(ccnpj, IE, file_id)
                            if res == "":
                                res = +"(falha em consulta)"  
                            debug(f"* consultou >{path}< >{tipo}< >{res}< >{cnpj}< >{IE}<  >{file_id}< *")

                        if re.search(r"ECD", tipo) :
                            debug("* consulta srf")
                            #NIRE = extract_seventh_field_from_left_ns(path)
                            NIRE = str_field_from_left(first_line,field_position=8)            
                            if '*** Erro' in NIRE or 'Linha' in NIRE:
                                debug(f"Erro ao extrair o NIRE do arquivo {path}: {NIRE}")
                                NIRE = "Erro"
                            # debug(f'O valor de NIRE do arquivo {path} é: {NIRE}')
                            sha1_hash, cass = sign_sha1(path)
                            if sha1_hash == "":
                                res += "(não consultado)"
                            else:
                                res += consultar_situacao_ecd(NIRE, sha1_hash)
                            if res == "":
                                res += "(falha em consulta)"
                            debug(f"******************************************* consultou >{path}< >{tipo}< >{res}< >{NIRE}< >{sha1_hash}< *")

                    except:
                        res += "(falha de conexão com a SRF)"
                        errcon = True
                else:
                    res += "(não consultado, cnpj de outra empresa)"

                res += cass # acrescentar comentários só após consulta SRF p/ simplificar análise da resposta

                if tipo== "":
                    # reseta 
                    #tipo = "não identificado"
                    dataini = '00000000'
                    datafim = '00000000'
                    uf = "--"
                    cnpj = ""
                    rs = ""
                    ano = 0
                    res += f"(não identificado {mime_type})"

                nomearq = path
                nomelink = ""
                # debug("nomearq: " +nomearq)

                if nomearq != "":
                    nomelink = str(Path(nomearq).as_uri())
                    tmp = recuperavpath(path)
                    nomearq = tmp # unquote(str(Path(tmp).as_uri()))

                # link
                link = nomelink
                # link0 = re.findall(r"file:/.*", nomelink)
                # if len(link0) >0:
                #     link = nomearq #f'\n<p><a href="'+ link0[0] +'">'+ link0[0] +'</a></p>\n'
                #     #debug(link)


                rs = prestref(cnpj, rs, ano)  # padroniza texto inserido para melhor visualização

                # meses + meserr
                n1, n2 = respostaok(res)
                mesin, m2 = meses_inclusos(str(ano),dataini,datafim, n1,n2)


                # debug(f"meses: {meses}")
                # debug(f"meserr: {meserr}")
                # debug(f"mesin: {mesin}")
                # debug(f"m2: {m2}")

                if uf == "":
                    uf = "--" # simplificar tratamento de chaves

                # popular dataframe 
                listatemporaria.append({
                    'Prestadora': rs,
                    'Ano Fiscal': ano,
                    'Tipo': tipo,
                    'UF': uf,
                    'CNPJ': cnpj,
                    meses[0]: mesin[0],
                    meses[1]: mesin[1],
                    meses[2]: mesin[2],
                    meses[3]: mesin[3],
                    meses[4]: mesin[4],
                    meses[5]: mesin[5],
                    meses[6]: mesin[6],
                    meses[7]: mesin[7],
                    meses[8]: mesin[8],
                    meses[9]: mesin[9],
                    meses[10]: mesin[10],
                    meses[11]: mesin[11],
                    meserr[0]: m2[0],
                    meserr[1]: m2[1],
                    meserr[2]: m2[2],
                    meserr[3]: m2[3],
                    meserr[4]: m2[4],
                    meserr[5]: m2[5],
                    meserr[6]: m2[6],
                    meserr[7]: m2[7],
                    meserr[8]: m2[8],
                    meserr[9]: m2[9],
                    meserr[10]: m2[10],
                    meserr[11]: m2[11],
                    'Data Inicial': dataini, #datetime.strptime(dataini,r'%d%m%Y'),
                    'Data Final': datafim,  #datetime.strptime(datafim,r'%d%m%Y'),
                    'Resultado da Validação': res,
                    'Início do Arquivo': first_line,
                    'Origem do Arquivo': nomearq,
                    'Tamanho do Arquivo': tamanho,
                    'Arquivo Temporário': link,
                    'cnt': 1,
                })    

# 
def gera_dataframes(visualizacao):

    global res_brutos, expandida, filtrada # , res_val

    with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
        file.write(f"\nProcessando e formatando resultados: Tabela {visualizacao}")


    debug(f"Matriz: {cnpj_} Ano: {ano_} ({prest_}) * gerando {visualizacao} res_val:")
    #print(res_val)

    # # ???
    # salva_offline('cnpj_',cnpj_)
    # salva_offline('ano_',ano_)
    # salva_offline('prest_',prest_)

    if visualizacao == 'expandida':

        remove_json(f"dataframe-tabela-expandida_{pathprestok}")
        expandida = pd.DataFrame()
        res_val = res_brutos # 
        res_val.reset_index(drop=True, inplace=True)
        cls = ['Prestadora', 'Ano Fiscal','Tipo', 'UF', 'CNPJ', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro', 'Jan inválidos','Fev inválidos','Mar inválidos','Abr inválidos','Mai inválidos','Jun inválidos','Jul inválidos','Ago inválidos','Set inválidos','Out inválidos','Nov inválidos','Dez inválidos', 'Resultado da Validação', 'Origem do Arquivo', 'Arquivo Temporário','cnt']
        cnpj0 = prestref(cnpj_, prest_, 0) # ???
        res_val_0 = pd.DataFrame() # pd.read_json(le_offline('res_brutos',{}))
        for tipo in tipos:
            debug(f"expandindo {tipo}")
            # tipos = ['ECD','ECF','EFD ICMS-IPI','EFD-Contribuições','LFPD'] 
            if tipo == 'EFD ICMS-IPI': # expandir p/ todas ufs

                for uf in estados:

                    debug(f"* df1: {cnpj0} {cnpj_} {ano_} {tipo} >{uf}<")
                    # dfteste = res_val.loc[ (res_val['Prestadora'].str.contains(cnpj_)) & (res_val['Ano Fiscal'] == int(ano_)) & (res_val['Tipo'] == tipo) & (res_val['UF'] == uf)] #  & (res_val['Ano Fiscal'] == ano_) & (res_val['Tipo'] == tipo) & (res_val['UF'] == uf)
                    # debug(f"len: {len(res_val.index)} {len(dfteste.index)}")
                    # debug(dfteste.to_string())
                    
                    df1 = res_val.loc[(res_val['Prestadora'].str.contains('Erro') == False) & (res_val['Ano Fiscal'] == ano_) & (res_val['Tipo'] == tipo) & (res_val['UF'] == uf)] #  & (res_val['Ano Fiscal'] == ano_) & (res_val['Tipo'] == tipo) & (res_val['UF'] == uf)
                    df1['Origem do Arquivo'] = df1['index'].astype(str) + ' - ' + df1['Origem do Arquivo']
                    df1['Arquivo Temporário'] = df1['index'].astype(str) + ' - ' + df1['Arquivo Temporário']
                    df1['Resultado da Validação'] = df1['index'].astype(str) + ' - ' + df1['Resultado da Validação']

                    #debug(df1)

                    if len(df1.index) > 0:
                        res_val_0 = res_val_0._append(df1)
                    else:    
                        dt = [cnpj0, ano_,tipo, uf, '', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', 0]
                        #debug(f"expandindo uf {uf} {dt}")
                        df2 = pd.DataFrame(
                            [dt], 
                            columns=cls
                            )
                        res_val_0 = res_val_0._append(df2)

            elif tipo == 'LFPD': 
                estados2 = ['--', 'DF','PE'] # DF e PE
                for uf in estados2:
                    pass
                    df1 = res_val.loc[(res_val['Prestadora'].str.contains('Erro') == False) & (res_val['Ano Fiscal'] == ano_) & (res_val['Tipo'] == tipo) & (res_val['UF'] == uf)]
                    df1['Origem do Arquivo'] = df1['index'].astype(str) + ' - ' + df1['Origem do Arquivo']      
                    df1['Arquivo Temporário'] = df1['index'].astype(str) + ' - ' + df1['Arquivo Temporário']   
                    df1['Resultado da Validação'] = df1['index'].astype(str) + ' - ' + df1['Resultado da Validação']                
                    debug(f"* df1: {cnpj0} {ano_} {tipo} {uf}")
                    # debug(df1)
                    
                    if len(df1.index) > 0:
                        res_val_0 = res_val_0._append(df1)
                    else:    
                        dt = [cnpj0, ano_,tipo, uf, '', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', 0]
                        #debug(f"expandindo uf {uf} {dt}")
                        df2 = pd.DataFrame(
                            [dt], 
                            columns=cls
                            )
                        res_val_0 = res_val_0._append(df2)


            else:
                    df1 = res_val.loc[(res_val['Prestadora'].str.contains('Erro') == False) & (res_val['Ano Fiscal'] == ano_) & (res_val['Tipo'] == tipo)]
                    df1['Origem do Arquivo'] = df1['index'].astype(str) + ' - ' + df1['Origem do Arquivo']  
                    df1['Arquivo Temporário'] = df1['index'].astype(str) + ' - ' + df1['Arquivo Temporário']   
                    df1['Resultado da Validação'] = df1['index'].astype(str) + ' - ' + df1['Resultado da Validação']    

                    if len(df1.index) > 0:
                        res_val_0 = res_val_0._append(df1)
                    else:    
                        dt = [cnpj0, ano_,tipo, '', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', 0]
                        #debug(f"expandindo uf {uf} {dt}")
                        df2 = pd.DataFrame(
                            [dt], 
                            columns=cls
                            )
                        res_val_0 = res_val_0._append(df2)

        res_val_r0 =  res_val_0.groupby(['Prestadora', 'Ano Fiscal', 'Tipo', 'UF', 'CNPJ']).agg({'Janeiro': [('sum')],'Jan inválidos': [('sum')], 'Fevereiro': [('sum')],'Fev inválidos': [('sum')], 'Março': [('sum')],'Mar inválidos': [('sum')], 'Abril': [('sum')],'Abr inválidos': [('sum')], 'Maio': [('sum')],'Mai inválidos': [('sum')], 'Junho': [('sum')],'Jun inválidos': [('sum')], 'Julho': [('sum')],'Jul inválidos': [('sum')], 'Agosto': [('sum')],'Ago inválidos': [('sum')], 'Setembro': [('sum')],'Set inválidos': [('sum')], 'Outubro': [('sum')],'Out inválidos': [('sum')], 'Novembro': [('sum')],'Nov inválidos': [('sum')], 'Dezembro': [('sum')],'Dez inválidos': [('sum')],'Resultado da Validação': ' \n\n'.join,'Origem do Arquivo': ' \n\n'.join,'Arquivo Temporário': '\n\n'.join,'cnt': [('sum')]}).reset_index()
        cols = ['Prestadora', 'Ano Fiscal', 'Tipo', 'UF', 'CNPJ', 'Janeiro', 'Jan inválidos', 'Fevereiro','Fev inválidos', 'Março','Mar inválidos', 'Abril','Abr inválidos', 'Maio','Mai inválidos', 'Junho','Jun inválidos', 'Julho','Jul inválidos', 'Agosto','Ago inválidos', 'Setembro','Set inválidos', 'Outubro','Out inválidos', 'Novembro','Nov inválidos', 'Dezembro','Dez inválidos', 'Resultado da Validação', 'Origem do Arquivo', 'Arquivo Temporário','cnt']
        res_val_r0.columns =  cols

        res_val_r = res_val_r0[res_val_r0['Prestadora'].str.contains('Erro') == False]
        res_val_r = res_val_r.sort_values([ 'Tipo','UF','CNPJ'], ascending=[True,True,True])
        expandida = res_val_r[['Tipo', 'UF', 'CNPJ', 'Janeiro', 'Jan inválidos', 'Fevereiro','Fev inválidos', 'Março','Mar inválidos', 'Abril','Abr inválidos', 'Maio','Mai inválidos', 'Junho','Jun inválidos', 'Julho','Jul inválidos', 'Agosto','Ago inválidos', 'Setembro','Set inválidos', 'Outubro','Out inválidos', 'Novembro','Nov inválidos', 'Dezembro','Dez inválidos', 'Resultado da Validação', 'Origem do Arquivo', 'Arquivo Temporário','cnt']]
        salva_json(f"dataframe-tabela-expandida_{pathprestok}",expandida.to_json())

        print(f"Matriz: {cnpj_} Ano: {ano_} ({prest_}) * salvou {visualizacao} expandida:")
        # print(expandida.to_string())

    elif visualizacao == 'filtrada':

        # res_val = expandida # provisóriamente sem expandir
        # res_val.reset_index(drop=True, inplace=True)
        # res_val_0 = res_val # pd.read_json(le_offline('expandida',{})) 
        # res_val_r0 =  res_val_0.groupby(['Prestadora', 'Ano Fiscal', 'Tipo', 'UF', 'CNPJ']).agg({'Janeiro': [('sum')], 'Fevereiro': [('sum')], 'Março': [('sum')], 'Abril': [('sum')], 'Maio': [('sum')], 'Junho': [('sum')], 'Julho': [('sum')], 'Agosto': [('sum')], 'Setembro': [('sum')], 'Outubro': [('sum')], 'Novembro': [('sum')], 'Dezembro': [('sum')],'Jan inválidos': [('sum')],'Fev inválidos': [('sum')],'Mar inválidos': [('sum')],'Abr inválidos': [('sum')],'Mai inválidos': [('sum')],'Jun inválidos': [('sum')],'Jul inválidos': [('sum')],'Ago inválidos': [('sum')],'Set inválidos': [('sum')],'Out inválidos': [('sum')],'Nov inválidos': [('sum')],'Dez inválidos': [('sum')],'Resultado da Validação': ' \n\n'.join,'Origem do Arquivo': ' \n\n'.join,'Arquivo Temporário': '<br<br>\n\n'.join,'cnt': [('sum')]}).reset_index()
        # cols = ['Prestadora', 'Ano Fiscal', 'Tipo', 'UF', 'CNPJ', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro', 'Jan inválidos','Fev inválidos','Mar inválidos','Abr inválidos','Mai inválidos','Jun inválidos','Jul inválidos','Ago inválidos','Set inválidos','Out inválidos','Nov inválidos','Dez inválidos', 'Resultado da Validação', 'Origem do Arquivo', 'Arquivo Temporário','cnt']
        # res_val_r0.columns =  cols
        #  res_val.loc[(res_val['Prestadora'].str.contains(cnpj_)) & (res_val['Ano Fiscal'] == int(ano_)) & (res_val['Tipo'] == tipo) & (res_val['UF'] == uf)] 
        res_val_r = expandida.loc[(expandida['cnt'] > 0)]
        filtrada = res_val_r[['Tipo', 'UF', 'CNPJ', 'Janeiro', 'Jan inválidos', 'Fevereiro','Fev inválidos', 'Março','Mar inválidos', 'Abril','Abr inválidos', 'Maio','Mai inválidos', 'Junho','Jun inválidos', 'Julho','Jul inválidos', 'Agosto','Ago inválidos', 'Setembro','Set inválidos', 'Outubro','Out inválidos', 'Novembro','Nov inválidos', 'Dezembro','Dez inválidos','cnt']]
        salva_json(f"dataframe-tabela-filtrada_{pathprestok}",filtrada.to_json())

        #print(f"Matriz: {cnpj_} Ano: {ano_} ({prest_}) * salvou {visualizacao} filtrada:")
        #print(filtrada)

    else:
        # tabela bruta
        res_val = res_brutos # provisóriamente sem expandir
        res_val.reset_index(drop=True, inplace=True)
        res_val_r = res_brutos   
        salva_json(f"dataframe-tabela-bruta_{pathprestok}",res_brutos.to_json())     
        #print(f"Matriz: {cnpj_} Ano: {ano_} ({prest_}) * salvou {visualizacao} res_brutos:")
        #print(res_brutos)
        

    ### fim expande
    ### res_val_r é mostrada
    # #  linhas = rows(res_val_r, fmt) 

    # vpath.to_csv(pasta_in + '_debug_vpath.csv', index=False)
    # res_brutos.to_csv(log_ + '/_debug_res_brutos.csv', index=True)

def agrupa_periodosxxx(cnpj,modulo,uf):

    grp = []


    # variáveis para formatar em períodos
    inicio = ""
    fim = ""
    templv = ''   
    # mes a mes válidos
    meses = []
    resv = []
    m = -1
    mini = m
    mfim = m
        # formada periodos ausentes e invalidos

    print(f"agrupando de {cnpj}, {modulo}, {uf} ")

    for mes in relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses']:

        m = m + 1
        meses.append(mes)

        if mini == -1:
            if not relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['valido']:
                mini = m
                mfim = m
                #print(f" inivazio {cnpj} {modulo} {uf} {mes} : {inicio} {fim}")

        else:        
            if not relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['valido']:
                mfim = m
                #print(f"{cnpj} {modulo} {uf} {mes} : {inicio} {fim}")
            else:
                if mfim != -1:
                    resv.append({ "inicio" : mini, "fim" : mfim, "nao-srf" : [] })  
                    mini = -1
                    mfim = -1

    if mfim != -1:
        resv.append({ "inicio" : mini, "fim" : mfim, "nao-srf" : [] })

    i = -1
    for item in resv:
        i = i + 1
        ir = item['inicio']
        fr = item['fim']
        resv[i]['inicio'] = meses[item['inicio']]
        resv[i]['fim'] = meses[item['fim']]

        print(f"procurando invalidos de {cnpj}, {modulo}, {uf} mini: {item['inicio']} mfim: {item['fim']}")

        resi = []
        iini = -1
        ifim = -1
            # formada periodos ausentes e invalidos

        for x in range(ir,fr): #for mes in relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses']:

            mes = meses[x]
            print(f"mes: {mes}")

            if iini == -1:
                if relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['recebido']:
                    iini = m
                    ifim = m
                    #print(f" inivazio {cnpj} {modulo} {uf} {mes} : {inicio} {fim}")

            else:        
                if relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['recebido']:
                    ifim = m
                    #print(f"{cnpj} {modulo} {uf} {mes} : {inicio} {fim}")
                else:
                    if ifim != -1:
                        resv[i]['nao-srf'].append([meses[iini],meses[ifim]])
                        #resi.append([iini,ifim])    
                        iini = -1
                        ifim = -1

        if iini != -1: # se foi até dezembro aós iniciar período sem registro
            resv[i]['nao-srf'].append([meses[iini],meses[ifim]])
            #resi.append([iini,ifim])
 
        #print(f"invalidos de {cnpj}, {modulo}, {uf} resi: {resi}")

    #print(f"detalhes de  {cnpj}, {modulo}, {uf} - resv:\n {resv} ")
    return resv


def agrupa_periodos(cnpj,modulo,uf,situacao,c):

    grp = []


    # variáveis para formatar em períodos
    inicio = ""
    fim = ""
    templv = ''   
    # mes a mes válidos
    meses = []
    resv = []
    m = -1
    mini = m
    mfim = m
        # formada periodos ausentes e invalidos

    print(f"agrupando de {cnpj}, {modulo}, {uf}, {situacao}, {c} ")

    for mes in relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses']:

        m = m + 1
        meses.append(mes)
        print(f"mes: {mes} {str(relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes][situacao])}")

        if mini == -1:
            if str(relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes][situacao]) == str(c):
                mini = m
                mfim = m
                #print(f" inivazio {cnpj} {modulo} {uf} {mes} : {inicio} {fim}")

        else:        
            if str(relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes][situacao]) == str(c):
                mfim = m
                #print(f"{cnpj} {modulo} {uf} {mes} : {inicio} {fim}")
            else:
                if mfim != -1:
                    resv.append({ "inicio" : mini, "fim" : mfim })  
                    mini = -1
                    mfim = -1

    if mfim != -1:
        resv.append({ "inicio" : mini, "fim" : mfim })

    # saida em meses
    i = -1
    for item in resv:
        i = i + 1
        resv[i]['inicio'] = meses[item['inicio']]
        resv[i]['fim'] = meses[item['fim']]

            #resi.append([iini,ifim])
 
        #print(f"invalidos de {cnpj}, {modulo}, {uf} resi: {resi}")

    print(f"detalhes de  {cnpj}, {modulo}, {uf} - resv:\n {resv} ")
    return resv


def relatorio_json():

    global relatorio_final

    with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
        file.write(f"\nGerando relatório json")

    relatorio_final['cnpj-matriz'] = cnpj_
    relatorio_final['ano-fiscal'] = ano_
    relatorio_final['razao-social'] = prest_
    relatorio_final['data-da-consulta'] = data_

    tmpcnt = res_brutos[res_brutos['Prestadora'].str.contains('Erro') == False]
    arqesc = len(tmpcnt.index)
    
    rel0 = res_brutos.groupby(['Prestadora', 'UF', 'CNPJ', 'Ano Fiscal'])['UF'].agg(['count'])
    rel0.reset_index( inplace = True)
    cols = ['Prestadora','UF','CNPJ', 'Ano Fiscal','contagem']
    rel0.columns =  cols
    rel0.index = rel0.index + 1
    rel1 = rel0[(rel0['Prestadora'].str.contains('Erro') == False)]
    rel = rel1[['UF','CNPJ','contagem']]

    relerr = rel0[rel0['Prestadora'].str.contains('Erro') == True]

    if errcon:
        relatorio_final['conexao-srf'] = False
    else:
        relatorio_final['conexao-srf'] = True   

            # # especifidades de expansão para cada tipo
            # if tipo == 'LFPD':
            #     estadosx = ['--', 'DF','PE']
            # elif tipo == 'ECD':
            #     estadosx = ['--']
            # elif tipo == 'ECF':
            #     estadosx = ['--']
            # else:
            #     estadosx = estados

            # relatorio_final['modulos-srf'][tipo]['ufs-avaliadas'] = estadosx
        


    if len(rel.index) < 1:
        relatorio_final['resultados-uteis'] = False
    else:
        relatorio_final['resultados-uteis'] = True
      

    if len(relerr.index) > 0:
        relatorio_final['encontrados-outros'] = True
    else:
        relatorio_final['encontrados-outros'] = False

    reltmp = {}
    reltmp['total'] = cntanon
    reltmp['uteis'] = arqesc

    relatorio_final['arquivos'] = reltmp

    ###
    ### Detalhamento do relatório descritivo a partir da tabela filtrada
    ### Esta função faz expansão ao gerar json
    ### variável "estadosx" configurável conforme tipo
    ###
    dtf = filtrada

    relatorio_final['cnpjs'] = {}
    relatorio_final['info-extra'] = {}
    relatorio_final['info-extra']['pendencias'] = {}
    relatorio_final['info-extra']['pendencias']['geral'] = False
    relatorio_final['info-extra']['pendencias']['escrituracoes'] = {}
    for modulo in relatorio_final['modulos-srf']:
        relatorio_final['info-extra']['pendencias']['escrituracoes'][modulo] = False

    relatorio_final['info-extra']['recebidos'] = {}
    relatorio_final['info-extra']['recebidos']['geral'] = False
    relatorio_final['info-extra']['recebidos']['escrituracoes'] = {}
    for modulo in relatorio_final['modulos-srf']:
        relatorio_final['info-extra']['recebidos']['escrituracoes'][modulo] = False

    # lista cnpjs do escopo e cria árvore com variáveis auxiliares
    n = 0
    # testa se existe resultado no escopo
    if arqesc > 0:
 
        res1 = dtf.groupby(['CNPJ'])['CNPJ'].agg(['count']) # ['Prestadora', 'UF', 'CNPJ', 'Ano Fiscal']
        res1.sort_values(['CNPJ'], ascending=[True])
        res1.reset_index( inplace = True)

        # colocando matrix no início
        relatorio_final['cnpjs'][cnpj_] = {}
        
        for index0, row0 in res1.iterrows():

            cnpjf = row0['CNPJ']
            relatorio_final['cnpjs'][cnpjf] = {}

            if cnpjf == cnpj_:
                # matrix
                relatorio_final['cnpjs'][cnpjf]['tipo'] = "Matriz" 
            else:
                # filiais  
                n = n + 1 
                relatorio_final['cnpjs'][cnpjf]['tipo'] = f"Filial {n}" 
        
            #relatorio_final['cnpjs'][cnpjf]['ufs'] = {}
            relatorio_final['cnpjs'][cnpjf]['status'] = {}
            relatorio_final['cnpjs'][cnpjf]['status']['recebido'] = False
            relatorio_final['cnpjs'][cnpjf]['status']['recebido-completo'] = {}
            relatorio_final['cnpjs'][cnpjf]['status']['recebido-valido'] = False
            relatorio_final['cnpjs'][cnpjf]['status']['recebido-invalido'] = False
            relatorio_final['cnpjs'][cnpjf]['status']['valido-completo'] = {}
            relatorio_final['cnpjs'][cnpjf]['status']['ufs'] = {}
            relatorio_final['cnpjs'][cnpjf]['escrituracoes'] = {}

            for modulo in relatorio_final['modulos-srf']:

                relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo] = {}
                relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['status'] = {}
                relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['status']['recebido'] = False
                relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['status']['recebido-completo'] = {}
                relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['status']['recebido-valido'] = False
                relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['status']['recebido-invalido'] = False
                relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['status']['valido-completo'] = {}

                relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'] = {}

                for uf in relatorio_final['modulos-srf'][modulo]['ufs-avaliadas']:

                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf] = {}
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status'] = {}
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido'] = False
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-completo'] = {}
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-valido'] = False
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-invalido'] = False
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = {}
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-recebidos'] = []
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-ausentes'] = []
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-invalidos'] = []
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-validos'] = []
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-pendentes'] = []
                    relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['meses'] = {}

                    for mes in meses:

                        relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes.lower()] = {}
                        relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes.lower()]['recebido'] = {}
                        relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes.lower()]['valido'] = {}
                        relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes.lower()]['invalido'] = {}
            
            # lista ufs por cnpj     

            res2 = dtf.loc[(dtf['CNPJ'] == cnpjf)]
            res3 = res2.groupby(['UF', 'CNPJ'])['UF'].agg(['count']) 
            res3.reset_index( inplace = True)
            ufs = []
            for index, row in res3.iterrows():
                ufs.append(row['UF'])             
             
            relatorio_final['cnpjs'][cnpjf]['status']['ufs'] = ufs



    # # lista ufs por cnpj
    
    # if arqesc > 0:
    #     reltmp = {}
    #     #matriz
    #     ufs = []
    #     res2 = dtf.loc[(dtf['CNPJ'] == cnpj_)]
    #     res3 =  res2.groupby(['UF', 'CNPJ'])['UF'].agg(['count']) 
    #     res3.reset_index( inplace = True)
    #     for index, row in res3.iterrows():
    #         ufs.append(row['UF'])

    #     reltmp[cnpj_] = {}
    #     reltmp[cnpj_]['tipo'] = {}
    #     reltmp[cnpj_]['ufs-encontradas'] = ufs

    #     res1 = dtf.groupby(['CNPJ'])['CNPJ'].agg(['count']) # ['Prestadora', 'UF', 'CNPJ', 'Ano Fiscal']
    #     res1.sort_values(['CNPJ'], ascending=[True])
    #     res1.reset_index( inplace = True)
    #     # outros
    #     for index0, row0 in res1.iterrows():
    #         ufs = []
    #         cnpjf = row0['CNPJ']
    #         if cnpjf != cnpj_:
    #             res2 = dtf.loc[(dtf['CNPJ'] == cnpjf)]
    #             res3 = res2.groupby(['UF', 'CNPJ'])['UF'].agg(['count']) 
    #             res3.reset_index( inplace = True)
    #             for index, row in res3.iterrows():
    #                 ufs.append(row['UF'])

    #             reltmp[cnpjf] = {}   
    #             reltmp[cnpjf]['tipo'] = {}    
    #             reltmp[cnpjf]['ufs-encontradas'] = ufs     

        #relatorio_final['cnpjs'] = reltmp

    # else:
    #     relatorio_final['cnpjs'] = {}
    #     relatorio_final['cnpjs']['status'] = {}


    # mes incompleto
    
    mi = []
    resmi = res_brutos.loc[(res_brutos['Prestadora'].str.contains('Erro') == False) & (( (res_brutos['Jan inválidos'] < 1) & (res_brutos['Jan inválidos'] > 0) ) | ( (res_brutos['Fev inválidos'] < 1) & (res_brutos['Fev inválidos'] > 0) ) | ( (res_brutos['Mar inválidos'] < 1) & (res_brutos['Mar inválidos'] > 0) ) | ( (res_brutos['Abr inválidos'] < 1) & (res_brutos['Abr inválidos'] > 0) ) | ( (res_brutos['Mai inválidos'] < 1) & (res_brutos['Mai inválidos'] > 0) ) | ( (res_brutos['Jun inválidos'] < 1) & (res_brutos['Jun inválidos'] > 0) ) | ( (res_brutos['Jul inválidos'] < 1) & (res_brutos['Jul inválidos'] > 0) ) | ( (res_brutos['Ago inválidos'] < 1) & (res_brutos['Ago inválidos'] > 0) ) | ( (res_brutos['Set inválidos'] < 1) & (res_brutos['Set inválidos'] > 0) ) | ( (res_brutos['Out inválidos'] < 1) & (res_brutos['Out inválidos'] > 0) ) | ( (res_brutos['Nov inválidos'] < 1) & ( (res_brutos['Nov inválidos'] > 0) ) | ( (res_brutos['Dez inválidos'] < 1) & (res_brutos['Dez inválidos'] > 0) ))) ]
    resmi.reset_index( inplace = True)
    for index, row in resmi.iterrows():
        mi.append(row['Origem do Arquivo'])

    relatorio_final['mes-incompleto'] = mi


    # sem assinatura
    
    sa = []
    ressa = res_brutos.loc[(res_brutos['Prestadora'].str.contains('Erro') == False) & (res_brutos['Resultado da Validação'].str.contains('sem assinatura') == True)]   
    ressa.reset_index( inplace = True)
    for index, row in ressa.iterrows():
        sa.append(row['Origem do Arquivo'])

    relatorio_final['sem-assinatura'] = sa

    # outros anos
    oa = []
    resec = res_brutos.loc[(res_brutos['Prestadora'].str.contains('ano fiscal divergente') == True)]   
    resec.reset_index( inplace = True)
    for index, row in resec.iterrows():
        oa.append(row['Origem do Arquivo'])

    relatorio_final['outros-anos-fiscais'] = oa

    # outros cnpjs
    oc = []
    resec = res_brutos.loc[(res_brutos['Prestadora'].str.contains('cnpj divergente') == True)]   
    resec.reset_index( inplace = True)
    for index, row in resec.iterrows():
        oc.append(row['Origem do Arquivo'])

    relatorio_final['outros-cnpjs'] = oc


    # diversos
    resdiv = res_brutos.loc[(res_brutos['Prestadora'].str.contains('não tratado ou desconhecido') == True)] 
    resdiv.reset_index( inplace = True)
    relatorio_final['outros-diversos'] = len(resdiv.index)

######################################################

    # preenche todos campos para cada cnpj

    for cnpj in relatorio_final['cnpjs']:

        for modulo in relatorio_final['modulos-srf']:

            for uf in relatorio_final['modulos-srf'][modulo]['ufs-avaliadas']:

                # # dtf = filtrada
                # res = dtf.loc[(dtf['Tipo'] == modulo)& (dtf['UF'] == uf) & (dtf['CNPJ'] == cnpj)]


                # # se ano completo e válidado
                # res = dtf.loc[(dtf['CNPJ'] == cnpj) & (dtf['Tipo'] == modulo) & (dtf['UF'] == uf) & ((dtf['Janeiro'] != 0) & (dtf['Fevereiro'] != 0) & (dtf['Março'] != 0) & (dtf['Abril'] != 0) & (dtf['Maio'] != 0) & (dtf['Junho'] != 0) & (dtf['Julho'] != 0) & (dtf['Agosto'] != 0) & (dtf['Setembro'] != 0) & (dtf['Outubro'] != 0) & (dtf['Novembro'] != 0) & (dtf['Dezembro'] != 0)) ]

                # if len(res.index) > 0:
                #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = True
                    
                # else:
                #     relatorio_final['cnpjs'][cnpj]['status']['valido-completo'] = False
                #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['valido-completo'] = False
                #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = False
                 


                # # se enviaram ano completo ainda que contendo invalidos
                # res = dtf.loc[(dtf['CNPJ'] == cnpj) & (dtf['Tipo'] == modulo) & (dtf['UF'] == uf) &  (  ((dtf['Janeiro'] != 0) | (dtf['Jan inválidos'] != 0 )) & ((dtf['Fevereiro'] != 0) | (dtf['Fev inválidos'] != 0 )) & ((dtf['Março'] != 0) | (dtf['Mar inválidos'] != 0 )) & ((dtf['Abril'] != 0) | (dtf['Abr inválidos'] != 0 )) & ((dtf['Maio'] != 0) | (dtf['Mai inválidos'] != 0 )) & ((dtf['Junho'] != 0) | (dtf['Jun inválidos'] != 0 )) & ((dtf['Julho'] != 0) | (dtf['Jul inválidos'] != 0 )) & ((dtf['Agosto'] != 0) | (dtf['Ago inválidos'] != 0 )) & ((dtf['Setembro'] != 0) | (dtf['Set inválidos'] != 0 )) & ((dtf['Outubro'] != 0) | (dtf['Out inválidos'] != 0 )) & ((dtf['Novembro'] != 0) | (dtf['Nov inválidos'] != 0 )) & ((dtf['Dezembro'] != 0) | (dtf['Dez inválidos'] != 0 )) ) ]      


                # if len(res.index) > 0:
                #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-completo'] = True
                    
                # else:
                #     relatorio_final['cnpjs'][cnpj]['status']['recebido-completo'] = False
                #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['recebido-completo'] = False
                #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-completo'] = False


                res = dtf.loc[(dtf['Tipo'] == modulo)& (dtf['UF'] == uf) & (dtf['CNPJ'] == cnpj)]

                # # variáveis para formatar em períodos
                # templr = ""
                # rini = ""
                # rfim = ""
                # inicio = ""
                # fim = ""
                # templv = ''   
                # mini = -1
                # mfim = -1

                # # mes a mes válidos
                m = -1
                for mes in relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses']:


                    if len(res.index) > 0: 

                        m = m + 1

                        # recebidos
                        if ( res[meserr[m]].iloc[0] > 0 ) | ( res[mes.title()].iloc[0] > 0 ):
                            relatorio_final['info-extra']['recebidos']['geral'] = True
                            relatorio_final['info-extra']['recebidos']['escrituracoes'][modulo] = True  
                            relatorio_final['cnpjs'][cnpj]['status']['recebido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['recebido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['recebido'] = True
                        else:               
                            relatorio_final['cnpjs'][cnpj]['status']['recebido-completo'] = False
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['recebido-completo'] = False
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-completo'] = False
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['recebido'] = False
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['invalido'] = False


                        # validos
                        if res[mes.title()].iloc[0] > 0:
                            relatorio_final['cnpjs'][cnpj]['status']['recebido-valido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['recebido-valido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-valido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['valido'] = True
                        else:    
                            relatorio_final['info-extra']['pendencias']['geral'] = True   
                            relatorio_final['info-extra']['pendencias']['escrituracoes'][modulo] = True            
                            relatorio_final['cnpjs'][cnpj]['status']['valido-completo'] = False
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['valido-completo'] = False
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = False
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['valido'] = False



                        # invalidos
                        if res[meserr[m]].iloc[0] > 0:
                            relatorio_final['cnpjs'][cnpj]['status']['recebido-invalido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['recebido-invalido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-invalido'] = True
                            relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['invalido'] = True
                        # else:    
                        #     relatorio_final['info-extra']['pendencias']['geral'] = True   
                        #     relatorio_final['info-extra']['pendencias']['escrituracoes'][modulo] = True            
                        #     relatorio_final['cnpjs'][cnpj]['status']['valido-completo'] = False
                        #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['valido-completo'] = False
                        #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = False
                        #     relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['valido'] = False



                    else:

                        relatorio_final['info-extra']['pendencias']['geral'] = True
                        relatorio_final['info-extra']['pendencias']['escrituracoes'][modulo] = True

                        relatorio_final['cnpjs'][cnpj]['status']['recebido-completo'] = False
                        relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['recebido-completo'] = False
                        relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['recebido-completo'] = False
                        relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['recebido'] = False

                        relatorio_final['cnpjs'][cnpj]['status']['valido-completo'] = False
                        relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['status']['valido-completo'] = False
                        relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = False
                        relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['meses'][mes]['valido'] = False

                
                # organiza em periodos
                relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-recebidos'] = agrupa_periodos(cnpj,modulo,uf,'recebido',True) 
                relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-ausentes'] =  agrupa_periodos(cnpj,modulo,uf,'recebido',False) 
                relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-invalidos'] =  agrupa_periodos(cnpj,modulo,uf,'invalido',True) 
                relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-pendentes'] =  agrupa_periodos(cnpj,modulo,uf,'valido',False) 
                relatorio_final['cnpjs'][cnpj]['escrituracoes'][modulo]['ufs'][uf]['status']['periodos-validos'] =  agrupa_periodos(cnpj,modulo,uf,'valido',True) 


    

######################################################
######################################################333

    # cnpjs = relatorio_final['cnpjs']


    # relatorio_final['escrituracoes'] = {}
        
    # filiais = {}
    # n = 0
    # txt = 'Matriz' # demais redefinidos no loop
    # for cnpj00 in cnpjs: # cada cnpj, existe pelo menos 1

    #     relatorio_final['cnpjs'][cnpj00]['tipo'] = txt

    # #######################################################3

    #     #relatorio_final['escrituracoes'][cnpj00] = {}
    #     relatorio_final['escrituracoes'][cnpj00] = {}
        
    #     for tipo in tipos: # verifica em separado para cada classificação por tipo reconhecido

    #         relatorio_final['escrituracoes'][cnpj00][tipo] = {}
    #         relatorio_final['escrituracoes'][cnpj00][tipo]['_'] = {}
    #         #res = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['Janeiro'] != 0) & (dtf['Fevereiro'] != 0) & (dtf['Março'] != 0) & (dtf['Abril'] != 0) & (dtf['Maio'] != 0) & (dtf['Junho'] != 0) & (dtf['Julho'] != 0) & (dtf['Agosto'] != 0) & (dtf['Setembro'] != 0) & (dtf['Outubro'] != 0) & (dtf['Novembro'] != 0) & (dtf['Dezembro'] != 0) ]

    #         # especifidades de expansão para cada tipo
    #         estadosx = relatorio_final['modulos-srf'][tipo]['ufs-avaliadas']

    #         # verificando a situação geral dos estados   
    #         resuf0 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['CNPJ'] == cnpj00)]             
    #         resuf = resuf0.groupby(['UF'])['UF'].agg(['count'])
    #         resuf.reset_index( inplace = True)  
    #         nuf = len(resuf.index)
    #         print(f"tipo: {tipo} nuf: {nuf} resuf:\n{resuf}")
    #         if nuf < 1:
    #             # relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = {}
    #             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['status']['recebido-valido'] = False  
    #             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['status']['recebido-completo'] = False  
    #             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['status']['valido-completo'] = False  
    #             relatorio_final['escrituracoes'][cnpj00][tipo]['_']['recebido-valido'] = False  
    #             relatorio_final['escrituracoes'][cnpj00][tipo]['_']['valido-completo'] = False 
    #         # elif nuf == len(estadosx):
    #         #     relatorio_final[cnpj00][tipo]['informacoes'] = True  
    #         else:
    #             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['status']['recebido-valido'] = True  
    #             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['status']['recebido-completo'] = True  
    #             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['status']['valido-completo'] = True  
    #             relatorio_final['escrituracoes'][cnpj00][tipo]['_']['recebido-valido'] = True
    #             relatorio_final['escrituracoes'][cnpj00][tipo]['_']['valido-completo'] = True 
                
    #             ufuteis = []
    #             ufnuteis = []
                
    #             for ufx in estadosx:   

    #                 relatorio_final['escrituracoes'][cnpj00][tipo][ufx] = {}
    #                 relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_'] = {}
    #                 # verificar aqui quais uf para o tipo
    #                 res0 = dtf.loc[(dtf['Tipo'] == tipo)& (dtf['UF'] == ufx) & (dtf['CNPJ'] == cnpj00)]


    #                 #verificar aqui quais cnpjs recebidos (validados ou não)
    #                 ncnpjs = 0
    #                 if len(res0.index) > 0:
    #             # relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = {}
    #                     relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['recebido-valido'] = True
    #                     relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['recebido-completo'] = True
    #                     relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['valido-completo'] = True
    #                     relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['recebido-valido'] = True  
    #                     relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['valido-completo'] = True
    #                     res1 = res0.groupby(['CNPJ'])['CNPJ'].agg(['count'])
    #                     res1.reset_index( inplace = True)
    #                     ncnpj = len(res1.index)
    #                 else:
    #                     relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['recebido-valido'] = False
    #                     relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['recebido-completo'] = False
    #                     relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['valido-completo'] = False
    #                     relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['recebido-valido'] = False  
    #                     relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['valido-completo'] = False
    #                     ncnpj = 0

    #                 #print(f"*** tipo {tipo} uf {ufx} len ufs {len(res0.index)}  len cnpjs {ncnpj}")

    
    #                 if ncnpj == 0:
    #                     ufnuteis.append(ufx)
    #                     #relatorio_final[cnpj00][tipo][ufx]['uteis'] = False 
    #                 else:
    #                     #relatorio_final[cnpj00][tipo][ufx]['uteis'] = True 

    #                     #relatorio_final['escrituracoes'][cnpj00][tipo][ufx] = {} 

    #                     if ncnpj > 1:
    #                         ufuteis.append(ufx)
    #                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['mais-de-um-cnpj'] = True 
    #                     else:
    #                         ufuteis.append(ufx)
    #                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['mais-de-um-cnpj'] = False 

    #                     relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['cnpjs'] =  ncnpj 

    #                     # obtém cada cnpj (validado ou não)
    #                     for index, row in res1.iterrows():
    #                         cnpjx = row['CNPJ'] 
    #             # relatorio_final['cnpjs'][cnpjf]['escrituracoes'][modulo]['ufs'][uf]['status']['valido-completo'] = {}
    #                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx] = {}
    #                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['_'] = {}
    #                         relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['recebido-valido'] = True
    #                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['_']['recebido-valido'] = True

    #                         # se recebido ano completo (validado ou não)
    #                         resrecebido = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == ufx) & (dtf['CNPJ'] == cnpjx) & (((dtf['Janeiro'] != 0) | (dtf['Jan inválidos'] != 0 )) & ((dtf['Fevereiro'] != 0) | (dtf['Fev inválidos'] != 0 )) & ((dtf['Março'] != 0) | (dtf['Mar inválidos'] != 0 )) & ((dtf['Abril'] != 0) | (dtf['Abr inválidos'] != 0 )) & ((dtf['Maio'] != 0) | (dtf['Mai inválidos'] != 0 )) & ((dtf['Junho'] != 0) | (dtf['Jun inválidos'] != 0 )) & ((dtf['Julho'] != 0) | (dtf['Jul inválidos'] != 0 )) & ((dtf['Agosto'] != 0) | (dtf['Ago inválidos'] != 0 )) & ((dtf['Setembro'] != 0) | (dtf['Set inválidos'] != 0 )) & ((dtf['Outubro'] != 0) | (dtf['Out inválidos'] != 0 )) & ((dtf['Novembro'] != 0) | (dtf['Nov inválidos'] != 0 )) & ((dtf['Dezembro'] != 0) | (dtf['Dez inválidos'] != 0 )) )]

    #                         if len(res3.index) > 0:

    #                             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['recebido-completo'] = True
    #                             relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['_']['recebido-completo'] = True
                                
    #                         else:
    #                             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['recebido-completo'] = False
    #                             relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['_']['recebido-completo'] = False


    #                             # ao menos 1 mes completo (validado ou não)
    #                             resrecebido4 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == ufx) &  (  ((dtf['Janeiro'] != 0) | (dtf['Jan inválidos'] != 0 )) | ((dtf['Fevereiro'] != 0) | (dtf['Fev inválidos'] != 0 )) | ((dtf['Março'] != 0) | (dtf['Mar inválidos'] != 0 )) | ((dtf['Abril'] != 0) | (dtf['Abr inválidos'] != 0 )) | ((dtf['Maio'] != 0) | (dtf['Mai inválidos'] != 0 )) | ((dtf['Junho'] != 0) | (dtf['Jun inválidos'] != 0 )) | ((dtf['Julho'] != 0) | (dtf['Jul inválidos'] != 0 )) | ((dtf['Agosto'] != 0) | (dtf['Ago inválidos'] != 0 )) | ((dtf['Setembro'] != 0) | (dtf['Set inválidos'] != 0 )) | ((dtf['Outubro'] != 0) | (dtf['Out inválidos'] != 0 )) | ((dtf['Novembro'] != 0) | (dtf['Nov inválidos'] != 0 )) | ((dtf['Dezembro'] != 0) | (dtf['Dez inválidos'] != 0 )) ) ]      

    #                             recebidos = []
    #                             nrecebidos = []
    #                             try: # verificar
    #                                 for mes in meses:
    #                                     if resrecebido4[mes].iloc[0] > 0:
    #                                         recebidos.append(mes.lower())
    #                                     else:
    #                                         nrecebidos.append(mes.lower()) 
    #                                         relatorio_final['cnpjs'][cnpj00]['status']['recebido-completo'] = False
    #                                         relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['status']['recebido-completo'] = False
    #                                         relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['recebido-completo'] = False
    #                                         relatorio_final['escrituracoes'][cnpj00][tipo]['_']['recebido-completo'] = False 
    #                                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['recebido-completo'] = False
    #                                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['_']['recebido-completo'] = False
    #                             except:
    #                                 nrecebidos.append(mes.lower())  

    #                             relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['recebidos'] = recebidos    
    #                             relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['nao-recebidos'] = nrecebidos  

    #                         # se ano completo e válidado
    #                         res3 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == ufx) & (dtf['CNPJ'] == cnpjx) & ((dtf['Janeiro'] != 0) & (dtf['Fevereiro'] != 0) & (dtf['Março'] != 0) & (dtf['Abril'] != 0) & (dtf['Maio'] != 0) & (dtf['Junho'] != 0) & (dtf['Julho'] != 0) & (dtf['Agosto'] != 0) & (dtf['Setembro'] != 0) & (dtf['Outubro'] != 0) & (dtf['Novembro'] != 0) & (dtf['Dezembro'] != 0)) ]


    #                         if len(res3.index) > 0:
    #                             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['valido-completo'] = True
    #                             relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['_']['valido-completo'] = True
                                
    #                         else:
    #                             relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['valido-completo'] = False
    #                             relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['_']['valido-completo'] = False
                                
    #                             # ao menos 1 mes validado
    #                             res4 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == ufx) & ((dtf['Janeiro'] != 0) | (dtf['Fevereiro'] != 0) | (dtf['Março'] != 0) | (dtf['Abril'] != 0) | (dtf['Maio'] != 0) | (dtf['Junho'] != 0) | (dtf['Julho'] != 0) | (dtf['Agosto'] != 0) | (dtf['Setembro'] != 0) | (dtf['Outubro'] != 0) | (dtf['Novembro'] != 0) | (dtf['Dezembro'] != 0)) ]      

    #                             confirmados = []
    #                             descartados = []
    #                             try: # verificar
    #                                 for mes in meses:
    #                                     if res4[mes].iloc[0] > 0:
    #                                         confirmados.append(mes.lower())
    #                                         descartados.append('')
    #                                     else:
    #                                         confirmados.append('')
    #                                         descartados.append(mes.lower())  
    #                                         relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['valido-completo'] = False
    #                                         relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['valido-completo'] = False
    #                                         relatorio_final['cnpjs'][cnpj00]['escrituracoes'][tipo]['ufs'][ufx]['status']['valido-completo'] = False
    #                                         relatorio_final['escrituracoes'][cnpj00][tipo]['_']['valido-completo'] = False 
    #                                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['_']['valido-completo'] = False
    #                                         relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['_']['valido-completo'] = False
    #                             except:
    #                                 descartados.append(mes.lower())  

    #                             relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['confirmados'] = confirmados    
    #                             relatorio_final['escrituracoes'][cnpj00][tipo][ufx][cnpjx]['descartados'] = descartados  

    #                         # if cnpjcompl:
    #                         #     relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['cnpjs-completos'][cnpjx] = cnpjsx
    #                         # else:    
    #                         #     relatorio_final['escrituracoes'][cnpj00][tipo][ufx]['cnpjs-incompletos'][cnpjx] = cnpjsx 

    #             #  
    #             relatorio_final['escrituracoes'][cnpj00][tipo]['ufs-presentes'] = ufuteis    
    #             relatorio_final['escrituracoes'][cnpj00][tipo]['ufs-ausentes'] = ufnuteis       

    # ##################################################




    #     n = n + 1
    #     txt = f"Filial {n}"

#######################################################3

    # #relatorio_final['escrituracoes'] = {}
    # relatorio_final['escrituracoes'] = {}
    # for tipo in tipos: # verifica em separado para cada classificação por tipo reconhecido
    #     relatorio_final['escrituracoes'][tipo] = {}
    #     relatorio_final['escrituracoes'][tipo]['_'] = {}
    #     #res = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['Janeiro'] != 0) & (dtf['Fevereiro'] != 0) & (dtf['Março'] != 0) & (dtf['Abril'] != 0) & (dtf['Maio'] != 0) & (dtf['Junho'] != 0) & (dtf['Julho'] != 0) & (dtf['Agosto'] != 0) & (dtf['Setembro'] != 0) & (dtf['Outubro'] != 0) & (dtf['Novembro'] != 0) & (dtf['Dezembro'] != 0) ]

    #     # especifidades de expansão para cada tipo
    #     if tipo == 'LFPD':
    #         estadosx = ['--', 'DF','PE']
    #     elif tipo == 'ECD':
    #         estadosx = ['--']
    #     elif tipo == 'ECF':
    #         estadosx = ['--']
    #     else:
    #         estadosx = estados

    #     # verificando a situação geral dos estados   
    #     resuf0 = dtf.loc[(dtf['Tipo'] == tipo)]             
    #     resuf = resuf0.groupby(['UF'])['UF'].agg(['count'])
    #     resuf.reset_index( inplace = True)  
    #     nuf = len(resuf.index)
    #     print(f"tipo: {tipo} nuf: {nuf} resuf:\n{resuf}")
    #     if nuf < 1:
    #         relatorio_final['escrituracoes'][tipo]['_']['recebido-valido'] = False  
    #         relatorio_final['escrituracoes'][tipo]['_']['valido-completo'] = False 
    #     # elif nuf == len(estadosx):
    #     #     relatorio_final[tipo]['informacoes'] = True  
    #     else:
    #         relatorio_final['escrituracoes'][tipo]['_']['recebido-valido'] = True
    #         relatorio_final['escrituracoes'][tipo]['_']['valido-completo'] = True 
            
    #         ufuteis = []
    #         ufnuteis = []
            
    #         for ufx in estadosx:   

    #             relatorio_final['escrituracoes'][tipo][ufx] = {}
    #             relatorio_final['escrituracoes'][tipo][ufx]['_'] = {}
    #             # verificar aqui quais uf para o tipo
    #             res0 = dtf.loc[(dtf['Tipo'] == tipo)& (dtf['UF'] == ufx)]


    #             #verificar aqui quais cnpjs recebidos (validados ou não)
    #             ncnpjs = 0
    #             if len(res0.index) > 0:
    #                 relatorio_final['escrituracoes'][tipo][ufx]['_']['recebido-valido'] = True  
    #                 relatorio_final['escrituracoes'][tipo][ufx]['_']['valido-completo'] = True
    #                 res1 = res0.groupby(['CNPJ'])['CNPJ'].agg(['count'])
    #                 res1.reset_index( inplace = True)
    #                 ncnpj = len(res1.index)
    #             else:
    #                 relatorio_final['escrituracoes'][tipo][ufx]['_']['recebido-valido'] = False  
    #                 relatorio_final['escrituracoes'][tipo][ufx]['_']['valido-completo'] = False
    #                 ncnpj = 0

    #             #print(f"*** tipo {tipo} uf {ufx} len ufs {len(res0.index)}  len cnpjs {ncnpj}")

  
    #             if ncnpj == 0:
    #                 ufnuteis.append(ufx)
    #                 #relatorio_final[tipo][ufx]['uteis'] = False 
    #             else:
    #                 #relatorio_final[tipo][ufx]['uteis'] = True 

    #                 #relatorio_final['escrituracoes'][tipo][ufx] = {} 

    #                 if ncnpj > 1:
    #                     ufuteis.append(ufx)
    #                     relatorio_final['escrituracoes'][tipo][ufx]['_']['mais-de-um-cnpj'] = True 
    #                 else:
    #                     ufuteis.append(ufx)
    #                     relatorio_final['escrituracoes'][tipo][ufx]['_']['mais-de-um-cnpj'] = False 

    #                 relatorio_final['escrituracoes'][tipo][ufx]['_']['cnpjs'] =  ncnpj 

    #                 # obtém cada cnpj (validado ou não)
    #                 for index, row in res1.iterrows():
    #                     cnpjx = row['CNPJ'] 
    #                     relatorio_final['escrituracoes'][tipo][ufx][cnpjx] = {}
    #                     relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['_'] = {}
    #                     relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['_']['recebido-valido'] = True

    #                     # se recebido ano completo (validado ou não)
    #                     resrecebido = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == ufx) & (dtf['CNPJ'] == cnpjx) & (((dtf['Janeiro'] != 0) | (dtf['Jan inválidos'] != 0 )) & ((dtf['Fevereiro'] != 0) | (dtf['Fev inválidos'] != 0 )) & ((dtf['Março'] != 0) | (dtf['Mar inválidos'] != 0 )) & ((dtf['Abril'] != 0) | (dtf['Abr inválidos'] != 0 )) & ((dtf['Maio'] != 0) | (dtf['Mai inválidos'] != 0 )) & ((dtf['Junho'] != 0) | (dtf['Jun inválidos'] != 0 )) & ((dtf['Julho'] != 0) | (dtf['Jul inválidos'] != 0 )) & ((dtf['Agosto'] != 0) | (dtf['Ago inválidos'] != 0 )) & ((dtf['Setembro'] != 0) | (dtf['Set inválidos'] != 0 )) & ((dtf['Outubro'] != 0) | (dtf['Out inválidos'] != 0 )) & ((dtf['Novembro'] != 0) | (dtf['Nov inválidos'] != 0 )) & ((dtf['Dezembro'] != 0) | (dtf['Dez inválidos'] != 0 )) )]

    #                     if len(res3.index) > 0:
    #                         relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['_']['recebido-completo'] = True
                            
    #                     else:
    #                         relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['_']['recebido-completo'] = False


    #                         # ao menos 1 mes completo (validado ou não)
    #                         resrecebido4 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == ufx) &  (  ((dtf['Janeiro'] != 0) | (dtf['Jan inválidos'] != 0 )) | ((dtf['Fevereiro'] != 0) | (dtf['Fev inválidos'] != 0 )) | ((dtf['Março'] != 0) | (dtf['Mar inválidos'] != 0 )) | ((dtf['Abril'] != 0) | (dtf['Abr inválidos'] != 0 )) | ((dtf['Maio'] != 0) | (dtf['Mai inválidos'] != 0 )) | ((dtf['Junho'] != 0) | (dtf['Jun inválidos'] != 0 )) | ((dtf['Julho'] != 0) | (dtf['Jul inválidos'] != 0 )) | ((dtf['Agosto'] != 0) | (dtf['Ago inválidos'] != 0 )) | ((dtf['Setembro'] != 0) | (dtf['Set inválidos'] != 0 )) | ((dtf['Outubro'] != 0) | (dtf['Out inválidos'] != 0 )) | ((dtf['Novembro'] != 0) | (dtf['Nov inválidos'] != 0 )) | ((dtf['Dezembro'] != 0) | (dtf['Dez inválidos'] != 0 )) ) ]      

    #                         recebidos = []
    #                         nrecebidos = []
    #                         try: # verificar
    #                             for mes in meses:
    #                                 if resrecebido4[mes].iloc[0] > 0:
    #                                     recebidos.append(mes.lower())
    #                                 else:
    #                                     nrecebidos.append(mes.lower())  
    #                                     relatorio_final['escrituracoes'][tipo]['_']['recebido-completo'] = False 
    #                                     relatorio_final['escrituracoes'][tipo][ufx]['_']['recebido-completo'] = False
    #                                     relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['_']['recebido-completo'] = False
    #                         except:
    #                             nrecebidos.append(mes.lower())  

    #                         relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['recebidos'] = recebidos    
    #                         relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['nao-recebidos'] = nrecebidos  

    #                     # se ano completo e válidado
    #                     res3 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == ufx) & (dtf['CNPJ'] == cnpjx) & ((dtf['Janeiro'] != 0) & (dtf['Fevereiro'] != 0) & (dtf['Março'] != 0) & (dtf['Abril'] != 0) & (dtf['Maio'] != 0) & (dtf['Junho'] != 0) & (dtf['Julho'] != 0) & (dtf['Agosto'] != 0) & (dtf['Setembro'] != 0) & (dtf['Outubro'] != 0) & (dtf['Novembro'] != 0) & (dtf['Dezembro'] != 0)) ]


    #                     if len(res3.index) > 0:
    #                         relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['_']['valido-completo'] = True
                            
    #                     else:
    #                         relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['_']['valido-completo'] = False
                            
    #                         # ao menos 1 mes validado
    #                         res4 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == ufx) & ((dtf['Janeiro'] != 0) | (dtf['Fevereiro'] != 0) | (dtf['Março'] != 0) | (dtf['Abril'] != 0) | (dtf['Maio'] != 0) | (dtf['Junho'] != 0) | (dtf['Julho'] != 0) | (dtf['Agosto'] != 0) | (dtf['Setembro'] != 0) | (dtf['Outubro'] != 0) | (dtf['Novembro'] != 0) | (dtf['Dezembro'] != 0)) ]      

    #                         confirmados = []
    #                         descartados = []
    #                         try: # verificar
    #                             for mes in meses:
    #                                 if res4[mes].iloc[0] > 0:
    #                                     confirmados.append(mes.lower())
    #                                     descartados.append('')
    #                                 else:
    #                                     confirmados.append('')
    #                                     descartados.append(mes.lower())  
    #                                     relatorio_final['escrituracoes'][tipo]['_']['valido-completo'] = False 
    #                                     relatorio_final['escrituracoes'][tipo][ufx]['_']['valido-completo'] = False
    #                                     relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['_']['valido-completo'] = False
    #                         except:
    #                             descartados.append(mes.lower())  

    #                         relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['confirmados'] = confirmados    
    #                         relatorio_final['escrituracoes'][tipo][ufx][cnpjx]['descartados'] = descartados  

    #                     # if cnpjcompl:
    #                     #     relatorio_final['escrituracoes'][tipo][ufx]['cnpjs-completos'][cnpjx] = cnpjsx
    #                     # else:    
    #                     #     relatorio_final['escrituracoes'][tipo][ufx]['cnpjs-incompletos'][cnpjx] = cnpjsx 

    #         #  
    #         relatorio_final['escrituracoes'][tipo]['ufs-presentes'] = ufuteis    
    #         relatorio_final['escrituracoes'][tipo]['ufs-ausentes'] = ufnuteis       

##################################################

    #relatorio_final['escrituracoes'] = reltmp
    salva_json(f"{relpre}{pathprestok}",json.dumps(relatorio_final))

    salva_json(f"ultimo_relatorio",json.dumps(relatorio_final))


def tblcnpjs():

    templ = ''

    if len(relatorio_final['cnpjs']) > 0:
        pass

        templ += '''
<p class="Item_Nivel2">Na documentação enviada foram encontradas escriturações referentes ao(s) seguinte(s) CNPJ(s):</p>

<table border="1" style="border-collapse:collapse;color:#000000;font-family:&quot;Times New Roman&quot;;font-size:medium;font-style:normal;font-variant-ligatures:normal;font-weight:400;margin-left:auto;margin-right:auto;text-align:start;text-decoration-color:initial;text-decoration-style:initial;text-decoration-thickness:initial;white-space:normal;width:90%;">
    <thead>
        <tr>
            <th scope="col" style="background-color:#eeeeee; width:839px">
            <p class="Tabela_Texto_Centralizado">Denominação/Razão Social&nbsp;</p>
            </th>
            <th scope="col" style="background-color:#eeeeee; width:976px">
            <p class="Tabela_Texto_Centralizado">CNPJ</p>
            </th>
            <th scope="col" style="background-color:#eeeeee; width:976px">
            <p class="Tabela_Texto_Centralizado">UFs</p>
            </th>
        </tr>
        '''

        for cnpj in relatorio_final['cnpjs']:
            
            ufs = ""

            for uf in relatorio_final['cnpjs'][cnpj]['status']['ufs'] :

                ufs += f" {uf}"





            templ += f'''
<tr>
    <td style="width:839px">
    <p class="Tabela_Texto_Centralizado">{relatorio_final['razao-social']} {relatorio_final['cnpjs'][cnpj]['tipo']}</p>
    </td>
    <td style="width:976px">
    <p class="Tabela_Texto_Centralizado">{cnpj}&nbsp;</p>
    </td>
    <td style="width:976px">
    <p class="Tabela_Texto_Centralizado">{ufs}&nbsp;</p>
    </td>
</tr>
            '''



        templ += '''
</table>
        '''

    else:
        templ = f'''
<p class="Item_Nivel2">Na documentação enviada não foram encontradas escriturações referentes à prestadora {prest_} para o ano fiscal {ano_} em análise.</p>
        '''

    return templ

def tab2h(prest, cnpj, meses):
    templ = f'''
    	<tr>
			<td class="dark-mode-color-black" colspan="7" rowspan="1" style="background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado" id=""><strong>Denominação/Razão Social</strong></p>

			<p class="Tabela_Texto_Centralizado">&nbsp;</p>
			</td>
			<td class="dark-mode-color-black" colspan="6" rowspan="1" style="background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>CNPJ</strong></p>
			</td>
		</tr>
		<tr>
			<td colspan="7" rowspan="1">
			<p class="Texto_Centralizado">{prest}</p>
			</td>
			<td colspan="6" rowspan="1">
			<p class="Tabela_Texto_Centralizado">{cnpj}</p>
			</td>
		</tr>
		<tr>
			<td class="dark-mode-color-black" colspan="1" rowspan="2" style="width: 839px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>UF</strong></p>
			</td>
			<td class="dark-mode-color-black" colspan="12" rowspan="1" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>Período</strong></p>
			</td>
		</tr>
		<tr>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[0]}&nbsp;</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[1]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[2]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[3]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[4]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[5]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[6]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[7]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[8]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[9]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[10]}</strong></p>
			</td>
			<td class="dark-mode-color-black" style="width: 976px; background-color: rgb(170, 170, 170);">
			<p class="Tabela_Texto_Centralizado"><strong>{meses[11]}&nbsp;</strong></p>
			</td>
		</tr>
    '''

    return templ

def tab2r(uf, status):
    templ = f'''

		<tr>
			<td class="dark-mode-color-black" style="width: 839px; background-color: rgb(204, 204, 204);">
			<p class="Tabela_Texto_Centralizado">{uf}</p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[0]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[1]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[2]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[3]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[4]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[5]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[6]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[7]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[8]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[9]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[10]}</span></p>
			</td>
			<td style="width:976px">
			<p class="Tabela_Texto_Centralizado"><span style="color:#27ae60;">{status[11]}</span></p>
			</td>
		</tr>
    '''
    
    return templ

def outrosanos():

    templ = ''
    outrosaf = relatorio_final['outros-anos-fiscais']
    n = len(outrosaf)


    if n > 1:
        templ += f'''
<p class="Item_Nivel2">Foram identificados {n} arquivos com escriturações que, embora pertençam à prestadora objeto da fiscalização, não correspondem ao ano fiscal em análise e, por isso, não serão avaliados. Os arquivos são:</p>
        '''

    elif n > 0:
        templ += f'''
<p class="Item_Nivel2">Foi identificado {n} arquivo com escriturações que, embora pertença à prestadora objeto da fiscalização, não corresponde ao ano fiscal em análise e, por isso, não será avaliado. O arquivo é:</p>
        '''   

    if n > 0:

        for item in outrosaf:

            templ += f'''
    <p class="Item_Alinea_Letra">{item}</p>
            '''


    return templ


def mes_incompleto():

    templ = ''
    mesinc = relatorio_final['mes-incompleto']
    n = len(mesinc)


    if n > 1:
        templ += f'''
<p class="Item_Nivel2">Foram identificados {n} arquivos com escriturações que, embora pertençam à prestadora objeto da fiscalização e ao ano fiscal em análise, comtemplam mês parcial e, por isso, o período parcial não foi avaliado. Os arquivos são:</p>
        '''

    elif n > 0:
        templ += f'''
<p class="Item_Nivel2">Foi identificado {n} arquivo com escriturações que, embora pertença à prestadora objeto da fiscalização e ao ano fiscal em análise, comtempla mês parcial e, por isso, o período parcial não foi avaliado. O arquivo é:</p>
        '''   

    if n > 0:

        for item in mesinc:

            templ += f'''
    <p class="Item_Alinea_Letra">{item}</p>
            '''


    return templ



def semassinatura():

    templ = ''
    semass = relatorio_final['sem-assinatura']
    n = len(semass)


    if n > 1:
        templ += f'''
<p class="Item_Nivel2">Foram identificados {n} arquivos com escriturações que, embora pertençam à prestadora objeto da fiscalização e ao ano fiscal em análise, não possuem assinatura e, por isso, não serão avaliados. Os arquivos são:</p>
        '''

    elif n > 0:
        templ += f'''
<p class="Item_Nivel2">Foi identificado {n} arquivo com escriturações que, embora pertença à prestadora objeto da fiscalização e ao ano fiscal em análise, não possue assinatura e, por isso, não será avaliado. O arquivo é:</p>
        '''   

    if n > 0:

        for item in semass:

            templ += f'''
    <p class="Item_Alinea_Letra">{item}</p>
            '''


    return templ


def outroscnpjs():
    
    templ = ''
    outrosc = relatorio_final['outros-cnpjs']
    n = len(outrosc)

    if n > 1:
        templ += f'''
<p class="Item_Nivel2">Identificamos {n} arquivos com escriturações cujos CNPJs diferem do objeto da fiscalização, motivo pelo qual não serão avaliados. Os arquivos são:</p>
        '''

    elif n > 0:
        templ += f'''
<p class="Item_Nivel2">Identificamos {n} arquivo com escriturações cujos CNPJs diferem do objeto da fiscalização, motivo pelo qual não será avaliados. O arquivo é:</p>
        '''   


    if n > 0:
        for item in outrosc:

            templ += f'''
<p class="Item_Alinea_Letra">{item}</p>
            '''

    return templ



def diversos():
    
    templ = ''
    n = relatorio_final['outros-diversos']

    if n > 1:

        templ += f'''

<p class="Item_Nivel2">Foram identificados {n} arquivos complementares diversos em outros formatos que não poderão ser consideradas escriturações válidas, motivo pelo qual serão desconsiderados.</p>

<p class="Citacao">&nbsp;</p>
        '''

    elif n > 0:
         
        templ += f'''

<p class="Item_Nivel2">Foi identificado {n} arquivo complementar em outro formato que não poderá ser considerada escrituração válida, motivo pelo qual serão desconsiderados.</p>

<p class="Citacao">&nbsp;</p>
        '''           

    return templ


def ptitle():

    templ = ''
    txt = ''
    clr = ''
    if not relatorio_final['conexao-srf']:
        txt = ' INVÁLIDO POR FALHA DE CONEXÃO '
        clr = ''

    templ += f'''
<title>SEI/ANATEL - Relatório de Atividades{txt}</title>
    '''

    return templ

def prel():

    templ = ''
    txt = ''
    clr = ''
    if not relatorio_final['conexao-srf']:
        txt = ' INVÁLIDO POR FALHA DE CONEXÃO '
        clr = ' style="color:#e74c3c;"'

    templ = f'''
<p class="Texto_Centralizado_Maiusculas"{clr}>Relatório de Atividades{txt}</p>
    '''

    return templ

# def relecd():

#     templ = ''



#     return templ

      
# def relecf():

#     templ = ''

#     if not relatorio_final['escrituracoes']['ECD']['_']['valido-completo']:

#         templ += '''

#     <p class="Item_Nivel3">MÓDULO ECD - ESCRITURAÇÃO CONTÁBIL DIGITAL:&nbsp; sugere-se ao fiscal que busque junto a prestadora a obtenção das ultimas versões das escriturações ECD dos seguintes períodos:</p>

#     '''

#         if not relatorio_final['escrituracoes']['ECD']['_']['recebido-valido']:

#             templ += f'''

#     <p class="Item_Alinea_Letra" style="margin-left: 200px;">Janeiro a Dezembro de {relatorio_final['ano-fiscal']};</p>

#     '''

#         else:
#             inicio = ""
#             fim = ""
#             for mes in relatorio_final['escrituracoes']['ECD']['descartados']:
#                 if inicio == "":
#                     if mes != "":
#                         inicio = mes
#                 else:        
#                     if mes != "":
#                         fim == mes
#                     else:
#                         if inicio == fim:

#                             templ = f'''

#                             <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} de {relatorio_final['ano-fiscal']};</p>

#                                 '''
#                             inicio = ""
#                             fim = ""    

#                         else:

#                             templ = f'''

#                             <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} a {fim} de {relatorio_final['ano-fiscal']};</p>

#                                 '''                              
#                             inicio = ""
#                             fim = ""    

#             if inicio == fim:

#                 templ = f'''

#                 <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} de {relatorio_final['ano-fiscal']};</p>

#                     '''

#             else:

#                 templ = f'''

#                 <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} a {fim} de {relatorio_final['ano-fiscal']};</p>

#                     '''      



#     return templ  
    
    
# def relefdcont():

#     templ = ''



#     return templ
    
    
# def relefdii():

#     templ = ''



#     return templ
    
    
# def rellfpd():

#     templ = ''



#     return templ
    
def conclitem(tipo):

    templ = ''


    if relatorio_final['info-extra']['pendencias']['escrituracoes'][tipo]: # relatorio_final['escrituracoes']['ECD']['_']['valido-completo'] # relatorio_final['modulos-srf'][tipo]['descricao']

        templ += f'''


    <p class="Item_Nivel3">MÓDULO {tipo} - {(relatorio_final['modulos-srf'][tipo]['descricao']).upper()}:&nbsp; sugere-se ao fiscal que busque junto a prestadora a obtenção das ultimas versões das escriturações {tipo} dos seguintes períodos:</p>

    '''


        for cnpj in relatorio_final['cnpjs']: # cada cnpj, existe pelo menos 1


            if not relatorio_final['cnpjs'][cnpj]['status']['valido-completo']:
            

                for uf in relatorio_final['modulos-srf'][tipo]['ufs-avaliadas']:

                    uftxt = f" e UF {uf}"
                    if uf == "--":
                        uftxt = ""

                    templ += f'''<p class="Item_Inciso_Romano">Para o CNPJ {relatorio_final['cnpjs'][cnpj]['tipo']}{uftxt},</p>'''
                
                    templv = ''
                    templnsrf = ''

                    for p in  relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-pendentes']:

                        if p['inicio'] == p['fim']:

                            templv += f"{p['inicio']}"

                        else:

                            templv += f"{p['inicio']} a {p['fim']}"      

                        # avalia aqui recebidos invalidos

                        templnsrf = ""
                        ln = len(relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-invalidos'])
                        if ln > 0:

                            templnsrf0 = ""

                            for pn in relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-invalidos']:

                                if pn['inicio'] == pn['fim']:
                                    templnsrf0 += f"{pn['inicio']}"
                                else:
                                    templnsrf0 += f"{pn['inicio']} a {pn['fim']}"  

                                ln = ln - 1
                                if ln == 1:
                                    templnsrf0 += f" e " 
                                elif ln == 0:
                                    templnsrf0 += f" " 
                                else:
                                    templnsrf0 += f", "        



                            templnsrf = f" Além disso as escriturações dos períodos de {templnsrf0} de 2022 apresentadas não correspondem às que estão na base do SPED;"


                                
                    templ += f'''

                            <p class="Item_Alinea_Letra" style="margin-left: 200px;">{templv} de {relatorio_final['ano-fiscal']};{templnsrf}</p>

                                '''


    return templ    
    
    
# def conclecf():

#     templ = ''

#     if not relatorio_final['escrituracoes']['ECF']['_']['valido-completo']:

#         templ += '''

# <p class="Item_Nivel3">MÓDULO ECF - ESCRITURAÇÃO CONTÁBIL FISCAL :<span style="font-size: 12pt; text-indent: 0mm;">&nbsp;sugere-se ao fiscal que busque junto a prestadora a obtenção das ultimas versões das escriturações ECFs dos seguintes períodos:</span></p>
# '''

#         if not relatorio_final['escrituracoes']['ECF']['_']['recebido-valido']:

#             templ += f'''

#     <p class="Item_Alinea_Letra" style="margin-left: 200px;">Janeiro a Dezembro de {relatorio_final['ano-fiscal']};</p>

#     '''

#         else:
#             inicio = ""
#             fim = ""
#             for mes in relatorio_final['escrituracoes']['ECF']['descartados']:
#                 if inicio == "":
#                     if mes != "":
#                         inicio = mes
#                 else:        
#                     if mes != "":
#                         fim == mes
#                     else:
#                         if inicio == fim:

#                             templ = f'''

#                             <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} de {relatorio_final['ano-fiscal']};</p>

#                                 '''
#                             inicio = ""
#                             fim = ""    

#                         else:

#                             templ = f'''

#                             <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} a {fim} de {relatorio_final['ano-fiscal']};</p>

#                                 '''                              
#                             inicio = ""
#                             fim = ""    

#             if inicio == fim:

#                 templ = f'''

#                 <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} de {relatorio_final['ano-fiscal']};</p>

#                     '''

#             else:

#                 templ = f'''

#                 <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} a {fim} de {relatorio_final['ano-fiscal']};</p>

#                     '''      



#     return templ    
    
    
def conclefdc():

    templ = ''

    if not relatorio_final['escrituracoes']['EFD ICMS-IPI']['_']['valido-completo']:

        templ += '''

<p class="Item_Nivel3">MÓDULO EFD CONTRIBUIÇÕES - ESCRITURAÇÃO FISCAL DIGITAL DAS CONTRIBUIÇÕES&nbsp;:<span style="font-size: 12pt; text-indent: 0mm;">sugere-se ao fiscal que busque junto a prestadora a obtenção das ultimas versões das escriturações EFD-Contribuições dos seguintes períodos:</span></p>

'''


        if not relatorio_final['escrituracoes']['EFD ICMS-IPI']['_']['recebido-valido']:

            templ += f'''

    <p class="Item_Alinea_Letra" style="margin-left: 200px;">Janeiro a Dezembro de {relatorio_final['ano-fiscal']};</p>

    '''

        else:
            inicio = ""
            fim = ""
            for mes in relatorio_final['escrituracoes']['EFD ICMS-IPI']['descartados']:
                if inicio == "":
                    if mes != "":
                        inicio = mes
                else:        
                    if mes != "":
                        fim == mes
                    else:
                        if inicio == fim:

                            templ = f'''

                            <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} de {relatorio_final['ano-fiscal']};</p>

                                '''
                            inicio = ""
                            fim = ""    

                        else:

                            templ = f'''

                            <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} a {fim} de {relatorio_final['ano-fiscal']};</p>

                                '''                              
                            inicio = ""
                            fim = ""    

            if inicio == fim:

                templ = f'''

                <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} de {relatorio_final['ano-fiscal']};</p>

                    '''

            else:

                templ = f'''

                <p class="Item_Alinea_Letra" style="margin-left: 200px;">{inicio} a {fim} de {relatorio_final['ano-fiscal']};</p>

                    '''      



    return templ    
    
  
   
    
def relconcl():

    templ = ''

    templ += f'''

<p class="Item_Nivel1">CONCLUSÃO</p>

<p class="Item_Nivel2">Foram analisados {relatorio_final['arquivos']['total']} arquivos enviados pela prestadora, dos quais {relatorio_final['arquivos']['uteis']} foram considerados válidos e aptos para análise e fiscalização do fundo em questão.

'''

    # templ += f"<p>*** DEBUG *** not relatorio_final['escrituracoes']['ECD']['_']['valido-completo'] {not relatorio_final['escrituracoes']['ECD']['_']['valido-completo']}</p>"
    # templ += f"<p>*** DEBUG *** not relatorio_final['escrituracoes']['ECF']['_']['valido-completo'] {not relatorio_final['escrituracoes']['ECF']['_']['valido-completo']}</p>"
    # templ += f"<p>*** DEBUG *** not relatorio_final['escrituracoes']['EFD ICMS-IPI']['_']['valido-completo'] {not relatorio_final['escrituracoes']['EFD ICMS-IPI']['_']['valido-completo']}</p>"
    # templ += f"<p>*** DEBUG *** not relatorio_final['escrituracoes']['EFD-Contribuições']['_']['valido-completo'] {not relatorio_final['escrituracoes']['EFD-Contribuições']['_']['valido-completo']}</p>"
    # templ += f"<p>*** DEBUG *** not relatorio_final['escrituracoes']['LFPD']['_']['valido-completo'] {not relatorio_final['escrituracoes']['LFPD']['_']['valido-completo']}</p>"
    # templ += f"<p>*** DEBUG *** {(not relatorio_final['escrituracoes']['ECD']['_']['valido-completo']) or (not relatorio_final['escrituracoes']['ECF']['_']['valido-completo']) or (not relatorio_final['escrituracoes']['EFD ICMS-IPI']['_']['valido-completo']) or (not relatorio_final['escrituracoes']['EFD-Contribuições']['_']['valido-completo'])}</p>"


    if relatorio_final['info-extra']['pendencias']['geral'] :

        templ += f''' <span style="font-size: 12pt; text-indent: 0mm;">No entanto, existem pendências nos arquivos enviados as quais que devem passar por uma análise de conveniência e oportunidade pelo fiscal, que decidirá por solicitar, ou não, correção ou complementação das informações inicialmente enviadas pela prestadora. As pendências encontradas foram as seguintes:</span></p>

    '''


        for tipo in relatorio_final['modulos-srf']:

            templ += conclitem(tipo)

    return templ


def rmodulosrf(tipo):
    templ = ""

    match tipo:

            
        case "EFD ICMS-IPI": # EFD ICMS-IPI # EFD-ICMS IPI

            if relatorio_final['info-extra']['recebidos']['escrituracoes'][tipo] :

                templ += f''' <p class="Item_Nivel2">Submetendo as escriturações localizadas à verificação de status no sistema SPED da Receita Federal do Brasil, verificou-se o seguinte:</p> '''

            for cnpj in relatorio_final['cnpjs']:

                if relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['status']['recebido']:

                    templ += f''' 
                    
    <table border="1" style="border-collapse:collapse;border-color:#646464;margin-left:auto;margin-right:auto;width:80%;">
        <tbody>
            <tr>
                <td class="dark-mode-color-black" colspan="7" rowspan="1" style="background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado" id=""><strong>Denominação/Razão Social</strong></p>
                </td>
                <td class="dark-mode-color-black" colspan="6" rowspan="1" style="background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>CNPJ</strong></p>
                </td>
            </tr>
            <tr>
                <td colspan="7" rowspan="1">
                <p class="Texto_Centralizado">{relatorio_final['razao-social']} ({relatorio_final['cnpjs'][cnpj]['tipo']})</p>
                </td>
                <td colspan="6" rowspan="1">
                <p class="Tabela_Texto_Centralizado">{cnpj}</p>
                </td>
            </tr>
            <tr>
                <td class="dark-mode-color-black" colspan="1" rowspan="2" style="width:839px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>UF</strong></p>
                </td>
                <td class="dark-mode-color-black" colspan="12" rowspan="1" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Período</strong></p>
                </td>
            </tr>
            <tr>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Janeiro </strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Fevereiro</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Março</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Abril</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Maio</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Junho</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Julho</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Agosto</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Setembro</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Outubro</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Novembro</strong></p>
                </td>
                <td class="dark-mode-color-black" style="width:976px; background-color:#aaaaaa">
                <p class="Tabela_Texto_Centralizado"><strong>Dezembro </strong></p>
                </td>
            </tr>
                    
                    '''

                    for uf in relatorio_final['modulos-srf'][tipo]['ufs-avaliadas']:

                        if relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['recebido']:

                            templ += f'''

                <tr>
                    <td class="dark-mode-color-black" style="width:839px; background-color:#cccccc">
                    <p class="Tabela_Texto_Centralizado">{uf}</p>
                    </td>
                    '''

                            for mes in relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['meses']:

                                stl = '' # verde ' style="color:#16a085"' vermelho ' style="color:#e74c3c"'
                                txt = ""
                                if relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['meses'][mes]['recebido']:

                                    if relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['meses'][mes]['valido']:
                                        txt = "Válido"
                                        stl = ' style="color:#16a085"'
                                    else:
                                        txt = "Inválido"
                                        stl = ' style="color:#e74c3c"'

                                templ += f''' 

                        <td style="width:976px">
                        <p class="Tabela_Texto_Centralizado"><span{stl}>{txt}</span></p>
                        </td>           

                                '''

                        #         templ += f'''
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado">&nbsp;</p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado">&nbsp;</p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado">&nbsp;</p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado">&nbsp;</p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado">&nbsp;</p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado"><span style="color:#16a085">Válido</span></p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado"><span style="color:#16a085">Válido</span></p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado"><span style="color:#e74c3c">Inválido</span></p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado"><span style="color:#e74c3c">Inválido</span></p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado"><span style="color:#16a085">Válido</span></p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado"><span style="color:#16a085">Válido</span></p>
                        # </td>
                        # <td style="width:976px">
                        # <p class="Tabela_Texto_Centralizado"><span style="color:#16a085">Válido</span></p>
                        # </td>
                        # '''

                            templ += f'''
                </tr>
                        '''


                templ += f'''</tbody></table><p class="Citacao">&nbsp;</p>  '''

            #templ += f'''<p class="Item_Nivel2">*** Implementando este módulo para {tipo}.'''


        #case "ECD":
        #case "ECF":
        #case "EFD-Contribuições":
            
        case "LFPD":
            templ += f''' '''

        case _:


            if relatorio_final['info-extra']['recebidos']['escrituracoes'][tipo] :

                if tipo == "ECF":

                    templ += f'''<p class="Item_Nivel2">O Programa Validador Autenticador (PVA) da Escrituração Contábil Fiscal (ECF) não oferece a possibilidade de verificar diretamente o estado da escrituração no sistema SPED. Assim, a validação da ECF é realizada de forma indireta, por meio da verificação se o hash da ECD que originou a ECF corresponde ao hash da ECD atualmente válida. Essa abordagem assegura que a ECF esteja correta e em conformidade com a ECD previamente enviada (atual), garantindo a integridade dos dados e a consistência das informações contábeis.</p>'''

                    templ += f''' <p class="Item_Nivel2">Dessa forma procedeu-se a comparação dos hash da ECF, bloco C0O1, com o hash da ECD analisada no item anterior, chegando-se as seguintes conclusões:</p> '''

                else:
 
                    templ += f'''<p class="Item_Nivel2">Submetendo as escriturações localizadas à verificação de status no sistema SPED da Receita Federal do Brasil, verificou-se o seguinte:</p>'''



            #xxxxxxxxxxxx

            for cnpj in relatorio_final['cnpjs']: # cada cnpj, existe pelo menos 1

                for uf in relatorio_final['modulos-srf'][tipo]['ufs-avaliadas']:

                    ln = len(relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-validos'])
                    if ln > 0:
        
                        uftxt = f" e UF {uf}"
                        if uf == "--":
                            uftxt = ""

                        templ += f'''<p class="Item_Inciso_Romano">Para o CNPJ {relatorio_final['cnpjs'][cnpj]['tipo']}{uftxt}, conferem e são as mesmas que se encontram na base de dados do SPED:</p>'''
                    
                        templv = ''
                        templnsrf = ''

                        for p in  relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-validos']:

                            if p['inicio'] == p['fim']:

                                templv += f"{p['inicio']}"

                            else:

                                templv += f"{p['inicio']} a {p['fim']}"      

                            
                            ln = ln - 1
                            if ln == 1:
                                templv += f" e " 
                            elif ln == 0:
                                templv += f" " 
                            else:
                                templv += f", "     
                                    
                        templ += f'''

                                <p class="Item_Alinea_Letra" style="margin-left: 200px;">{templv} de {relatorio_final['ano-fiscal']}</p>

                                    '''

            #xxxxxxxxxxxx

            for cnpj in relatorio_final['cnpjs']: # cada cnpj, existe pelo menos 1

                for uf in relatorio_final['modulos-srf'][tipo]['ufs-avaliadas']:

                    ln = len(relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-invalidos'])
                    if ln > 0:
        
                        uftxt = f" e UF {uf}"
                        if uf == "--":
                            uftxt = ""

                        templ += f'''<p class="Item_Inciso_Romano">Para o CNPJ {relatorio_final['cnpjs'][cnpj]['tipo']}{uftxt}, não conferem ou não são as mesmas que se encontram na base de dados do SPED:</p>'''
                    
                        templv = ''
                        templnsrf = ''

                        
                        for p in  relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-invalidos']:

                            if p['inicio'] == p['fim']:

                                templv += f"{p['inicio']}"

                            else:

                                templv += f"{p['inicio']} a {p['fim']}"      

                            
                            ln = ln - 1
                            if ln == 1:
                                templv += f" e " 
                            elif ln == 0:
                                templv += f" " 
                            else:
                                templv += f", "     
                                    
                        templ += f'''

                                <p class="Item_Alinea_Letra" style="margin-left: 200px;">{templv} de {relatorio_final['ano-fiscal']}</p>

                                    '''

            #xxxxxxxxxxxx

    return templ


def rmodulo(tipo):

    templ = ""

    templ += f'''

<p class="Texto_Alinhado_Esquerda_Espacamento_Simples_Maiusc"><strong>{tipo} - &nbsp;{relatorio_final['modulos-srf'][tipo]['descricao'].upper()} </strong></p>

<p class="Item_Nivel2">{relatorio_final['modulos-srf'][tipo]['obrigacao']}</p>

<p class="Item_Nivel2">{relatorio_final['modulos-srf'][tipo]['apresentacao']}</p>

    '''

    if relatorio_final['info-extra']['recebidos']['escrituracoes'][tipo]:

        templ += f'''

    <p class="Item_Nivel2">No caso em análise, foram encontradas para o CNPJ em análise as EFD-ICMS IPI para os seguintes períodos, UFs e unidades (matriz e filiais):</p>

        '''

        #xxxxxxxxxxxx


        for cnpj in relatorio_final['cnpjs']: # cada cnpj, existe pelo menos 1

            for uf in relatorio_final['modulos-srf'][tipo]['ufs-avaliadas']:

                if relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['recebido']:
    
                    uftxt = f" e UF {uf}"
                    if uf == "--":
                        uftxt = ""

                    templ += f'''<p class="Item_Inciso_Romano">Para o CNPJ {relatorio_final['cnpjs'][cnpj]['tipo']}{uftxt},</p>'''
                
                    templv = ''
                    templnsrf = ''

                    ln = len(relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-recebidos'])
                    for p in  relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-recebidos']:

                        if p['inicio'] == p['fim']:

                            templv += f"{p['inicio']}"

                        else:

                            templv += f"{p['inicio']} a {p['fim']}"      

                        
                        ln = ln - 1
                        if ln == 1:
                            templv += f" e " 
                        elif ln == 0:
                            templv += f" " 
                        else:
                            templv += f", "     
                                
                    templ += f'''

                            <p class="Item_Alinea_Letra" style="margin-left: 200px;">{templv} de {relatorio_final['ano-fiscal']}</p>

                                '''

    if relatorio_final['info-extra']['recebidos']['escrituracoes'][tipo]:

            #xxxxxxxxxxxx


        if relatorio_final['info-extra']['pendencias']['escrituracoes'][tipo]: # relatorio_final['escrituracoes']['ECD']['_']['valido-completo'] # relatorio_final['modulos-srf'][tipo]['descricao']

            templ += f'''

    <p class="Item_Nivel2">Não foram encontradas {tipo}s para a prestadora e o ano fiscal em tela para os seguintes períodos:</p>

        '''


            for cnpj in relatorio_final['cnpjs']: # cada cnpj, existe pelo menos 1


                if not relatorio_final['cnpjs'][cnpj]['status']['valido-completo']:
                

                    for uf in relatorio_final['modulos-srf'][tipo]['ufs-avaliadas']:

                        uftxt = f" e UF {uf}"
                        if uf == "--":
                            uftxt = ""

                        templ += f'''<p class="Item_Inciso_Romano">Para o CNPJ {relatorio_final['cnpjs'][cnpj]['tipo']}{uftxt},</p>'''
                    
                        templv = ''
                        templnsrf = ''

                        ln = len(relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-ausentes'])
                        for p in  relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-ausentes']:

                            if p['inicio'] == p['fim']:

                                templv += f"{p['inicio']}"

                            else:

                                templv += f"{p['inicio']} a {p['fim']}"      


                            
                            ln = ln - 1
                            if ln == 1:
                                templv += f" e " 
                            elif ln == 0:
                                templv += f" " 
                            else:
                                templv += f", "   

                            # avalia aqui recebidos invalidos

                            templnsrf = ""
                            ln = len(relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-invalidos'])
                            if ln > 0:

                                templnsrf0 = ""

                                for pn in relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-invalidos']:

                                    if pn['inicio'] == pn['fim']:
                                        templnsrf0 += f"{pn['inicio']}"
                                    else:
                                        templnsrf0 += f"{pn['inicio']} a {pn['fim']}"  

                                    ln = ln - 1
                                    if ln == 1:
                                        templnsrf0 += f" e " 
                                    elif ln == 0:
                                        templnsrf0 += f" " 
                                    else:
                                        templnsrf0 += f", "        



                                templnsrf = f" Além disso as escriturações dos períodos de {templnsrf0} de 2022 apresentadas não correspondem às que estão na base do SPED;"


                                    
                        templ += f'''

                                <p class="Item_Alinea_Letra" style="margin-left: 200px;">{templv} de {relatorio_final['ano-fiscal']};{templnsrf}</p>

                                    '''


            #xxxxxxxxxxxx    

            templ += rmodulosrf(tipo)              

            #xxxxxxxxxxxx


        if relatorio_final['info-extra']['pendencias']['escrituracoes'][tipo]: # relatorio_final['escrituracoes']['ECD']['_']['valido-completo'] # relatorio_final['modulos-srf'][tipo]['descricao']

            templ += f'''

    <p class="Item_Nivel2">Dessa forma, sugere-se ao fiscal que busque junto a prestadora a obtenção das ultimas versões das escriturações {tipo} dos seguintes períodos:</p>
        '''


            for cnpj in relatorio_final['cnpjs']: # cada cnpj, existe pelo menos 1


                if not relatorio_final['cnpjs'][cnpj]['status']['valido-completo']:
                

                    for uf in relatorio_final['modulos-srf'][tipo]['ufs-avaliadas']:

                        uftxt = f" e UF {uf}"
                        if uf == "--":
                            uftxt = ""

                        templ += f'''<p class="Item_Inciso_Romano">Para o CNPJ {relatorio_final['cnpjs'][cnpj]['tipo']}{uftxt},</p>'''
                    
                        templv = ''
                        templnsrf = ''

                        for p in  relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-pendentes']:

                            if p['inicio'] == p['fim']:

                                templv += f"{p['inicio']}"

                            else:

                                templv += f"{p['inicio']} a {p['fim']}"      

                            # avalia aqui recebidos invalidos

                            templnsrf = ""
                            ln = len(relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-invalidos'])
                            if ln > 0:

                                templnsrf0 = ""

                                for pn in relatorio_final['cnpjs'][cnpj]['escrituracoes'][tipo]['ufs'][uf]['status']['periodos-invalidos']:

                                    if pn['inicio'] == pn['fim']:
                                        templnsrf0 += f"{pn['inicio']}"
                                    else:
                                        templnsrf0 += f"{pn['inicio']} a {pn['fim']}"  

                                    ln = ln - 1
                                    if ln == 1:
                                        templnsrf0 += f" e " 
                                    elif ln == 0:
                                        templnsrf0 += f" " 
                                    else:
                                        templnsrf0 += f", "        



                                templnsrf = f" Além disso as escriturações dos períodos de {templnsrf0} de 2022 apresentadas não correspondem às que estão na base do SPED;"


                                    
                        templ += f'''

                                <p class="Item_Alinea_Letra" style="margin-left: 200px;">{templv} de {relatorio_final['ano-fiscal']};{templnsrf}</p>

                                    '''


            #xxxxxxxxxxxx        


    if not relatorio_final['info-extra']['recebidos']['escrituracoes'][tipo]:

        templ += f'''

    <p class="Item_Nivel2">No caso em análise, não foram encontradas para o CNPJ em análise as {tipo}s.</p>

        '''

    if not relatorio_final['info-extra']['pendencias']['escrituracoes'][tipo]:

        templ += f''' <p class="Item_Nivel2">Dessa forma, foram encontradas escriturações&nbsp;{tipo} válidas para todo o período do ano fiscal em análise;</p> '''    

    if tipo == "LFPD":

        templ += f''' <p class="Item_Nivel2">A análise do status da LFPD ainda não foi implementada de maneira automatizada, devendo, portanto, o fiscal recorrer aos devidos&nbsp; meios para validar tais escriturações.</p> '''    


    return templ
    

def relmodulos():

    templ = ""


    for tipo in relatorio_final['modulos-srf']:

        templ += rmodulo(tipo)   

    return templ                 


def relatorio_sei():

    html = ''

    html += '''
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html lang="pt-br"><head>
<meta http-equiv="Pragma" content="no-cache">
<meta name="robots" content="noindex">
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    '''
    
    html += ptitle()
    
    html += '''
<style type="text/css">
p.Citacao {font-size:10pt;font-family:Calibri;word-wrap:normal;margin:4pt 0 4pt 160px;text-align:justify;} p.Item_Alinea_Letra {font-size:12pt;font-family:Calibri;text-indent:0mm;text-align:justify;word-wrap:normal;margin:6pt 6pt 6pt 120px;counter-increment:letra_minuscula;} p.Item_Alinea_Letra:before {content:counter(letra_minuscula, lower-latin) ") ";display:inline-block;width:5mm;font-weight:normal;} p.Item_Inciso_Romano {font-size:12pt;font-family:Calibri;text-align:justify;word-wrap:normal;text-indent:0mm;margin:6pt 6pt 6pt 120px;counter-increment:romano_maiusculo;counter-reset:letra_minuscula;} p.Item_Inciso_Romano:before {content:counter(romano_maiusculo, upper-roman) " - ";display:inline-block;width:15mm;font-weight:normal;} p.Item_Nivel1 {text-transform:uppercase;font-weight:bold;background-color:#e6e6e6;font-size:12pt;font-family:Calibri;text-align:justify;word-wrap:normal;text-indent:0;margin:6pt;counter-increment:item-n1;counter-reset:item-n2 item-n3 item-n4 romano_maiusculo letra_minuscula;} p.Item_Nivel1:before {content:counter(item-n1) ".";display:inline-block;width:25mm;font-weight:normal;} p.Item_Nivel2 {font-size:12pt;font-family:Calibri;text-indent:0mm;text-align:justify;word-wrap:normal;margin:6pt;counter-increment:item-n2;counter-reset:item-n3 item-n4 romano_maiusculo letra_minuscula;} p.Item_Nivel2:before {content:counter(item-n1) "." counter(item-n2) ".";display:inline-block;width:25mm;font-weight:normal;} p.Item_Nivel3 {font-size:12pt;font-family:Calibri;text-indent:0mm;text-align:justify;word-wrap:normal;margin:6pt;counter-increment:item-n3;counter-reset:item-n4 romano_maiusculo letra_minuscula;margin-left:40px;} p.Item_Nivel3:before {content:counter(item-n1) "." counter(item-n2) "." counter(item-n3) ".";display:inline-block;width:25mm;font-weight:normal;} p.Item_Nivel4 {font-size:12pt;font-family:Calibri;text-indent:0mm;text-align:justify;word-wrap:normal;margin:6pt;counter-increment:item-n4;counter-reset:romano_maiusculo letra_minuscula;margin-left:80px;} p.Item_Nivel4:before {content:counter(item-n1) "." counter(item-n2) "." counter(item-n3) "."  counter(item-n4) ".";display:inline-block;width:25mm;font-weight:normal;} p.Paragrafo_Numerado_Nivel1 {font-size:12pt;font-family:Calibri;text-align:justify;word-wrap:normal;text-indent:0mm;margin:6pt;counter-increment:paragrafo-n1;counter-reset:paragrafo-n2 paragrafo-n3 paragrafo-n4 romano_maiusculo letra_minuscula;} p.Paragrafo_Numerado_Nivel1:before {content:counter(paragrafo-n1) ".";display:inline-block;width:25mm;font-weight:normal;} p.Paragrafo_Numerado_Nivel2 {font-size:12pt;font-family:Calibri;text-indent:0mm;text-align:justify;word-wrap:normal;margin:6pt;counter-increment:paragrafo-n2;counter-reset:paragrafo-n3 paragrafo-n4 romano_maiusculo letra_minuscula;margin-left:40px;} p.Paragrafo_Numerado_Nivel2:before {content:counter(paragrafo-n1) "." counter(paragrafo-n2) ".";display:inline-block;width:25mm;font-weight:normal;} p.Paragrafo_Numerado_Nivel3 {font-size:12pt;font-family:Calibri;text-indent:0mm;text-align:justify;word-wrap:normal;margin:6pt;counter-increment:paragrafo-n3;counter-reset:paragrafo-n4 romano_maiusculo letra_minuscula;margin-left:80px;} p.Paragrafo_Numerado_Nivel3:before {content:counter(paragrafo-n1) "." counter(paragrafo-n2) "." counter(paragrafo-n3) ".";display:inline-block;width:25mm;font-weight:normal;} p.Paragrafo_Numerado_Nivel4 {font-size:12pt;font-family:Calibri;text-indent:0mm;text-align:justify;word-wrap:normal;margin:6pt;counter-increment:paragrafo-n4;counter-reset:romano_maiusculo letra_minuscula;margin-left:120px;} p.Paragrafo_Numerado_Nivel4:before {content:counter(paragrafo-n1) "." counter(paragrafo-n2) "." counter(paragrafo-n3) "." counter(paragrafo-n4) ".";display:inline-block;width:25mm;font-weight:normal;} p.Tabela_Texto_8 {font-size:8pt;font-family:Calibri;text-align:left;word-wrap:normal;margin:0 3pt 0 3pt;} p.Tabela_Texto_Alinhado_Direita {font-size:11pt;font-family:Calibri;text-align:right;word-wrap:normal;margin:0 3pt 0 3pt;} p.Tabela_Texto_Alinhado_Esquerda {font-size:11pt;font-family:Calibri;text-align:left;word-wrap:normal;margin:0 3pt 0 3pt;} p.Tabela_Texto_Centralizado {font-size:11pt;font-family:Calibri;text-align:center;word-wrap:normal;margin:0 3pt 0;} p.Texto_Alinhado_Direita {font-size:12pt;font-family:Calibri;text-align:right;word-wrap:normal;margin:6pt;} p.Texto_Alinhado_Esquerda {font-size:12pt;font-family:Calibri;text-align:left;word-wrap:normal;margin:6pt;} p.Texto_Alinhado_Esquerda_Espacamento_Simples {font-size:12pt;font-family:Calibri;text-align:left;word-wrap:normal;margin:0 0 0 6pt;} p.Texto_Alinhado_Esquerda_Espacamento_Simples_Maiusc {font-size:12pt;font-family:Calibri;text-align:left;text-transform:uppercase;word-wrap:normal;margin:0 0 0 6pt;} p.Texto_Centralizado {font-size:12pt;font-family:Calibri;text-align:center;word-wrap:normal;margin:6pt;} p.Texto_Centralizado_Maiusculas {font-size:13pt;font-family:Calibri;text-align:center;text-transform:uppercase;word-wrap:normal;} p.Texto_Centralizado_Maiusculas_Negrito {font-weight:bold;font-size:13pt;font-family:Calibri;text-align:center;text-transform:uppercase;word-wrap:normal;} p.Texto_Espaco_Duplo_Recuo_Primeira_Linha {letter-spacing:1px;font-weight:bold;font-size:12pt;font-family:Calibri;text-indent:25mm;text-align:justify;word-wrap:normal;margin:6pt;} p.Texto_Fundo_Cinza_Maiusculas_Negrito {text-transform:uppercase;font-weight:bold;background-color:#e6e6e6;font-size:12pt;font-family:Calibri;text-align:justify;word-wrap:normal;text-indent:0;margin:6pt;} p.Texto_Fundo_Cinza_Negrito {font-weight:bold;background-color:#e6e6e6;font-size:12pt;font-family:Calibri;text-align:justify;word-wrap:normal;text-indent:0;margin:6pt;} p.Texto_Justificado {font-size:12pt;font-family:Calibri;text-align:justify;word-wrap:normal;text-indent:0;margin:6pt;} p.Texto_Justificado_Maiusculas {font-size:12pt;font-family:Calibri;text-align:justify;word-wrap:normal;text-indent:0;margin:6pt;text-transform:uppercase;} p.Texto_Justificado_Recuo_Primeira_Linha {font-size:12pt;font-family:Calibri;text-indent:25mm;text-align:justify;word-wrap:normal;margin:6pt;} p.Texto_Justificado_Recuo_Primeira_Linha_Esp_Simples {font-size:12pt;font-family:Calibri;text-indent:25mm;text-align:justify;word-wrap:normal;margin:0 0 0 6pt;} 
</style>
<style type="text/css">.lnkseisel{background-color: yellow;}</style>
<script type="text/javascript">document.addEventListener('click',function(ev){if(ev.target.className.indexOf('ancora_sei')!==-1){var b=document.getElementsByClassName('lnkseisel');if(b.length>0){for(var a=b.length;a;)b[--a].className='ancora_sei';}ev.target.className='ancora_sei lnkseisel';}});</script>
</head>
<body>
    '''

    html += f'''
<div align="center"><img alt="Timbre" src="data:image/svg+xml;base64,PHN2ZyB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgaGVpZ2h0PSI2OS4xMSIgd2lkdGg9IjIwMSIgdmVyc2lvbj0iMS4xIiB4bWxuczpjYz0iaHR0cDovL2NyZWF0aXZlY29tbW9ucy5vcmcvbnMjIiB4bWxuczp4bGluaz0iaHR0cDovL3d3dy53My5vcmcvMTk5OS94bGluayIgeG1sbnM6ZGM9Imh0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvIj48dGl0bGU+VGltYnJlIEFuYXRlbDwvdGl0bGU+PGRlZnM+PHJhZGlhbEdyYWRpZW50IGlkPSJhIiBzcHJlYWRNZXRob2Q9InJlZmxlY3QiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIiBjeT0iMzU4LjIiIGN4PSIxMzYuNyIgZ3JhZGllbnRUcmFuc2Zvcm09Im1hdHJpeCguMjAzNyAuMTAyIC0uMTI0OSAuMjQ5NCAzOC4yOSAtNjQuNjkpIiByPSI3OC42NCI+PHN0b3Agc3RvcC1jb2xvcj0iIzAwMDdmZiIgc3RvcC1vcGFjaXR5PSIwIiBvZmZzZXQ9IjAiLz48c3RvcCBzdG9wLWNvbG9yPSIjMDA0N2JiIiBzdG9wLW9wYWNpdHk9Ii40OTgwIiBvZmZzZXQ9Ii41NTY5Ii8+PHN0b3Agc3RvcC1jb2xvcj0iIzAwMDdmZiIgb2Zmc2V0PSIxIi8+PC9yYWRpYWxHcmFkaWVudD48L2RlZnM+PGcgdHJhbnNmb3JtPSJtYXRyaXgoLjgzMSAwIDAgLjgzMSAtNi40MDcgLTMuNDIpIj48ZyBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGZpbGw9IiMwMDkwMzUiPjxwYXRoIGQ9Im0xMDUuNSA1Ni42NGMwLjEgMi43OCAwIDUuNTYtMC4zIDguMTVoOC4xYzAuOC0xMS40OC0xLjgtMjYuNzMtMy40LTMyLjUzaC02Yy00LjU2IDUuOC0xNS4yNiAyMS4wNS0yMC41NiAzMi41M2g4LjJjMS4xLTIuNTkgMi41LTUuMzcgNC04LjE1aDkuOTZ6bS04LjA2LTMuNjRjMy41Ni02LjM2IDcuMDYtMTEuNTQgNy4wNi0xMS41NHMwLjcgNS4xOCAwLjkgMTEuNTRoLTcuOTZ6Ii8+PHBhdGggZD0ibTEzOS42IDY0Ljc5aDUuMWw4LjYtMzIuNTNoLTcuM2wtNS4xIDE5LjI2LTkuMy0xOS4yNmgtNS4xbC04LjYgMzIuNTNoNy4ybDUuMS0xOS4yIDkuNCAxOS4yeiIvPjxwYXRoIGQ9Im0xNzEgNTYuNjRjMCAyLjc4LTAuMSA1LjU2LTAuMyA4LjE1aDhjMC43LTExLjQ4LTEuOS0yNi43My0zLjMtMzIuNTNoLTYuMWMtNC42IDUuOC0xNS4yIDIxLjA1LTIwLjUgMzIuNTNoOC4xYzEuMS0yLjU5IDIuNS01LjM3IDQtOC4xNWgxMC4xem0tOC4yLTMuNjRjMy43LTYuMzYgNy4xLTExLjU0IDcuMS0xMS41NHMwLjcgNS4xOCAxIDExLjU0aC04LjF6Ii8+PHBhdGggZD0ibTE5Mi44IDY0Ljc5IDcuNy0yOC44OWg4LjFsMS0zLjY0aC0yNC4ybC0xIDMuNjRoOC4ybC03LjUgMjguODloNy43eiIvPjxwYXRoIGQ9Im0yMTMuOSA2MS4yMSAyLjktMTEuMjNoOS41bDEtMy42NWgtOS41bDIuNy0xMC40M2gxMS4ybDAuOS0zLjY0aC0xOC45bC04LjYgMzIuNTNoMTkuNWwwLjktMy41OGgtMTEuNnoiLz48cGF0aCBkPSJtMjM4LjMgNjEuMjEgNy42LTI4Ljk1aC03LjhsLTguNiAzMi41M2gxOS4ybDAuOS0zLjU4aC0xMS4zeiIvPjwvZz48cGF0aCBkPSJtNzUuMjQgNjQuNzljMTAuMS0yMy41MiA3LjktNDcuMDQtNi43Ni01Ni41NC0xMy44OS05LjAxOS0zNC42OS0yLjc3OS01MS42MSAxMy43NiAxMS4wNS04LjUyIDIzLjU4LTEwLjggMzEuMjQtNC42MyA5Ljc1IDcuODQgNy42NSAyNi42MS00Ljc2IDQxLjkyLTEuNiAxLjk3LTMuMzMgMy44My01LjEyIDUuNTVsMzcuMDEtMC4xeiIgZmlsbC1ydWxlPSJldmVub2RkIiBmaWxsPSIjZmZkYzAwIi8+PGcgZmlsbC1ydWxlPSJldmVub2RkIiBmaWxsPSIjMDA5MDM1Ij48cGF0aCBkPSJtMzguMzQgNzUuMjhoLTAuMzFsLTYuMTcgOC43aDAuNDMgMC40M2MwLjY4LTEuMSAxLjQyLTIuMiAyLjEtMy40aDMuMjFjMC4xOSAxLjIgMC4zMSAyLjQgMC4zNyAzLjRoMC42OCAwLjYybC0xLjM2LTguN3ptLTAuMzcgNC45aC0yLjcybDIuMTYtMy4zIDAuNTYgMy4zeiIvPjxwYXRoIGQ9Im00My4wOSA4My44OGMwLjkzIDAgMS43OSAwLjEgMS40MiAxLjQtMC4zMSAxLjItMS40OCAxLjYtMi4zNCAxLjYtMS4wNSAwLTEuNjctMC41LTEuNDItMS41IDAuMjQtMSAxLjA1LTEuNSAyLjM0LTEuNXptNC4yLTUuOGgtMC45M2wtMS42Ni0wLjFjLTEuODYtMC4xLTIuNzIgMC44LTMuMDkgMi0wLjI1IDAuOSAwLjEyIDEuNCAwLjc0IDEuOC0wLjU1IDAuMi0wLjk5IDAuNS0xLjExIDEtMC4yNSAwLjggMC4xMiAxIDAuNDkgMS4xaC0wLjFjLTAuOCAwLjItMS40MiAwLjYtMS42NiAxLjYtMC4zOCAxLjMgMC43NCAxLjggMS43MiAxLjggMS45MiAwIDMuNDYtMSAzLjgzLTIuNSAwLjI1LTEuMS0wLjI1LTEuNi0xLjczLTEuNmgtMC44Yy0wLjc0IDAtMS4xNy0wLjEtMC45OS0wLjYgMC4xOS0wLjggMC44Ny0wLjYgMS4wNS0wLjYgMS40MiAwIDIuNzgtMC42IDMuMTUtMiAwLjE5LTAuNiAwLTEuMi0wLjQzLTEuNmwxLjM2IDAuMSAwLjEyLTAuNHptLTQuNjkgMS45YzAuMjQtMSAwLjkyLTEuNiAxLjc5LTEuNiAwLjk5IDAgMS4xNyAwLjcgMC45MiAxLjYtMC4yNCAwLjktMC45MiAxLjYtMS44NSAxLjYtMC44NiAwLTEuMTctMC44LTAuODYtMS42eiIvPjxwYXRoIGQ9Im00OS44MiA3Ny4zOCAxLjc5LTEuMyAxLjExIDEuM2gwLjQzbC0wLjk4LTIuMWgtMC42OGwtMi4xIDIuMWgwLjQzem0yLjE2IDUuM2MtMC40MyAwLjQtMS4yMyAwLjktMi4xIDAuOS0xLjQ4IDAtMS45MS0xLjItMS40Mi0yLjZoMS43M2MwLjg3IDAgMS42NyAwIDIuNTMgMC4xIDAuNjgtMi4xLTAuMzEtMy4xLTEuNzMtMy4xLTEuODUgMC0zLjIxIDEuNC0zLjY0IDMuMS0wLjU1IDEuOSAwLjM3IDMgMi4xIDMgMC43NCAwIDEuNjEtMC4zIDIuMzUtMC43bDAuMTgtMC43em0tMy4zOS0yLjFjMC4zLTEuMSAxLjE3LTIuMiAyLjM0LTIuMnMxLjI0IDEuMSAwLjkzIDIuMmgtMy4yN3oiLz48cGF0aCBkPSJtNTMuMjggODMuOThoMC41NSAwLjQ0bDAuOC0yLjljMC40My0xLjUgMC45OS0yLjQgMi4yOC0yLjQgMS4xNyAwIDEuMTEgMC44IDAuOCAybC0wLjg2IDMuM2gwLjQ5IDAuNWwwLjk5LTMuNWMwLjQzLTEuNyAwLjEtMi41LTEuMzYtMi41LTAuODcgMC0xLjY3IDAuNS0yLjM1IDEuMmwwLjMxLTEuMWgtMC40OS0wLjVsLTEuNiA1Ljl6Ii8+PHBhdGggZD0ibTY2LjQzIDc4LjQ4Yy0wLjU2LTAuMy0xLjExLTAuNS0xLjg2LTAuNS0xLjg1IDAtMy41MSAxLjEtNC4wMSAzLTAuNDkgMS44IDAuMjUgMy4xIDIuMzUgMy4xIDAuNjggMCAxLjQyLTAuMiAyLjEtMC42bDAuMTgtMC42aC0wLjFjLTAuNjggMC41LTEuMjMgMC44LTEuOTEgMC44LTEuMzYgMC0xLjk4LTEuMS0xLjU1LTIuNyAwLjM3LTEuMyAxLjM2LTIuNiAyLjg0LTIuNiAwLjM3IDAgMC44NyAwLjIgMS4wNSAwLjUgMC4xMyAwLjEgMC4xOSAwLjMgMC4yNSAwLjVoMC4xMmwwLjUtMC45eiIvPjxwYXRoIGQ9Im02OS4yNyA3OC4wOGgtMC41LTAuNDlsLTEuNjEgNS45aDAuNSAwLjQ5bDEuNjEtNS45em0wLjc0LTIuMWMwLjEtMC40LTAuMTktMC43LTAuNS0wLjctMC4zNyAwLTAuNjggMC4zLTAuOCAwLjctMC4xMiAwLjMgMC4xMiAwLjYgMC40OSAwLjYgMC4zMSAwIDAuNjgtMC4zIDAuODEtMC42eiIvPjxwYXRoIGQ9Im03NS4wNyA4MC4wOGMwLjM3LTEuNC0wLjEyLTIuMS0xLjQyLTIuMS0wLjc0IDAtMS40OCAwLjMtMi4yMiAwLjdsLTAuMTkgMC43aDAuMTljMC4xMi0wLjMgMC44LTAuOSAxLjY2LTAuOSAwLjkzIDAgMS4zNiAwLjUgMS4xMSAxLjUtMC4xOCAwLjYtMC41NSAwLjYtMS41NCAwLjgtMS4yMyAwLjItMi40MSAwLjQtMi43OCAxLjgtMC4yNCAwLjkgMC4zNyAxLjUgMS4yNCAxLjUgMC43NCAwIDEuMzYtMC4yIDIuMDQtMC43bDAuMTItMC4yYy0wLjEgMC44IDAuNDMgMC44IDEuMTEgMC44IDAuMTItMC4xIDAuMzEtMC4xIDAuMzctMC4ybDAuMTItMC4zYy0wLjggMC4yLTAuNjggMC0wLjU1LTAuNWwwLjc0LTIuOXptLTEuNjcgMi42Yy0wLjEgMC4xLTAuMzcgMC40LTAuNDMgMC40LTAuMzEgMC4zLTAuOCAwLjUtMS4xMSAwLjUtMC44IDAtMS4xNy0wLjQtMC45My0xLjIgMC4zMS0xLjEgMS42MS0xLjIgMi40Ny0xLjRoMC41bC0wLjUgMS43eiIvPjxwYXRoIGQ9Im04OC45NCA3NS40OGMtMC4xIDAtMC4yIDAuMS0wLjQgMC4xLTAuMSAwLTAuMS0wLjEtMC4zLTAuMWwtMS43IDYuNGgtMC4xbC00LjItNi40aC0wLjVsLTIuMiA4LjVoMC4zIDAuNGwxLjctNi43aDAuMmwzLjcgNS45YzAuMiAwLjMgMC40IDAuNyAwLjUgMC44aDAuM2wyLjMtOC41eiIvPjxwYXRoIGQ9Im05NC4wNCA4MC4wOGMwLjQtMS40LTAuMS0yLjEtMS40LTIuMS0wLjcgMC0xLjUgMC4zLTIuMiAwLjdsLTAuMiAwLjdoMC4xYzAuMi0wLjMgMC44LTAuOSAxLjgtMC45IDAuOSAwIDEuMyAwLjUgMSAxLjUtMC4xIDAuNi0wLjUgMC42LTEuNSAwLjgtMS4yIDAuMi0yLjQgMC40LTIuOCAxLjgtMC4zIDAuOSAwLjQgMS41IDEuMyAxLjUgMC43IDAgMS4zLTAuMiAyLTAuN2wwLjItMC4yYy0wLjIgMC44IDAuNCAwLjggMS4xIDAuOCAwLjEtMC4xIDAuMy0wLjEgMC4zLTAuMmwwLjEtMC4zYy0wLjcgMC4yLTAuNiAwLTAuNS0wLjVsMC43LTIuOXptLTEuNiAyLjZjLTAuMSAwLjEtMC40IDAuNC0wLjUgMC40LTAuMyAwLjMtMC44IDAuNS0xLjEgMC41LTAuOCAwLTEuMS0wLjQtMC45LTEuMiAwLjMtMS4xIDEuNi0xLjIgMi41LTEuNGgwLjRsLTAuNCAxLjd6Ii8+PHBhdGggZD0ibTEwMS4zIDc4LjQ4Yy0wLjYtMC4zLTEuMS0wLjUtMS44Ni0wLjUtMS44IDAtMy41IDEuMS00IDMtMC41IDEuOCAwLjIgMy4xIDIuMyAzLjEgMC43IDAgMS41LTAuMiAyLjEtMC42bDAuMTYtMC42Yy0wLjY2IDAuNS0xLjI2IDAuOC0xLjg2IDAuOC0xLjQgMC0yLTEuMS0xLjYtMi43IDAuMy0xLjMgMS40LTIuNiAyLjgtMi42IDAuNCAwIDAuODYgMC4yIDEuMDYgMC41IDAuMSAwLjEgMC4yIDAuMyAwLjIgMC41aDAuMWwwLjYtMC45eiIvPjxwYXRoIGQ9Im0xMDQuMSA3OC4wOGgtMC41LTAuNWwtMS42IDUuOWgwLjUgMC41bDEuNi01Ljl6bTAuNy0yLjFjMC4xLTAuNC0wLjEtMC43LTAuNC0wLjctMC40IDAtMC44IDAuMy0wLjkgMC43LTAuMSAwLjMgMC4yIDAuNiAwLjUgMC42IDAuNCAwIDAuNy0wLjMgMC44LTAuNnoiLz48cGF0aCBkPSJtMTA1IDgwLjk4Yy0wLjYgMS45IDAuNCAzLjEgMi4xIDMuMSAyIDAgMy41LTEuNSAzLjktMy4xIDAuNS0xLjgtMC40LTMtMi4xLTMtMS44IDAtMy40IDEuMi0zLjkgM3ptMy45LTIuNmMxLjMgMCAxLjMgMS40IDEuMSAyLjYtMC4zIDAuOS0xLjMgMi43LTIuNyAyLjdzLTEuNi0xLjMtMS4zLTIuNWMwLjQtMS40IDEuMy0yLjggMi45LTIuOHoiLz48cGF0aCBkPSJtMTExLjYgODMuOThoMC41IDAuNWwwLjgtMi45YzAuNC0xLjUgMS0yLjQgMi4yLTIuNHMxLjIgMC44IDAuOSAybC0wLjkgMy4zaDAuNSAwLjVsMS0zLjVjMC40LTEuNyAwLTIuNS0xLjQtMi41LTAuOSAwLTEuNyAwLjUtMi4zIDEuMmwwLjMtMS4xaC0wLjUtMC41bC0xLjYgNS45eiIvPjxwYXRoIGQ9Im0xMjMuNyA4MC4wOGMwLjQtMS40LTAuMS0yLjEtMS40LTIuMS0wLjcgMC0xLjUgMC4zLTIuMiAwLjdsLTAuMiAwLjdoMC4xYzAuMi0wLjMgMC44LTAuOSAxLjgtMC45IDAuOSAwIDEuMyAwLjUgMSAxLjUtMC4xIDAuNi0wLjUgMC42LTEuNSAwLjgtMS4yIDAuMi0yLjQgMC40LTIuOCAxLjgtMC4zIDAuOSAwLjQgMS41IDEuMiAxLjVzMS40LTAuMiAyLjEtMC43bDAuMS0wLjJjLTAuMSAwLjggMC41IDAuOCAxLjIgMC44IDAuMS0wLjEgMC4zLTAuMSAwLjMtMC4ybDAuMS0wLjNjLTAuOCAwLjItMC43IDAtMC41LTAuNWwwLjctMi45em0tMS43IDIuNmMwIDAuMS0wLjMgMC40LTAuNCAwLjQtMC4zIDAuMy0wLjggMC41LTEuMSAwLjUtMC44IDAtMS4xLTAuNC0wLjktMS4yIDAuMi0xLjEgMS42LTEuMiAyLjUtMS40aDAuNGwtMC41IDEuN3oiLz48cGF0aCBkPSJtMTI1IDgzLjk4aDAuNSAwLjVsMi41LTkuM2gtMC41LTAuNWwtMi41IDkuM3oiLz48cGF0aCBkPSJtMTM4LjkgNzQuNjhoLTAuNS0wLjVsLTEuMiA0LjVjLTAuMi0wLjctMC43LTEuMi0xLjctMS4yLTEuNiAwLTMgMS40LTMuNCAzLjEtMC42IDIgMC4yIDMgMS42IDMgMSAwIDEuOC0wLjQgMi41LTEuM2wtMC4zIDEuMmgwLjUgMC41bDIuNS05LjN6bS0yLjYgNi4yYy0wLjMgMS4yLTEuMiAyLjgtMi42IDIuOC0xLjMgMC0xLjQtMS4zLTEuMS0yLjQgMC4zLTEuMyAxLTIuOCAyLjYtMi44IDEuMyAwIDEuMyAxLjMgMS4xIDIuNHoiLz48cGF0aCBkPSJtMTQzLjEgODIuNjhjLTAuNCAwLjQtMS4yIDAuOS0yLjEgMC45LTEuNSAwLTEuOS0xLjItMS41LTIuNmgxLjhjMC44IDAgMS43IDAgMi42IDAuMSAwLjYtMi4xLTAuNC0zLjEtMS44LTMuMS0xLjggMC0zLjIgMS40LTMuNiAzLjEtMC42IDEuOSAwLjQgMyAyLjEgMyAwLjcgMCAxLjYtMC4zIDIuMy0wLjdsMC4yLTAuN3ptLTMuNC0yLjFjMC4zLTEuMSAxLjEtMi4yIDIuMy0yLjJzMS4yIDEuMSAxIDIuMmgtMy4zeiIvPjxwYXRoIGQ9Im0xNTIuNyA3Ni4wOGMxLjIgMCAyIDAuMSAyLjYgMC4yIDAtMC4yIDAtMC4zIDAuMS0wLjQgMC0wLjEgMC4xLTAuMyAwLjEtMC40aC02LjRjMCAwLjEgMCAwLjMtMC4xIDAuNCAwIDAuMSAwIDAuMi0wLjEgMC40IDAuOC0wLjEgMS41LTAuMiAyLjgtMC4ybC0yLjIgNy45aDAuNiAwLjZsMi03Ljl6Ii8+PHBhdGggZD0ibTE1Ny45IDgyLjY4Yy0wLjMgMC40LTEuMSAwLjktMiAwLjktMS41IDAtMi0xLjItMS41LTIuNmgxLjhjMC44IDAgMS43IDAgMi41IDAuMSAwLjctMi4xLTAuMy0zLjEtMS43LTMuMS0xLjggMC0zLjIgMS40LTMuNyAzLjEtMC41IDEuOSAwLjQgMyAyLjIgMyAwLjcgMCAxLjYtMC4zIDIuMi0wLjdsMC4yLTAuN3ptLTMuNC0yLjFjMC40LTEuMSAxLjItMi4yIDIuNC0yLjJzMS4yIDEuMSAxIDIuMmgtMy40eiIvPjxwYXRoIGQ9Im0xNTkuNSA4My45OGgwLjUgMC41bDIuNi05LjNoLTAuNS0wLjVsLTIuNiA5LjN6Ii8+PHBhdGggZD0ibTE2Ny42IDgyLjY4Yy0wLjQgMC40LTEuMiAwLjktMi4xIDAuOS0xLjUgMC0xLjktMS4yLTEuNC0yLjZoMS43YzAuOSAwIDEuNyAwIDIuNiAwLjEgMC42LTIuMS0wLjMtMy4xLTEuOC0zLjEtMS44IDAtMy4yIDEuNC0zLjYgMy4xLTAuNSAxLjkgMC40IDMgMi4xIDMgMC43IDAgMS42LTAuMyAyLjMtMC43bDAuMi0wLjd6bS0zLjQtMi4xYzAuNC0xLjEgMS4yLTIuMiAyLjQtMi4yczEuMiAxLjEgMC45IDIuMmgtMy4zeiIvPjxwYXRoIGQ9Im0xNzUuMiA3OC40OGMtMC41LTAuMy0xLjItMC41LTEuOS0wLjUtMS44IDAtMy41IDEuMS00IDMtMC41IDEuOCAwLjMgMy4xIDIuMyAzLjEgMC43IDAgMS41LTAuMiAyLjEtMC42bDAuMi0wLjZjLTAuNyAwLjUtMS4zIDAuOC0yIDAuOC0xLjMgMC0xLjktMS4xLTEuNS0yLjcgMC40LTEuMyAxLjQtMi42IDIuOC0yLjYgMC41IDAgMC45IDAuMiAxLjEgMC41IDAuMSAwLjEgMC4yIDAuMyAwLjIgMC41aDAuMmwwLjUtMC45eiIvPjxwYXRoIGQ9Im0xNzUuNSA4MC45OGMtMC43IDEuOSAwLjMgMy4xIDIuMSAzLjEgMiAwIDMuNC0xLjUgMy45LTMuMSAwLjQtMS44LTAuNC0zLTIuMS0zLTEuOCAwLTMuNSAxLjItMy45IDN6bTMuOC0yLjZjMS40IDAgMS40IDEuNCAxLjEgMi42LTAuMiAwLjktMS4yIDIuNy0yLjYgMi43LTEuNSAwLTEuNy0xLjMtMS4zLTIuNSAwLjMtMS40IDEuMi0yLjggMi44LTIuOHoiLz48cGF0aCBkPSJtMTgyIDgzLjk4aDAuNSAwLjVsMC45LTMuNmMwLjMtMC45IDAuNy0xLjcgMi0xLjcgMC45IDAgMS4yIDAuNSAwLjkgMS43bC0xIDMuNmgwLjUgMC41bDAuOS0zLjRjMC4yLTAuOCAwLjctMS45IDItMS45IDEuMSAwIDEuMSAwLjkgMC44IDJsLTAuOSAzLjNoMC41IDAuNWwwLjktMy41YzAuNC0xLjYgMC4yLTIuNS0xLjMtMi41LTAuOCAwLTEuNiAwLjQtMi4zIDEuMiAwLTAuOC0wLjYtMS4yLTEuNC0xLjItMC45IDAtMS42IDAuNC0yLjIgMS4ybDAuMi0xLjFoLTAuNS0wLjRsLTEuNiA1Ljl6Ii8+PHBhdGggZD0ibTE5OC45IDc4LjA4aC0wLjUtMC41bC0wLjkgMy40Yy0wLjIgMC45LTAuOCAyLTIuMSAyLTEuMSAwLTEuMy0wLjgtMC45LTJsMC45LTMuNGgtMC41LTAuNWwtMSAzLjdjLTAuNSAxLjYgMCAyLjMgMS41IDIuMyAwLjggMCAxLjYtMC40IDIuMi0xLjJsLTAuMyAxLjFoMC41IDAuNWwxLjYtNS45eiIvPjxwYXRoIGQ9Im0xOTkuMyA4My45OGgwLjUgMC41bDAuOC0yLjljMC40LTEuNSAxLTIuNCAyLjMtMi40IDEuMSAwIDEuMSAwLjggMC44IDJsLTAuOSAzLjNoMC41IDAuNWwxLTMuNWMwLjQtMS43IDAtMi41LTEuNC0yLjUtMC44IDAtMS42IDAuNS0yLjMgMS4ybDAuMy0xLjFoLTAuNS0wLjVsLTEuNiA1Ljl6Ii8+PHBhdGggZD0ibTIwOSA3OC4wOGgtMC40LTAuNWwtMS42IDUuOWgwLjUgMC41bDEuNS01Ljl6bTAuOC0yLjFjMC4xLTAuNC0wLjEtMC43LTAuNS0wLjctMC4zIDAtMC43IDAuMy0wLjggMC43LTAuMSAwLjMgMC4xIDAuNiAwLjUgMC42IDAuMyAwIDAuNy0wLjMgMC44LTAuNnoiLz48cGF0aCBkPSJtMjE1LjkgNzguNDhjLTAuNi0wLjMtMS4xLTAuNS0xLjktMC41LTEuOCAwLTMuNSAxLjEtNCAzLTAuNSAxLjggMC4zIDMuMSAyLjQgMy4xIDAuNyAwIDEuNC0wLjIgMi0wLjZsMC4zLTAuNmgtMC4xYy0wLjcgMC41LTEuMiAwLjgtMS45IDAuOC0xLjQgMC0yLTEuMS0xLjYtMi43IDAuNC0xLjMgMS40LTIuNiAyLjgtMi42IDAuNSAwIDEgMC4yIDEuMSAwLjUgMC4yIDAuMSAwLjIgMC4zIDAuMyAwLjVsMC42LTAuOXoiLz48cGF0aCBkPSJtMjIxLjEgODAuMDhjMC40LTEuNC0wLjEtMi4xLTEuNC0yLjEtMC44IDAtMS41IDAuMy0yLjMgMC43bC0wLjEgMC43aDAuMWMwLjItMC4zIDAuOC0wLjkgMS43LTAuOXMxLjQgMC41IDEuMSAxLjVjLTAuMiAwLjYtMC41IDAuNi0xLjUgMC44LTEuMyAwLjItMi40IDAuNC0yLjggMS44LTAuMiAwLjkgMC40IDEuNSAxLjIgMS41czEuNC0wLjIgMi4xLTAuN2wwLjEtMC4yYy0wLjEgMC44IDAuNCAwLjggMS4xIDAuOCAwLjEtMC4xIDAuMy0wLjEgMC40LTAuMmwwLjEtMC4zYy0wLjggMC4yLTAuNyAwLTAuNi0wLjVsMC44LTIuOXptLTEuNyAyLjZjMCAwLjEtMC40IDAuNC0wLjQgMC40LTAuMyAwLjMtMC44IDAuNS0xLjEgMC41LTAuOCAwLTEuMi0wLjQtMC45LTEuMiAwLjMtMS4xIDEuNi0xLjIgMi40LTEuNGgwLjVsLTAuNSAxLjd6Ii8+PHBhdGggZD0ibTIyMy4zIDg1LjE4IDAuMiAwLjFjMC4xIDAgMC4yLTAuMSAwLjMtMC4xIDAuMyAwIDAuNiAwLjEgMC41IDAuNXMtMC41IDAuNS0wLjkgMC41Yy0wLjIgMC0wLjUtMC4xLTAuNi0wLjFsLTAuNCAwLjRjMC40IDAuMSAwLjcgMC4xIDEgMC4xIDAuNCAwIDAuOCAwIDEuMy0wLjMgMC4yLTAuMiAwLjQtMC40IDAuNS0wLjcgMC4xLTAuNi0wLjQtMS0xLjItMC44bDAuNi0wLjhoLTAuNGwtMC45IDEuMnptNS02LjdjLTAuNS0wLjMtMS4xLTAuNS0xLjgtMC41LTEuOSAwLTMuNiAxLjEtNC4xIDMtMC40IDEuOCAwLjQgMy4xIDIuNCAzLjEgMC43IDAgMS40LTAuMiAyLjEtMC42bDAuMi0wLjZoLTAuMWMtMC42IDAuNS0xLjIgMC44LTEuOSAwLjgtMS40IDAtMi0xLjEtMS41LTIuNyAwLjMtMS4zIDEuMy0yLjYgMi44LTIuNiAwLjQgMCAwLjkgMC4yIDEgMC41IDAuMiAwLjEgMC4yIDAuMyAwLjMgMC41aDAuMWwwLjUtMC45eiIvPjxwYXRoIGQ9Im0yMzEgNzcuMDhjMC4xLTAuMiAwLjMtMC41IDAuNS0wLjUgMC41LTAuMiAwLjggMCAxLjEgMC4yIDAuMiAwLjEgMC40IDAuMyAwLjggMC4zIDAuNyAwIDEuMy0wLjcgMS42LTEuM2gtMC4zYy0wLjEgMC4yLTAuMiAwLjMtMC4zIDAuNC0wLjMgMC4yLTAuNyAwLjItMC45IDAuMi0wLjEtMC4xLTAuMy0wLjEtMC40LTAuMy0wLjIgMC0wLjMtMC4xLTAuNS0wLjItMC44LTAuMi0xLjYgMC40LTEuOSAxLjJoMC4zem0tMi40IDMuOWMtMC42IDEuOSAwLjQgMy4xIDIuMSAzLjEgMi4xIDAgMy41LTEuNSAzLjktMy4xIDAuNS0xLjgtMC40LTMtMi0zLTEuOCAwLTMuNSAxLjItNCAzem0zLjgtMi42YzEuNCAwIDEuNSAxLjQgMS4yIDIuNi0wLjMgMC45LTEuMyAyLjctMi43IDIuN3MtMS42LTEuMy0xLjItMi41YzAuMy0xLjQgMS4xLTIuOCAyLjctMi44eiIvPjxwYXRoIGQ9Im0yNDAuMSA4Mi42OGMtMC40IDAuNC0xLjIgMC45LTIgMC45LTEuNiAwLTItMS4yLTEuNS0yLjZoMS43YzAuOSAwIDEuNyAwIDIuNSAwLjEgMC43LTIuMS0wLjMtMy4xLTEuNy0zLjEtMS44IDAtMy4xIDEuNC0zLjYgMy4xLTAuNSAxLjkgMC4zIDMgMi4xIDMgMC44IDAgMS42LTAuMyAyLjMtMC43bDAuMi0wLjd6bS0zLjQtMi4xYzAuNC0xLjEgMS4yLTIuMiAyLjQtMi4yczEuMiAxLjEgMC45IDIuMmgtMy4zeiIvPjxwYXRoIGQ9Im0yNDEuNiA4Mi43OGMtMC4xIDAuMy0wLjMgMC42LTAuNSAwLjkgMC40IDAuMyAwLjkgMC40IDEuNCAwLjQgMS4xIDAgMi41LTAuNiAyLjgtMS45IDAuNS0yLTIuNi0xLjItMi4yLTIuOCAwLjItMC43IDAuOC0xIDEuNC0xIDAuNSAwIDAuOCAwLjQgMC44IDAuOGgwLjJjMC4yLTAuMyAwLjMtMC42IDAuNS0wLjgtMC4yLTAuMi0wLjctMC40LTEuMy0wLjQtMS4xIDAtMi4yIDAuNy0yLjUgMS44LTAuNiAyLjIgMi43IDEuMiAyLjIgMi44LTAuMiAwLjYtMC45IDEuMS0xLjUgMS4xcy0xLjEtMC40LTEuMy0wLjl6Ii8+PC9nPjxjaXJjbGUgY3k9IjQ3LjQ4IiBjeD0iMjUuMzMiIHI9IjE3LjYyIiBmaWxsPSJ1cmwoI2EpIi8+PC9nPjwvc3ZnPg=="></div>
    '''

    html += prel()

    html += f'''
<p class="Item_Nivel1">Identificação da prestadora</p>

<table border="1" style="border-collapse:collapse;color:#000000;font-family:&quot;Times New Roman&quot;;font-size:medium;font-style:normal;font-variant-ligatures:normal;font-weight:400;margin-left:auto;margin-right:auto;text-align:start;text-decoration-color:initial;text-decoration-style:initial;text-decoration-thickness:initial;white-space:normal;width:90%;">
	<thead>
		<tr>
			<th scope="col" style="background-color: rgb(238, 238, 238); width: 839px;">
			<p class="Tabela_Texto_Centralizado">1.1. Denominação/Razão Social (Matriz)</p>
			</th>
			<th scope="col" style="background-color: rgb(238, 238, 238); width: 976px;">
			<p class="Tabela_Texto_Centralizado">1.2 CNPJ</p>
			</th>
		</tr>
	</thead>
	<tbody>
		<tr>
			<td style="width:839px">
			<p class="Tabela_Texto_Centralizado">{relatorio_final['razao-social']}</p>
			</td>
			<td style="width:839px">
			<p class="Tabela_Texto_Centralizado">{relatorio_final['cnpj-matriz']}</p>
			</td>
		</tr>
	</tbody>
</table>

<p class="Item_Nivel1">ANO FISCAL</p>

<p class="Item_Nivel2">{relatorio_final['ano-fiscal']}</p>

<p class="Item_Nivel1">Análise da documentação</p>

<p class="Item_Nivel2">Este item visa realizar uma análise preliminar automatizada da documentação enviada pela prestadora em resposta ao Requerimento de Informações. O objetivo é identificar e verificar o status de cada escrituração enviada pela prestadora junto à Receita Federal do Brasil, além de detectar possíveis arquivos ausentes.</p>

<p class="Item_Nivel2">Os arquivos enviados pela prestadora foram processados e, quando necessário, descompactados, totalizando {str(relatorio_final['arquivos']['total'])} arquivos preparados para avaliação.</p>

<p class="Item_Nivel2">A consulta à Receita Federal do Brasil foi feita em {relatorio_final['data-da-consulta']}.</p>
    '''

    html += tblcnpjs() 

    html += semassinatura()

    html += mes_incompleto()

    html += outrosanos() 

    html += outroscnpjs() 

    html += diversos()

    html += relmodulos()
    
    # html += relecd()

    # html += relecf()

    # html += relefdcont()

    # html += relefdii()

    # html += rellfpd()

    html += relconcl()

    html += '''
</body></html>
    '''

    path =  f"{log_}/{relpre}{pathprestok}.html"
    print(path)
    with open(path, 'w', encoding="utf-8") as file:
        file.write(html)

    path =  f"{log_}/ultimo_relatorio.html"
    print(path)
    with open(path, 'w', encoding="utf-8") as file:
        file.write(html)


    path =  f"{log_}/{relpre}{pathprestok}.md"
    print(path)
    with open(path, 'w', encoding="utf-8") as file:
        file.write(md(html))

    path =  f"{log_}/ultimo_relatorio.md"
    print(path)
    with open(path, 'w', encoding="utf-8") as file:
        file.write(md(html))


    salva_json(f"template{pathprestok}" ,str(json.dumps(fmt)))


def copia_arquivos():

    # rever com atenção se  pandas.DataFrame.to_html dá todas estas opções de formatação condicional
    # pandas.DataFrame.to_clipboard via flet ?

    global cntanon, cntanon0, res_val_r, res_val, pastaTemp, fmt, vpath, pasta_nok, pasta_ok, log_, tipos, errcon, data_, maxpath, cnpj_ , ano_, pathprestok, res_brutos, expandida, filtrada



    # desvincular da gui
    salva_offline('data_', data_)
    salva_offline('cnpj_', cnpj_)
    salva_offline('ano_', ano_)
    salva_offline('prest_', prest_)

    title = f"{data_} para a prestadora {prest_} e o ano fiscal {ano_}"
    #pathprestok = f"{re.sub(r"[^A-Za-z0-9_()]", "",cnpj_)}_{ano_}"
    with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
        file.write(f"\nProcessando, formatando e salvando relatorios")

    if True: #try:
        ### ini down
        # tabela bruta
        #dtf = res_brutos # pd.read_json(le_offline('res_brutos',{})) 
        # dtf = res_val # res_val # res_val_r
        # dtf = dtf.reset_index()  # make sure indexes pair with number of rows
        debug(f"pasta_ok: {pasta_ok}")
        debug(f"pasta_nok: {pasta_nok}")
        Path(pasta_ok).mkdir(parents=True, exist_ok=True)
        Path(pasta_nok).mkdir(parents=True, exist_ok=True)

        for index, row in res_brutos.iterrows():

            debug(f"str(index+1): {str(index+1)}")
            debug(f"Prestadora: {row['Prestadora']}")

            #m = re.search(r'(file:///.*)\n', row['Arquivo Temporário'])

            # p = urlparse(m.group(1))
            # path = unquote(os.path.abspath(os.path.join(p.netloc, p.path)))

            p = urlparse(row['Arquivo Temporário']) # urllib.parse.unquote(fileuri) # urlparse(fileuri)
            if os.name == 'posix':
                path = str(unquote("/" + p.netloc + "/" + p.path))[2:]
            else:    
                path = str(unquote("" + p.netloc + "/" + p.path))[2:] #  ? verificar e corrigir // path = str(unquote("/" + p.netloc + "/" + p.path))[2:] #

            debug(f"debug path: {path}")
            uf = row['UF']
            if row['UF'] == "":
                uf = "_" # sem feito
                debug("inconsistência em UF")

            # tmpdt = datetime.strptime(data_, "%d/%m/%Y %H:%M:%S")
            # dtformat = iduuid # tmpdt.strftime('%Y%m%d%H%M%S')

            #fmtprest = fmtname(row['Prestadora'])

            tmp1 = fmtnome(f"{row['Prestadora']}{str(row['Ano Fiscal'])}_") + f"{iduuid}" #re.sub(r"[^A-Za-z0-9_]", "", f"{row['Prestadora']}{str(row['Ano Fiscal'])}{dtformat}" ) # fmtprest + "" + str(row['Ano Fiscal']))  + "_" + dtformat + ""
            tmp2 = re.sub(r"[^A-Za-z0-9_()]", "", row['Tipo'] + "_" + uf + "_" + pycpfcnpj.cpfcnpj.clear_punctuation(row['CNPJ']) + "_" + str(index+1)  + "_" ) 
            #tmp2 =  row['Tipo'] + "_" + uf + "_" + pycpfcnpj.cpfcnpj.clear_punctuation(row['CNPJ']) + "_" + str(index+1)  + "____" + Path(path).stem
            debug(f"tmp1: {tmp1} tmp2: {tmp2} ")

            tmp3 = re.sub(r"[^A-Za-z0-9_()]", "", Path(path).stem)
            
            n1, n2 = respostaok(row['Resultado da Validação']) # tmp2 = re.sub(r"[^A-Z]", "", tmp)
            
            if row['Prestadora'].find("Erro") == -1 and n1 == 1:
                pathprestok = tmp1
                tmp4 = ".SituacaoOk"
                Path(pasta_ok + "/" + tmp1).mkdir(parents=True, exist_ok=True)
                path0 = pasta_ok + "/" + tmp1 + "/" + tmp2
                n =  0 - maxpath + len(path0) + len(tmp4)
                path0 += tmp3[n:]
                path0 +=  tmp4
                debug(f"path: {path} path0: {path0} ")
                shutil.copy(path, path0 )

            else:
                tmp4 = ".SituacaoNaoOk"
                Path(pasta_nok + "/" + tmp1).mkdir(parents=True, exist_ok=True)
                path0 = pasta_nok + "/" + tmp1 + "/" + tmp2
                n =  0 - maxpath + len(path0) + len(tmp4)
                path0 += tmp3[n:]
                path0 += tmp4
                debug(f"path: {path} path0: {path0} ")
                shutil.copy(path, path0 )

            # atualiza temporarios
            res_brutos.at[index,'Arquivo Temporário'] = str(Path(path0).as_uri())
    
        ### salva res_brutos já atualizado
        salva_json(f"dataframe-tabela-bruta_{pathprestok}",res_brutos.to_json())
        # remove para atualizar origem do arquivo

        path =  f"{log_}/ultimo_relatorio_tabela_bruta.html"
        print(path)
        with open(path, 'w', encoding="utf-8") as file:
            file.write(res_brutos.to_html())




#         inihtml = """<!DOCTYPE html>
# <html lang="en">
# <head>
#     <meta charset="UTF-8">
#     <meta name="viewport" content="width=device-width, initial-scale=1.0">"""
#         inihtml += f"<title>Relatório gerado em {title}</title>"
#         inihtml += """<style>

#         html, body, table {
#             zoom: 85%;
#         }
#         @media print {
#             html
#             {
#                 zoom: 50%;
#             }
#             @page
#             {
#                 size: 297mm 210mm; /* landscape */
#                 /* you can also specify margins here: */
#                 margin: 250mm;
#                 margin-right: 450mm; /* for compatibility with both A4 and Letter */
#             }
#             body {
#                 margin: 0;
#                 padding: 20mm; /* Add padding for print */
#                 -webkit-print-color-adjust: exact;
#                 color-adjust: exact;
#             }
#             table {
#                 width: 100%;
#                 border-collapse: collapse;
#             }
#             th, td {
#                 border: 1px solid black;
#                 padding: 8px;
#                 text-align: left;
#             }
#             th {
#                 background-color: #f2f2f2 !important;
#             }
#         }
#         .tooltip {
#         position: relative;
#         display: inline-block;
#         cursor: pointer;
#         }

#         .tooltip .tooltip-text {
#         visibility: hidden;
#         opacity: 0;
#         position: absolute;
#         top: 100%;
#         left: 50%;
#         transform: translateX(-50%);
#         background-color: #f1f1f1;
#         color: #333;
#         padding: 5px;
#         border-radius: 4px;
#         box-shadow: 0 2px 5px rgba(0, 0, 0, 0.3);
#         white-space: nowrap;
#         transition: opacity 0.3s, visibility 0.3s;
#         }

#         .tooltip:hover .tooltip-text {
#         visibility: visible;
#         opacity: 1;
#         }
#     </style>
# </head>
# <body>"""

#         inihtml += f"<h1>Relatório gerado em {title}</h1>"
#         inihtml += "<table>"

#         fimhtml = '</tbody></table></body></html>'

#         # debug(f"copia_arquivos de {cntanon0} linhas para {path}")

#         html = inihtml
                    
#         html += '\n<thead><tr>'

#         for header in dtf.columns:
#             html += '<th>'
#             html += str(header)
#             html += '</th>'


#         html += '</tr></thead><tbody>'


#         for index, row in dtf.iterrows():

#             html += '\n<tr>'

#             for header in dtf.columns:

#                 css = 'style="background-color:0xeeeeee !important;"'
#                 try:
#                     if (row[header]) >= 1:
#                         css =  'style="background-color:' + fmt[header]["1"] + ' !important;"'  #fmt[header]["1"]
#                     elif (row[header]) == 0:
#                         css = 'style="background-color:' + fmt[header]["0"] + ' !important;"'  #fmt[header]["0"]
#                     else:
#                         css = 'style="background-color:' + fmt[header]["-1"] + ' !important;"'  #fmt[header]["-1"]  
#                 except:
#                     css = 'style="background-color:0xeeeeee !important;"'  #'0xeeeeee'

            

#                 html += '<td ' + css + '>'
#                 html += '<div class="tooltip">'
#                 html += "<br />".join(str(row[header]).split("\n")) # str(row[header])
#                 html += '<span class="tooltip-text">Detalhes a exibir</span></div>'
#                 html += '</td>'

#             html += '</tr>'

#         html += fimhtml

#         with open(path, 'w', encoding="utf-8") as file:
#             file.write(html)

########## testes por tipos dtf usar exp

        relatorio = "**Relatório**  \n"



        tmpcnt = res_brutos[res_brutos['Prestadora'].str.contains('Erro') == False]
        arqesc = len(tmpcnt.index)
        rel0 = res_brutos.groupby(['Prestadora', 'UF', 'CNPJ', 'Ano Fiscal'])['UF'].agg(['count'])
        rel0.reset_index( inplace = True)
        cols = ['Prestadora','UF','CNPJ', 'Ano Fiscal','contagem']
        rel0.columns =  cols
        rel0.index = rel0.index + 1
        rel1 = rel0[(rel0['Prestadora'].str.contains('Erro') == False)]
        rel = rel1[['UF','CNPJ','contagem']]

        relerrs = ""
        relerr = rel0[rel0['Prestadora'].str.contains('Erro') == True]
        if len(relerr.index) > 0:
            relerrs += "Também foram encontrados estes arquivos em outros formatos não identificados ou fora do escopo deste CNPJ da matriz e Ano Fiscal:  \n"
            # relerrs += f"\n\n{relerr.to_string()}  \n\n\n"
            for index, row in relerr.iterrows(): # res_val_r0.columns =  cols
                relerrs += str(index)
                relerrs += "    "            
                for column in relerr:
                    relerrs += str(row[column])
                    relerrs += "    "
                relerrs += "  \n" 

        rels = "" # f"{rel.to_string(columns=['CNPJ', 'UF', 'count'])}"
        # for column in rel:
        #     rels += column
        #     rels += "    "
        # rels += "  \n"

        for index, row in rel.iterrows(): # res_val_r0.columns =  cols
            rels += str(index)
            rels += "    "            
            for column in rel:
                rels += str(row[column])
                rels += "    "
            rels += "  \n" 





        debug(f"len(rel.index): {len(rel.index)}")
        debug(rel)
        debug("\n\n\n")

        err = ""
        if len(rel.index) < 1:
            err += "**Não foram encontrados dados para este CNPJ da matriz e Ano Fiscal na pasta indicada.**  \n"
        else:
            pass
                

        if errcon:
            err += "**Ocorreu falha de conexão com a SRF: tente novamente para a verificação correta.**  \n"
        else:
            pass  

        resumo = f''
        # f"{data_} para a prestadora {prest_} e o ano fiscal {ano_}"

        relatorio += f'Os resultados foram obtidos em consulta à SRF feita em {title}, a partir dos arquivos recebidos.  <span style="color:blue">some *blue* text</span>\n'
        relatorio += f"{err}"
        resumo += f"**Estatísticas**  \nForam selecionados {arqesc} arquivos úteis para o foco da atividade dentre {str(cntanon)} processados. Contagem por UF e CNPJ dos selecionados:  \n{rels}  "
        resumo += f"{relerrs}"

        ###
        ### Detalhamento do relatório descritivo a partir da tabela expandida
        ###
        
        dtf = expandida
        # dtf ==> expandida

        for tipo in tipos: # verifica em separado para cada classificação por tipo reconhecido
            ufsemarq = []
            #res = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['Janeiro'] != 0) & (dtf['Fevereiro'] != 0) & (dtf['Março'] != 0) & (dtf['Abril'] != 0) & (dtf['Maio'] != 0) & (dtf['Junho'] != 0) & (dtf['Julho'] != 0) & (dtf['Agosto'] != 0) & (dtf['Setembro'] != 0) & (dtf['Outubro'] != 0) & (dtf['Novembro'] != 0) & (dtf['Dezembro'] != 0) ]
            res0 = dtf.loc[(dtf['Tipo'] == tipo)]
            debug(f"*** tipo {tipo} {len(res0.index)}:")

            if len(res0.index) > 0: # contém um ou mais arquivos para esta classificação
                
                cntuf = 0
                tstcnpj = ""
                tstuf = ""
                cnpjtmp = ""
                naofoi = ""
                for index, row in res0.iterrows():
                    cntuf = cntuf + 1
                    uf = row['UF']   
                    cnpj = row['CNPJ']      
                    if uf == "  " or uf == "":
                        uf == "  "
                        uftxt = f" nacional e CNPJ {cnpj}"
                    else:
                        uftxt = f"na UF {uf} e CNPJ {cnpj}"  

                    # este teste só funciona se dataframe estiver ordenado 
                    if tstuf != uf:
                        tstcnpj = ""
                        tstuf = uf
                    if tstcnpj != cnpj:
                        if tstcnpj != "":
                            cnpjtmp = f" Para a escrituração do tipo {tipo} na UF {uf}, foi encontrado mais de um CNPJ.  \n"
                        else:
                            pass   
                        tstcnpj = cnpj
                     

                    res1 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == uf) & ((dtf['Janeiro'] != 0) & (dtf['Fevereiro'] != 0) & (dtf['Março'] != 0) & (dtf['Abril'] != 0) & (dtf['Maio'] != 0) & (dtf['Junho'] != 0) & (dtf['Julho'] != 0) & (dtf['Agosto'] != 0) & (dtf['Setembro'] != 0) & (dtf['Outubro'] != 0) & (dtf['Novembro'] != 0) & (dtf['Dezembro'] != 0)) ]

                    if len(res1.index) == 1:
                        completo = True
                        relatorio += f" Para a escrituração do tipo {tipo} {uftxt}, foram verificados arquivos cobrindo todos os meses do ano.  \n"
                    else:
                        res2 = dtf.loc[(dtf['Tipo'] == tipo) & (dtf['UF'] == uf) & ((dtf['Janeiro'] != 0) | (dtf['Fevereiro'] != 0) | (dtf['Março'] != 0) | (dtf['Abril'] != 0) | (dtf['Maio'] != 0) | (dtf['Junho'] != 0) | (dtf['Julho'] != 0) | (dtf['Agosto'] != 0) | (dtf['Setembro'] != 0) | (dtf['Outubro'] != 0) | (dtf['Novembro'] != 0) | (dtf['Dezembro'] != 0)) ]
                        if len(res2.index) == 0:
                            ufsemarq.append(uf)
                            naofoi += f"{uf}, "
                        else:
                            
                            relatorio += f" Para a escrituração do tipo {tipo} {uftxt}, foram verificados arquivos somente para"


                            mesant = ""
                            plural = False
                            rrel = ""
                            for mes in meses:
                                if res2[mes].iloc[0] > 0:
                                    if mesant == "":
                                        mesant = mes.lower()
                                    else:
                                        if plural:
                                            rrel += ", "
                                        else:
                                            rrel += " "
                                        rrel += mesant
                                        mesant = mes.lower()
                                        plural = True

                            if plural:
                                relatorio += " os meses "
                            else:
                                relatorio += " o mês "
                            relatorio += rrel
                            if plural:
                                relatorio += " e " 
                                relatorio += mesant 
                            else:
                                relatorio += mesant    

                            relatorio += ", faltando" 

                            mesant = ""
                            plural = False
                            rrel = ""     
                            for mes in meses:
                                if res2[mes].iloc[0] == 0:
                                    if mesant == "":
                                        mesant = mes.lower()
                                    else:
                                        if plural:
                                            rrel += ", "
                                        else:
                                            rrel += " "
                                        rrel += mesant
                                        mesant = mes.lower()
                                        plural = True

                            if plural:
                                relatorio += " os meses "
                            else:
                                relatorio += " o mês "
                            relatorio += rrel
                            if plural:
                                relatorio += " e " 
                                relatorio += mesant 
                            else:
                                relatorio += mesant    
                                   

                            relatorio += ".  \n"  


                    if uf == "  " or uf == "":
                        uf = "--"
 

                if uf == "  " or uf == "":
                    uf = "--"

                if cntuf == 0:
                    relatorio += f" Para a escrituração do tipo {tipo}, não foi verificado nenhum arquivo.  \n" 
                else:
                    pass

                if naofoi != "":
                    relatorio += f" Para a escrituração do tipo {tipo} nas UFs {naofoi}não foi verificado nenhum arquivo.  \n"
                else:
                    pass

                relatorio += cnpjtmp

            else:
                debug(f"não contém arquivo classificado como {tipo}")


        relatorio += ""
        relatorio += resumo
        #relatorio += links

        path =  f"{log_}/{relpre}{pathprestok}.old.md"
        with open(path, 'w', encoding="utf-8") as file:
            file.write(relatorio)

        with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
            file.write(f"\nRelatório salvo em '{str(Path(path).as_uri())}' ")

  

        ### fim down  
    else:#except:
        debug("Algum arquivo temporário foi apagado por outro aplicativo ou algum erro.")
        sys.exit()

    remove_json(f"dataframe-tabela-expandida_{pathprestok}")
    expandida = pd.DataFrame()

# inicia nova validação na pasta
def descompacta_e_verifica():

    global arquivosenha, pastaRaiz, pastaTemp, vpcnt, cntanon0, tcodec, validados, cnpj_, ano_, prest_, log_, data_, tipos, errcon, res_brutos, listatemporaria, res_val_r, res_val, vpath

    if len(ano_) == 4 and int(ano_) > 2010:
        pass
    else:
        debug("Ano inválido")  
        sys.exit()  

    c = ""
    if pycpfcnpj.cnpj.validate(re.sub(r"[^0-9]", "", cnpj_)):
        c = re.sub(r"[^0-9]", "", cnpj_) # # pycpfcnpj.cpfcnpj.clear_punctuation(cnpj_ft.value)
    else:
        debug("CNPJ inválido")
        sys.exit()

    cnpj_ = c[0:2] + "." + c[2:5] + "." + c[5:8] + "/" + c[8:12] + "-" + c[12:14]


    cnpj_client = cnpj.CNPJClient()
    try:
        res = cnpj_client.cnpj(pycpfcnpj.cpfcnpj.clear_punctuation(cnpj_)) 
        prest_ = res['razao_social']
    except:
        errcon = True
        debug("Erro em consulta via biblioteca cnpj.CNPJClient")
        prest_ = ""   

    # apaga todos resultados
    listatemporaria.clear()
    vpath.drop(vpath.index, inplace=True)
    # res_val.drop(res_val.index, inplace=True)
    # res_val_r.drop(res_val_r.index, inplace=True)
    shutil.rmtree(pasta_in, ignore_errors=True) # pastaTemp+"/out"
    remove_json(f"dataframe-tabela-bruta_{pathprestok}")
    remove_json(f"dataframe-tabela-filtrada_{pathprestok}")
    remove_json(f"dataframe-tabela-expandida_{pathprestok}")
    remove_offline('cnpj_')
    remove_offline('ano_')
    remove_offline('prest_')

    with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
        file.write("\nDescompactando e contando arquivos")

    trata_list_dir_recursive(pastaRaiz,"","",ddeep) # só conta total

    with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
        file.write(f"\nTotal de arquivos reconhecidos: {cntanon0}. Iniciando a validação ..")

    senha = generate_password(24)

    trata_list_dir_recursive(pasta_in,"",senha,ddeep)

    # já salva organizada res_val_r0 = res_val_r0.reset_index()
    res_brutos = pd.DataFrame(listatemporaria)
    res_brutos = res_brutos.sort_values(['Prestadora', 'Ano Fiscal', 'Tipo', 'UF', 'CNPJ'], ascending=[True, True, True, True, True])
    res_brutos = res_brutos.reset_index(drop=True)
    res_brutos.index = res_brutos.index + 1
    res_brutos.reset_index( inplace = True)
    # salva após ajuste posterior em copia_arquivos
    # print(res_brutos)
    #salva_json('res_brutos_debug',res_brutos.to_json())



# if os.path.exists(f"{log_}/debug.log"):
#   os.remove(f"{log_}/debug.log")

debug("############################################################################################################")
debug(f"Executando {appver} {sshenv} {str(datetime.today())} ") # 
debug("############################################################################################################")
debug(os.environ)

if __name__ == "__main__":

    log(f"Arguments: {sys.argv}" )
    args = docopt(__doc__, version="202412271800")



    schema = Schema(
        {
            "PASTA-DE-ENTRADA": And(
                Or( None, os.path.exists ),
                error="Erro: PASTA-DE-ENTRADA inexistente, retorne e tente novamente",
            ),
            "ARQUIVO": And(
                Or( None, Use(str) ),
                error="Erro: ARQUIVO não implementado, retorne e tente novamente",
            ),
            "CNPJ-MATRIZ": And(
                Or( None, lambda n: pycpfcnpj.cnpj.validate(n) ),
                error="Erro: CNPJ-MATRIZ inválido, retorne e tente novamente",
            ),
            "ANO-FISCAL": And(
                Or(None, Use(int) ),
                error="Erro: ANO-FISCAL inválido, retorne e tente novamente",
            ),
            "UUID": And(
                Or(None, Use(str) ),
                error="Erro: UUID inválido, retorne e tente novamente",
            ),
            "--query": Or( None, False, True ),
            "--dir": Or( None, False, True ),
            "--file": Or( None, False, True ),
            "--log": Or( None, False, True ),
            "--relatorios": Or( None, False, True ),
            "PATH-INI": Or( None, Use(str) ),
            "QUERY": Or( None, Use(str) ),
        }
    )


    try:
        tmp = str(uuid.UUID(args['UUID']).time)
        iduuid = args['UUID']
    except:
        iduuid = '_erro_00000000000000000000000000000000'

    try:
        args = schema.validate(args)
    except SchemaError as e:
        log(e)
        exit(e)


    if args['--query']:
        print(f"implementando --query")
        sys.exit()

    elif args['--dir']:
        print(lista_pasta(args['PATH-INI']))
        sys.exit()

    elif args['--file']:
        print(get_file(args['ARQUIVO']))
        sys.exit()

    elif args['--relatorios']:
        print(lista_relatorios())
        sys.exit()

    elif args['--log']:
        print(tail_log(args['UUID']))
        sys.exit()

    else:
        pass   

    pastaRaiz = args['PASTA-DE-ENTRADA']
    cnpj_ = args['CNPJ-MATRIZ']
    ano_ = str(args['ANO-FISCAL'])
    iduuid = args['UUID']

    argslast = []
    argslast.append(pastaRaiz)
    argslast.append(cnpj_)
    argslast.append(ano_)
    log(json.dumps(argslast))
    salva_json('args-last',json.dumps(argslast))

    # print("\n\ndebug:\n")
    # print(args)
    # #sys.exit()

    prest_ = "" # sys.argv[5]

    pasta_ok = log_ + "/ARQS_SIT_OK"
    pasta_nok = log_ + "/ARQS_SIT_NOT_OK"

    #Path(pastaRaiz).mkdir(parents=True, exist_ok=True)
    Path(pasta_in).mkdir(parents=True, exist_ok=True)
    Path(pastaTemp).mkdir(parents=True, exist_ok=True)
    Path(log_).mkdir(parents=True, exist_ok=True)
    Path(pasta_ok).mkdir(parents=True, exist_ok=True)
    Path(pasta_nok).mkdir(parents=True, exist_ok=True)


    # atual = datetime.now()
    # atual.strftime("%d/%m/%Y, %H:%M:%S")
    data0 = datetime.now()
    data_ = data0.strftime("%d/%m/%Y %H:%M:%S")

    # id_data = {}
    # id_data['id'] = data0.strftime('%Y%m%d%H%M%S')
    # print(f"{json.dumps(id_data)}\n")

    remove_offline('res_brutos')

    with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
        file.write( "\nData da consulta na SRF: " + str(datetime.today()) + "")


    with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
        file.write("\n'" + "','".join(sys.argv[:]) + "'")

    descompacta_e_verifica()
    gera_dataframes("expandida") # preliminar necessário para primeira etapa
    gera_dataframes("filtrada") # preliminar necessário para primeira etapa
    copia_arquivos()
    relatorio_json()
    relatorio_sei()
    gera_dataframes("expandida") # atualiza Origem do arquivo
    #gera_dataframes("filtrada") # atualiza Origem do arquivo


    with open(f"{log_}/{iduuid}.log", 'a', encoding="utf-8") as file:
        #file.write( f"\n{str(datetime.today())}")
        file.write( f"\nConcluido Relatorio {pathprestok}")



