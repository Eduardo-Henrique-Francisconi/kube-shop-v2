# 3. Manual de operação

Todas as rotinas são executadas em **GitHub → Actions**, escolhendo o workflow e clicando em *Run workflow*. Cada execução gera um resumo (*Summary*) que serve de evidência e não mostra credenciais.

> **Rotinas cotidianas** (não removem dados): 1 - Infra (`plan`/`apply` sem recriação), 2 - Infra (`health`, `logs`, `restart`, `backup`, `list-backups`, `smoke`, `deploy-app`).
> **Rotinas destrutivas** (removem ou substituem dados): 2 - Infra `restore` (pede `RESTAURAR`), 1 - Infra com `allow_replace=true`, 9 - Infra | Desativar (pede `DESTRUIR-<env>`).

## 3.1 Parâmetros do pipeline `1 - Infra | Provisionar e configurar`

| Parâmetro | Exemplo | Vai para | Efeito |
|---|---|---|---|
| `environment` | dev / homolog / prod | Terraform + Ansible | RG, state, Secrets e backups do ambiente |
| `action` | plan / apply | pipeline | `plan` só mostra o que mudaria |
| `instance_name` | vm-kubeshop | Terraform | Prefixo das VMs (**recria** as VMs) |
| `instance_type` | Standard_B1ms | Terraform | Tamanho da VM da aplicação (in-place, reinicia) |
| `db_instance_type` | Standard_B2s | Terraform | Tamanho da VM do banco (in-place, reinicia) |
| `db_data_disk_gb` | 16 | Terraform + Ansible | Disco do MongoDB (só aumenta; o Ansible expande o filesystem) |
| `docker_image` | ghcr.io/org/kubeshop | Ansible | Prefixo das imagens `-api` e `-frontend` |
| `docker_tag` | 1.0.0 | Ansible | Versão da aplicação (troca = pull + recriação controlada) |
| `mongo_tag` | 8.0.17 | Ansible | Versão do MongoDB (dados preservados no disco) |
| `update_os` | true / false | Ansible | Aplica `apt dist-upgrade` e reinicia só se necessário |
| `extra_packages` | git, unzip, htop | Ansible | Pacotes adicionais nas duas VMs |
| `allow_replace` | false | pipeline | Libera planos que destroem/recriam VM ou disco |

**Resultado esperado**: job verde; no *Summary*, o plano (`Plan: …` ou `No changes.`), o PLAY RECAP sem `failed`, a URL da loja, catálogo com 6 produtos e "Porta 27017 no IP público: bloqueada".

## 3.2 Atualizar a aplicação (nova versão)

1. Publique as imagens: `App | Build e publicação das imagens` com a nova `version` (ou crie a tag git `v1.0.1`).
2. Implante: `2 - Infra | Operação` → `routine=deploy-app`, `docker_tag=1.0.1` (ou `deploy_env` no próprio workflow de build).
3. Resultado: `api` e `frontend` recriados com a nova tag, verificação de saúde e versão OK.
4. **Rollback**: execute de novo com a tag anterior.

## 3.3 Saúde — `routine=health`
Mostra contêineres, disco, memória, último backup e roda as verificações (`docker` ativo, Mongo *healthy*, 27017 só no IP privado, `/api/health/ready`, catálogo e versão).

## 3.4 Logs — `routine=logs`, `service=all|api|frontend|mongo|backup`
Últimas 200 linhas dos contêineres e do serviço de backup (`journalctl`).

## 3.5 Reinício — `routine=restart`, `service=all|api|frontend|mongo`
Reinicia na ordem segura (banco → API → frontend) e espera a loja responder.

## 3.6 Backup — `routine=backup`
Executa o mesmo script do timer diário (03:00 UTC): `mongodump` compactado → `/var/backups/kubeshop` (7 últimos) → container `backups-<env>` (30 dias). O resumo mostra `BACKUP_OK name=… sha256=…` e a contagem de pedidos no momento do backup.

## 3.7 Listar backups — `routine=list-backups`

## 3.8 Restauração — `routine=restore`, `backup_name=latest|<arquivo>`, `confirm=RESTAURAR`
1. Faz um backup de segurança (quando `backup_name` não é `latest`).
2. Baixa o arquivo do Blob (se não estiver no disco local), valida o gzip e executa `mongorestore --drop` no banco `kubeshop`.
3. Mostra a contagem de pedidos **antes** e **depois** e quantos pedidos a API retorna.

## 3.9 Acesso administrativo ao banco (procedimento separado — REQ-03)
O banco não tem IP público. O acesso administrativo é feito pela VM da aplicação (bastion):

1. Adicione seu IP em `ADMIN_CIDRS` (ex.: `["200.10.20.30/32"]`) e rode `1 - Infra` (cria a regra `allow-ssh-admin`).
2. Use a chave autorizada e o `ProxyJump`:
   ```sh
   ssh -J azureuser@<IP_PUBLICO_APP> azureuser@10.20.2.10
   sudo docker exec -it mongo mongosh -u admin -p --authenticationDatabase admin
   ```
3. Ao terminar, remova seu IP de `ADMIN_CIDRS` e rode `1 - Infra` novamente.

## 3.10 Desativação — `9 - Infra | Desativar ambiente`
`confirm=DESTRUIR-<env>`, `final_backup=true` (recomendado).

| Item | Destino |
|---|---|
| VMs, discos (inclusive o de dados), NICs, IP público, NSGs, VNet, RG do ambiente | **Removidos** (deixam de gerar cobrança) |
| Pedidos | Só permanecem no backup final e nos anteriores (`backups-<env>`) |
| `rg-kubeshop-shared` (state + backups) | **Mantido**, continua gerando custo (centavos/mês). Backups expiram em 30 dias. Para encerrar tudo: `az group delete -n rg-kubeshop-shared` |
| Imagens no GHCR | Mantidas (sem custo para pacotes públicos) |

Para recriar o ambiente: `1 - Infra` com `action=apply` e depois `restore` com o backup desejado.

## 3.11 Falhas comuns

| Sintoma | Causa provável | Ação |
|---|---|---|
| `Configuração ausente: ...` | Secret/Variable não cadastrado | Ver §2.3 |
| `terraform init` 403/404 | Bootstrap não executado ou nome da storage errado | Rodar `0 - Bootstrap`; conferir `AZURE_STORAGE_ACCOUNT` |
| `Error acquiring the state lock` | Outra execução em andamento ou execução interrompida | Aguardar; se travado, `terraform force-unlock <ID>` localmente |
| `O plano destrói/recria VM ou disco` | Mudança em `instance_name`, imagem ou disco | Revisar; se intencional: backup + `allow_replace=true` |
| `SkuNotAvailable` / cota | Tamanho indisponível na região/assinatura | Outro `instance_type` ou `AZURE_LOCATION` |
| Ansible `UNREACHABLE` | VM reiniciando, regra JIT não propagou | Reexecutar (idempotente) |
| `manifest unknown` / `denied` no pull | Tag não publicada ou pacote privado | Rodar o build da tag; pacote público ou Secrets do registry |
| API não fica *healthy* | Banco indisponível ou senha errada | `logs` com `service=api` e `mongo`; conferir Secrets do ambiente |
| `BACKUP_SAS vazio` / upload 403 | Token expirado (sem deploy há > 90 dias) | Rodar `1 - Infra` (renova o SAS automaticamente) |
| Regra `gha-ssh-*` esquecida no NSG | Runner cancelado antes da limpeza | A próxima execução remove; ou `az network nsg rule delete` |
