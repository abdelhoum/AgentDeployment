terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Optionnel : décommenter pour stocker le state dans Azure Storage
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "<storage-account-name>"
  #   container_name       = "tfstate"
  #   key                  = "cortex-demo.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "demo" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Cluster OPS — héberge ArgoCD (1 node suffit)
module "aks_ops" {
  source = "./modules/aks"

  cluster_name        = "aks-cortex-ops"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  node_count          = 1
  vm_size             = var.vm_size
  tags                = var.tags
}

# Clusters DEMO — cibles ArgoCD (2 nodes chacun)
module "aks_demo_1" {
  source = "./modules/aks"

  cluster_name        = "aks-cortex-demo-1"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  node_count          = 2
  vm_size             = var.vm_size
  tags                = var.tags
}

module "aks_demo_2" {
  source = "./modules/aks"

  cluster_name        = "aks-cortex-demo-2"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  node_count          = 2
  vm_size             = var.vm_size
  tags                = var.tags
}

module "aks_demo_3" {
  source = "./modules/aks"

  cluster_name        = "aks-cortex-demo-3"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  node_count          = 2
  vm_size             = var.vm_size
  tags                = var.tags
}
