# Os backups ficam na storage account COMPARTILHADA criada pelo bootstrap
# (rg-kubeshop-shared), fora do resource group do ambiente: um terraform destroy
# do ambiente não apaga os backups. A retenção é feita por lifecycle policy.
data "azurerm_storage_account" "shared" {
  name                = var.backup_storage_account
  resource_group_name = var.shared_resource_group
}

# Token SAS estável entre execuções (não gera mudança a cada plan) e renovado
# automaticamente a cada backup_sas_rotation_days, com 30 dias de sobreposição.
resource "time_rotating" "backup_sas" {
  rotation_days = var.backup_sas_rotation_days
}

data "azurerm_storage_account_blob_container_sas" "backups" {
  connection_string = data.azurerm_storage_account.shared.primary_connection_string
  container_name    = local.backup_container
  https_only        = true

  start  = time_rotating.backup_sas.rfc3339
  expiry = timeadd(time_rotating.backup_sas.rotation_rfc3339, "720h")

  # Sem permissão de exclusão: a VM consegue gravar e ler, mas não apagar backups.
  permissions {
    read   = true
    add    = true
    create = true
    write  = true
    delete = false
    list   = true
  }
}
