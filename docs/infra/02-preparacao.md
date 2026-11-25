# 2. Pré-requisitos e preparação (uma vez)

## 2.1 Azure

1. Assinatura Azure (ex.: Azure for Students) e Azure CLI.
2. Service principal com papel **Contributor** na assinatura (usado pelo Terraform, pelo Azure CLI da pipeline e pelo bootstrap):

   ```sh
   az login
   az ad sp create-for-rbac --name sp-kubeshop-pipeline --role Contributor \
     --scopes /subscriptions/<SUBSCRIPTION_ID>
   # guarde appId, password e tenant (não versionar)
   ```

3. Escolha um nome **único** para a storage account (3 a 24 letras minúsculas/números), ex.: `stkubeshop<iniciais><4 dígitos>`.

## 2.2 Chave SSH da pipeline

```sh
ssh-keygen -t ed25519 -N "" -C kubeshop-pipeline -f kubeshop
# kubeshop      -> Secret SSH_PRIVATE_KEY
# kubeshop.pub  -> Variable SSH_PUBLIC_KEY
```

## 2.3 GitHub (Settings → Secrets and variables → Actions)

**Repository secrets**

| Nome | Valor |
|---|---|
| `AZURE_CLIENT_ID` | `appId` do service principal |
| `AZURE_CLIENT_SECRET` | `password` do service principal |
| `AZURE_TENANT_ID` | `tenant` |
| `AZURE_SUBSCRIPTION_ID` | ID da assinatura |
| `SSH_PRIVATE_KEY` | conteúdo do arquivo `kubeshop` |
| `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` | *(opcional)* só se as imagens do GHCR forem privadas: usuário e PAT com `read:packages` |

**Repository variables**

| Nome | Exemplo | Obrigatória |
|---|---|---|
| `AZURE_STORAGE_ACCOUNT` | `stkubeshopabc1234` | sim |
| `SSH_PUBLIC_KEY` | `ssh-ed25519 AAAA... kubeshop-pipeline` | sim |
| `AZURE_LOCATION` | `eastus2` | não |
| `ADMIN_CIDRS` | `["200.10.20.30/32"]` (IP fixo da equipe para SSH) | não |
| `ENABLE_NAT_GATEWAY` | `true` | não (padrão `false`) |

**Environments** (Settings → Environments): crie `dev`, `homolog` e `prod`. Em cada um:

| Secret | Como gerar |
|---|---|
| `MONGO_ROOT_PASSWORD` | `openssl rand -hex 24` |
| `MONGO_APP_PASSWORD` | `openssl rand -hex 24` |

Em `prod`, ative *Required reviewers*: toda execução em produção espera aprovação.

## 2.4 Ordem da primeira execução

1. **Actions → `0 - Infra | Bootstrap`** → *Run workflow*. Cria `rg-kubeshop-shared`, a storage account, os containers `tfstate` e `backups-<env>` e a retenção.
2. **Actions → `App | Build e publicação das imagens`** com `version=1.0.0`. Publica `ghcr.io/<dono>/kubeshop-api:1.0.0` e `kubeshop-frontend:1.0.0`.
3. Em *Packages*, torne os dois pacotes **públicos** (ou configure `REGISTRY_USERNAME/PASSWORD`).
4. **Actions → `1 - Infra | Provisionar e configurar`** com `environment=dev`, `action=apply` e `update_os=true` (Cenário 1).
5. Abra a URL mostrada no resumo da execução.

## 2.5 Execução local (opcional, para depuração)

```sh
export ARM_CLIENT_ID=... ARM_CLIENT_SECRET=... ARM_TENANT_ID=... ARM_SUBSCRIPTION_ID=...
cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # ajuste os valores
terraform -chdir=terraform init \
  -backend-config="resource_group_name=rg-kubeshop-shared" \
  -backend-config="storage_account_name=<AZURE_STORAGE_ACCOUNT>" \
  -backend-config="container_name=tfstate" -backend-config="key=kubeshop-dev.tfstate"
terraform -chdir=terraform plan
```

O state é o mesmo da pipeline: evite aplicar localmente e pela pipeline ao mesmo tempo (o lock impede corrupção, mas a segunda execução falha).
