resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.name_suffix}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Sub-rede pública: somente a VM da aplicação (Nginx + API)
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.app_subnet_cidr]
}

# Sub-rede privada: somente o MongoDB, sem IP público
resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.db_subnet_cidr]

  # Saída para a internet (apt, imagens Docker, upload de backups).
  # Sem NAT Gateway, usa a saída padrão do Azure; com NAT, a saída padrão é desligada.
  default_outbound_access_enabled = !var.enable_nat_gateway
}

# ---------------------------------------------------------------------------
# NSG da aplicação: HTTP público, SSH só de origens autorizadas
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Regras em recursos separados: a pipeline cria uma regra SSH temporária
# (gha-ssh-<run_id>) para o IP do runner e a remove no final, sem gerar drift aqui.
resource "azurerm_network_security_rule" "app_http" {
  name                        = "allow-http"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = var.http_allowed_cidrs
  destination_address_prefix  = local.app_private_ip
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "app_ssh_admin" {
  count = length(var.admin_cidrs) > 0 ? 1 : 0

  name                        = "allow-ssh-admin"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.admin_cidrs
  destination_address_prefix  = local.app_private_ip
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# ---------------------------------------------------------------------------
# NSG do banco: 27017 e SSH SOMENTE a partir da VM da aplicação
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "db" {
  name                = "nsg-db-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  security_rule {
    name                       = "allow-mongo-from-app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = "${local.app_private_ip}/32"
    destination_address_prefix = "${local.db_private_ip}/32"
  }

  # Acesso administrativo ao banco: SSH com a VM da aplicação como bastion (ProxyJump)
  security_rule {
    name                       = "allow-ssh-from-app"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${local.app_private_ip}/32"
    destination_address_prefix = "${local.db_private_ip}/32"
  }

  # A regra padrão AllowVnetInBound liberaria toda a VNet; aqui ela é anulada.
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

# ---------------------------------------------------------------------------
# Saída opcional do banco por NAT Gateway
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "pip-nat-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "nat-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.nat[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "db" {
  count = var.enable_nat_gateway ? 1 : 0

  subnet_id      = azurerm_subnet.db.id
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
}
