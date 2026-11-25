#!/usr/bin/env bash
# Executado UMA vez (workflow "0 - Bootstrap"). Idempotente.
# Cria o resource group compartilhado e a storage account do Terraform State e dos backups.
set -euo pipefail
rg="${SHARED_RG:-rg-kubeshop-shared}"
sa="${AZURE_STORAGE_ACCOUNT:?defina a variável AZURE_STORAGE_ACCOUNT}"
location="${AZURE_LOCATION:-eastus2}"
retention_days="${BACKUP_RETENTION_DAYS:-30}"

az group create -n "$rg" -l "$location" --tags project=kubeshop managed_by=bootstrap --output none
echo "Resource group $rg OK"

if ! az storage account show -g "$rg" -n "$sa" --output none 2>/dev/null; then
  az storage account create -g "$rg" -n "$sa" -l "$location" \
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
    --allow-blob-public-access false --https-only true \
    --tags project=kubeshop managed_by=bootstrap --output none
fi
echo "Storage account $sa OK"

# Proteção e recuperação do state e dos backups
az storage account blob-service-properties update -g "$rg" --account-name "$sa" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 14 \
  --enable-container-delete-retention true --container-delete-retention-days 14 \
  --output none
echo "Versionamento e soft delete OK"

key="$(az storage account keys list -g "$rg" -n "$sa" --query '[0].value' -o tsv)"
for c in tfstate backups-dev backups-homolog backups-prod; do
  az storage container create --account-name "$sa" --account-key "$key" -n "$c" --output none
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
az storage account management-policy create -g "$rg" --account-name "$sa" --policy "@$policy" --output none
echo "Lifecycle policy: backups expiram em ${retention_days} dias"
