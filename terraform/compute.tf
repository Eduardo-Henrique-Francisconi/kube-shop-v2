resource "random_string" "dns" {
  length  = 5
  upper   = false
  special = false
}

# IP público estático com nome DNS gratuito do Azure:
# http://kubeshop-<env>-<sufixo>.<regiao>.cloudapp.azure.com
resource "azurerm_public_ip" "app" {
  name                = "pip-app-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.name_suffix}-${random_string.dns.result}"
  tags                = local.tags
}

resource "azurerm_network_interface" "app" {
  name                = "nic-app-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.app_private_ip
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

# A NIC do banco NÃO tem IP público.
resource "azurerm_network_interface" "db" {
  name                = "nic-db-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.db.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.db_private_ip
  }
}

locals {
  ubuntu_image = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = local.app_vm_name
  computer_name                   = "app-${var.environment}"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.instance_type
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app.id]
  tags                            = merge(local.tags, { role = "app" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-app-${local.name_suffix}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = local.ubuntu_image.publisher
    offer     = local.ubuntu_image.offer
    sku       = local.ubuntu_image.sku
    version   = local.ubuntu_image.version
  }

  boot_diagnostics {} # usa storage gerenciada; ajuda a diagnosticar boot pela console
}

resource "azurerm_linux_virtual_machine" "db" {
  name                            = local.db_vm_name
  computer_name                   = "db-${var.environment}"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.db_instance_type
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.db.id]
  tags                            = merge(local.tags, { role = "db" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-db-${local.name_suffix}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = local.ubuntu_image.publisher
    offer     = local.ubuntu_image.offer
    sku       = local.ubuntu_image.sku
    version   = local.ubuntu_image.version
  }

  boot_diagnostics {}
}

# Disco de dados do MongoDB: recurso independente da VM.
# Mudar o tamanho da VM, ou até recriá-la, não apaga os pedidos.
resource "azurerm_managed_disk" "mongo_data" {
  name                 = "disk-mongo-${local.name_suffix}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.db_data_disk_gb
  tags                 = merge(local.tags, { role = "db-data" })
}

resource "azurerm_virtual_machine_data_disk_attachment" "mongo_data" {
  managed_disk_id    = azurerm_managed_disk.mongo_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.db.id
  lun                = 0
  caching            = "None"
}
