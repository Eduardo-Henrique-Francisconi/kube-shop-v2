# 0. Demanda, componentes e solução

## 0.1 Interpretação da demanda (escopo Zibiska Korp v1.2)

A Zibiska Korp precisa publicar o **KubeShop** (frontend React servido pelo Nginx, API Node.js/Express e MongoDB autenticado com persistência) na nuvem, com **aplicação e banco em servidores separados**, banco **sem exposição pública**, credenciais fora do repositório e dos logs, **backup e restauração testados**, pipelines para criar, alterar, operar e desativar o ambiente, e estimativa de custos. O código da aplicação já existe; o foco é a infraestrutura.

| Componente | Necessidade | Dependências |
|---|---|---|
| Frontend (Nginx) | Entrada pública HTTP, entrega o React e encaminha `/api` | API pelo nome `api` na rede Docker |
| API (Express) | Catálogo, criação/consulta de pedidos, `/api/health/ready` | MongoDB (usuário `kubeshop`, senha em arquivo) |
| MongoDB | Pedidos persistentes, autenticação | Disco persistente, senhas root/app |
| Operação | Saúde, logs, reinício, backup, restauração, desativação | Acesso administrativo restrito |

## 0.2 Solução entregue

- **Terraform** (`terraform/`): resource group por ambiente, VNet com sub-redes `app` e `db`, NSGs com regras por origem, IP público estático com DNS, 2 VMs Ubuntu 24.04, disco gerenciado do MongoDB, token SAS para backups, NAT Gateway opcional. State remoto no Azure Blob com lock e versionamento.
- **Ansible** (`ansible/`), 8 roles idempotentes:

| Role | Hosts | O que faz |
|---|---|---|
| `os_updates` | todas | Verifica atualizações pendentes; aplica `dist-upgrade` e reinicia só se `update_os=true` e o SO pedir |
| `packages` | todas | Pacotes base (curl, certificados, net-tools, jq, unattended-upgrades) + `extra_packages` |
| `docker` | todas | Repositório oficial, Docker Engine/Compose/SDK, rotação de logs, serviço no boot |
| `data_disk` | db | Localiza o disco pelo LUN, cria ext4 só se vazio, expande se cresceu, monta por UUID |
| `mongodb` | db | Senhas em arquivos `0400`, contêiner `mongo:<mongo_tag>` com porta só no IP privado, usuário da app, healthcheck |
| `backup` | db | Scripts de backup/restauração/listagem, timer systemd diário, upload para Blob |
| `app` | app | Testa a conexão privada com o banco, sobe `api` e `frontend` com a `docker_tag`, espera *healthy*, limpa imagens antigas |
| `verify` | todas | Asserções de serviço, portas, saúde, catálogo e versão (falha a pipeline se algo estiver errado) |

- **GitHub Actions** (`.github/workflows/`): `0 - Bootstrap`, `1 - Provisionar e configurar` (Terraform → Ansible com os mesmos parâmetros), `2 - Operação`, `9 - Desativar` e `App | Build` (CI/CD da aplicação).
