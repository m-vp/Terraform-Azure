terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 4.8.0"
    }
  }

  required_version = ">=1.9.0"
}

provider "azurerm" {
  features {
    
  }
}

# resource "azurerm_resource_group" "rg1" {
#     name = "rsc-grp-1"
#     location = "West Europe"
# }

# resource "azurerm_storage_account" "sq1" {
#     name = "storageaccmvp"
#     resource_group_name = azurerm_resource_group.rg1.name
#     location = azurerm_resource_group.rg1.location
#     account_tier             = "Standard"
#     account_replication_type = "GRS"

#     tags = {
#       environment = "testing"
#     }

# }