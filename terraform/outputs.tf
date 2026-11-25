output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "app_nsg_name" {
  description = "Usado pela pipeline para abrir/fechar o SSH temporário do runner."
  value       = azurerm_network_security_group.app.name
}

output "app_public_ip" {
  value = azurerm_public_ip.app.ip_address
}

output "app_fqdn" {
  value = azurerm_public_ip.app.fqdn
}

output "app_url" {
  value = "http://${azurerm_public_ip.app.fqdn}"
}

output "app_private_ip" {
  value = local.app_private_ip
}

output "db_private_ip" {
  value = local.db_private_ip
}

output "admin_username" {
  value = var.admin_username
}

output "vm_inventory" {
  description = "Inventário das VMs (ACE-02)."
  value = {
    app = {
      name       = azurerm_linux_virtual_machine.app.name
      size       = azurerm_linux_virtual_machine.app.size
      private_ip = local.app_private_ip
      public_ip  = azurerm_public_ip.app.ip_address
    }
    db = {
      name         = azurerm_linux_virtual_machine.db.name
      size         = azurerm_linux_virtual_machine.db.size
      private_ip   = local.db_private_ip
      public_ip    = "nenhum"
      data_disk_gb = azurerm_managed_disk.mongo_data.disk_size_gb
    }
  }
}

output "backup_container_url" {
  value = "${data.azurerm_storage_account.shared.primary_blob_endpoint}${local.backup_container}"
}

output "backup_sas" {
  value     = data.azurerm_storage_account_blob_container_sas.backups.sas
  sensitive = true
}
