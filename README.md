# Automating Windows Server on Azure with Terraform, Ansible & CI/CD

Este repositório contém um laboratório completo de **Infraestrutura como Código (IaC)**, **Gerenciamento de Configuração** e **Entrega Contínua (CI/CD)**. O objetivo do projeto é provisionar uma infraestrutura na nuvem da Microsoft Azure e configurar automaticamente um servidor web (IIS) em uma máquina Windows Server 2022, tudo orquestrado via GitHub Actions.

## Arquitetura do Projeto

O projeto está dividido em três pilares fundamentais:

1. **Infraestrutura (Terraform):** Provisionamento de toda a base na Azure (Resource Group, VNet, Subnet, Public IP Standard, NSG com portas 80 e 5985 liberadas, NIC e a VM Windows Server). Uma *Custom Script Extension* injeta um script PowerShell no boot para habilitar e configurar o protocolo WinRM.
2. **Configuração (Ansible):** Utilização de módulos nativos do Ansible (`win_feature`, `win_service`, `win_copy`) para conectar no servidor via WinRM, instalar o IIS de forma idempotente, configurar o serviço e realizar o deploy de uma página HTML personalizada.
3. **Orquestração (GitHub Actions):** Uma esteira de CI/CD que, a cada push na branch `main`, levanta um *runner* Ubuntu, cria um ambiente virtual Python (VENV) isolado para instalar o Ansible e a biblioteca `pywinrm`, monta o arquivo de inventário dinamicamente resgatando credenciais seguras do GitHub Secrets e dispara o playbook contra a Azure.

## Tecnologias Utilizadas

* **Nuvem:** Microsoft Azure
* **IaC:** Terraform (HCL)
* **Gerência de Configuração:** Ansible
* **CI/CD:** GitHub Actions
* **Sistemas Operacionais:** Linux (Runner CI) interagindo com Windows Server 2022 (Alvo)
* **Linguagens/Protocolos:** YAML, PowerShell, WinRM, Python

## Estrutura do Repositório

```text
├── .github/workflows/
│   └── deploy.yml          # Pipeline de CI/CD
├── ansible/
│   ├── playbook.yml        # Automação da instalação do IIS e Deploy
│   └── inventory.ini       # Ignorado no Git (gerado dinamicamente no CI)
├── terraform/
│   └── main.tf             # Declaração dos recursos da Azure
└── README.md
Como Reproduzir este Laboratório
1. Provisionando a Infraestrutura (Localmente)
Navegue até a pasta do Terraform, autentique-se na sua conta da Azure e crie os recursos:

Bash
cd terraform
az login --use-device-code
terraform init
terraform apply -auto-approve
Aguarde a finalização. O Terraform retornará o IP Público gerado no terminal.

2. Configurando o CI/CD (GitHub Secrets)
Para que o pipeline funcione sem expor senhas no código, cadastre as seguintes variáveis em Settings > Secrets and variables > Actions no seu repositório:

AZURE_VM_IP: O IP público gerado pelo Terraform.

WIN_USER: O usuário da VM (ex: adminuser).

WIN_PASSWORD: A senha configurada no arquivo do Terraform.

3. Disparando a Esteira
Qualquer commit na branch main irá acionar o fluxo definido em .github/workflows/deploy.yml. O runner fará a instalação do ambiente e executará o comando:

Bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
4. Limpeza (Evitando Custos)
Após os testes, destrua a infraestrutura para não consumir créditos:

Bash
cd terraform
terraform destroy -auto-approve
Desenvolvido como prova de conceito para integração de ambientes híbridos (Linux gerenciando Windows) e esteiras modernas de DevOps.

Criado por João Breno
