locals {
  name_suffix = "${var.project}-${var.environment}"

  app_subnet_cidr = cidrsubnet(var.vnet_cidr, 8, 1) # 10.20.1.0/24
  db_subnet_cidr  = cidrsubnet(var.vnet_cidr, 8, 2) # 10.20.2.0/24

  # IPs privados fixos: o Ansible e a API usam o endereço do banco,
  # que não pode mudar quando a VM reinicia ou muda de tamanho.
  app_private_ip = cidrhost(local.app_subnet_cidr, 10)
  db_private_ip  = cidrhost(local.db_subnet_cidr, 10)

  app_vm_name = "${var.instance_name}-app-${var.environment}"
  db_vm_name  = "${var.instance_name}-db-${var.environment}"

  backup_container = "backups-${var.environment}"

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    repository  = "kube-shop-v2"
  }
}
