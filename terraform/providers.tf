terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

# Credenciais vêm das variáveis de ambiente ARM_CLIENT_ID, ARM_CLIENT_SECRET,
# ARM_TENANT_ID e ARM_SUBSCRIPTION_ID (Secrets do GitHub). Nada fica no código.
provider "azurerm" {
  features {
    virtual_machine {
      # O disco de dados do MongoDB é um recurso separado e não é apagado junto
      # com a VM; o disco do SO pode ser descartado.
      delete_os_disk_on_deletion = true
    }
  }
  resource_provider_registrations = "none"
}
