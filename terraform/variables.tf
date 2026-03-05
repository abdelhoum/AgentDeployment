variable "subscription_id" {
  type        = string
  description = "ID de la souscription Azure cible pour cette démo"
  # Pas de default — obligatoire, varie par client/démo
}

variable "location" {
  type        = string
  description = "Région Azure pour tous les clusters"
  default     = "francecentral"
}

variable "resource_group_name" {
  type        = string
  description = "Nom du resource group de la démo"
  default     = "rg-cortex-demo"
}

variable "vm_size" {
  type        = string
  description = "Taille des VMs des nodes"
  default     = "Standard_D2s_v3"
}

variable "tags" {
  type        = map(string)
  description = "Tags appliqués à toutes les ressources"
  default = {
    project     = "cortex-demo"
    environment = "demo"
    managed_by  = "terraform"
  }
}
