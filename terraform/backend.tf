# State remoto no Azure Blob Storage (com lock por lease, versionamento e soft delete).
# Configuração parcial: a pipeline informa os valores com -backend-config:
#   resource_group_name  = rg-kubeshop-shared
#   storage_account_name = <AZURE_STORAGE_ACCOUNT>
#   container_name       = tfstate
#   key                  = kubeshop-<environment>.tfstate
# Cada ambiente (dev/homolog/prod) tem o seu próprio arquivo de state.
terraform {
  backend "azurerm" {}
}
