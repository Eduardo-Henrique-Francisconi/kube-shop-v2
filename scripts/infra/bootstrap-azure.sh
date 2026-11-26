#!/usr/bin/env bash
# Executado UMA vez (workflow "0 - Bootstrap"). Idempotente.
# Cria o resource group compartilhado e a storage account do Terraform State e dos backups.
set -euo pipefail
rg="${SHARED_RG:-rg-kubeshop-shared}"
sa="${AZURE_STORAGE_ACCOUNT:?defina a variável AZURE_STORAGE_ACCOUNT}"
location="${AZURE_LOCATION:-eastus2}"
retention_days="${BACKUP_RETENTION_DAYS:-30}"

# Repete comandos do Azure que podem falhar logo após a criação (propagação do ARM)
retry() {
  local n=1
  until "$@"; do
    [ "$n" -ge 8 ] && { echo "Falhou após $n tentativas: $*" >&2; return 1; }
    echo "  aguardando propagação no Azure (tentativa $n)..." >&2; sleep 15; n=$((n + 1))
  done
}

# Regiões permitidas pela assinatura (Azure for Students limita as regiões)
allowed="$(az policy assignment list --query "[].parameters.listOfAllowedLocations.value" -o tsv 2>/dev/null | tr '\t' '\n' | sort -u | tr '\n' ' ')"
[ -n "$allowed" ] && echo "Regiões permitidas pela política da assinatura: $allowed"
echo "Região escolhida (AZURE_LOCATION): $location"

if az group show -n "$rg" --output none 2>/dev/null; then
  echo "Resource group $rg já existe em $(az group show -n "$rg" --query location -o tsv)"
else
  az group create -n "$rg" -l "$location" --tags project=kubeshop managed_by=bootstrap --output none
  echo "Resource group $rg criado em $location"
fi

if az storage account show -g "$rg" -n "$sa" --output none 2>/dev/null; then
  echo "Storage account $sa já existe"
else
  avail="$(az storage account check-name -n "$sa" --query nameAvailable -o tsv)"
  [ "$avail" = "true" ] || { echo "::error::O nome $sa já está em uso no Azure. Troque a Variable AZURE_STORAGE_ACCOUNT."; exit 1; }
  az storage account create -g "$rg" -n "$sa" -l "$location" \
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
    --allow-blob-public-access false --https-only true \
    --tags project=kubeshop managed_by=bootstrap --output none
  echo "Storage account $sa criada em $location"
fi
retry az storage account show -g "$rg" -n "$sa" --output none

# Proteção e recuperação do state e dos backups
retry az storage account blob-service-properties update -g "$rg" --account-name "$sa" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 14 \
  --enable-container-delete-retention true --container-delete-retention-days 14 \
  --output none
echo "Versionamento e soft delete OK"

key="$(retry az storage account keys list -g "$rg" -n "$sa" --query '[0].value' -o tsv)"
for c in tfstate backups-dev backups-homolog backups-prod; do
  retry az storage container create --account-name "$sa" --account-key "$key" -n "$c" --output none
  echo "Container $c OK"
done

# Retenção dos backups (o state não expira)
policy="$(mktemp)"
cat > "$policy" <<JSON
{ "rules": [ {
  "enabled": true, "name": "expira-backups", "type": "Lifecycle",
  "definition": {
    "filters": { "blobTypes": ["blockBlob"], "prefixMatch": ["backups-dev/", "backups-homolog/", "backups-prod/"] },
    "actions": {
      "baseBlob": { "delete": { "daysAfterModificationGreaterThan": ${retention_days} } },
      "version": { "delete": { "daysAfterCreationGreaterThan": ${retention_days} } }
    } } } ] }
JSON
retry az storage account management-policy create -g "$rg" --account-name "$sa" --policy "@$policy" --output none
echo "Lifecycle policy: backups expiram em ${retention_days} dias"
echo "BOOTSTRAP OK: storage $sa em $location"
