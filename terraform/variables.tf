# ---------------------------------------------------------------------------
# Parâmetros vindos da pipeline (TF_VAR_*)
# ---------------------------------------------------------------------------
variable "environment" {
  description = "Ambiente de destino (dev, homolog ou prod)."
  type        = string

  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "environment deve ser dev, homolog ou prod."
  }
}

variable "instance_name" {
  description = "Prefixo do nome das VMs. Ex.: vm-kubeshop gera vm-kubeshop-app-dev e vm-kubeshop-db-dev. Alterar este valor RECRIA as VMs."
  type        = string
  default     = "vm-kubeshop"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.instance_name))
    error_message = "instance_name: 3 a 31 caracteres, minúsculas, números e hífen, começando por letra."
  }
}

variable "instance_type" {
  description = "Tamanho da VM da aplicação (alteração in-place: a VM reinicia, não é recriada)."
  type        = string
  default     = "Standard_B1ms"
}

variable "db_instance_type" {
  description = "Tamanho da VM do MongoDB (alteração in-place: a VM reinicia, o disco de dados é preservado)."
  type        = string
  default     = "Standard_B2s"
}

variable "db_data_disk_gb" {
  description = "Tamanho do disco de dados do MongoDB em GiB. Só pode aumentar (o Ansible expande o filesystem)."
  type        = number
  default     = 16

  validation {
    condition     = var.db_data_disk_gb >= 8 && var.db_data_disk_gb <= 1024
    error_message = "db_data_disk_gb deve estar entre 8 e 1024."
  }
}

# ---------------------------------------------------------------------------
# Configuração fixa por repositório (Variables do GitHub) ou defaults
# ---------------------------------------------------------------------------
variable "project" {
  description = "Nome curto do projeto, usado em nomes e tags."
  type        = string
  default     = "kubeshop"
}

variable "location" {
  description = "Região do Azure."
  type        = string
  default     = "eastus2"
}

variable "vnet_cidr" {
  description = "Faixa da rede virtual."
  type        = string
  default     = "10.20.0.0/16"
}

variable "admin_username" {
  description = "Usuário administrativo das VMs (login apenas por chave SSH)."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Chave pública SSH (conteúdo, não caminho). A privada fica só nos Secrets da pipeline."
  type        = string
}

variable "admin_cidrs" {
  description = "CIDRs fixos autorizados a acessar SSH na VM da aplicação (ex.: IP da equipe). Vazio = somente acesso temporário da pipeline."
  type        = list(string)
  default     = []
}

variable "http_allowed_cidrs" {
  description = "Origens autorizadas na porta 80 da loja."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "os_disk_type" {
  description = "Tipo de disco do SO."
  type        = string
  default     = "StandardSSD_LRS"
}

variable "data_disk_type" {
  description = "Tipo de disco de dados do MongoDB."
  type        = string
  default     = "StandardSSD_LRS"
}

variable "enable_nat_gateway" {
  description = "Usa NAT Gateway para a saída da sub-rede do banco (mais robusto, ~US$ 33/mês). false = saída padrão do Azure."
  type        = bool
  default     = false
}

variable "shared_resource_group" {
  description = "Resource group compartilhado criado pelo bootstrap (state e backups)."
  type        = string
  default     = "rg-kubeshop-shared"
}

variable "backup_storage_account" {
  description = "Storage account compartilhada criada pelo bootstrap (state e backups)."
  type        = string
}

variable "backup_sas_rotation_days" {
  description = "Dias até o Terraform gerar um novo token SAS para os backups."
  type        = number
  default     = 60
}
