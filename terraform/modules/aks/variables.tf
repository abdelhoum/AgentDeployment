variable "cluster_name" {
  type        = string
  description = "Nom du cluster AKS"
}

variable "resource_group_name" {
  type        = string
  description = "Nom du resource group Azure"
}

variable "location" {
  type        = string
  description = "Région Azure"
}

variable "node_count" {
  type        = number
  description = "Nombre de nodes dans le node pool"
}

variable "vm_size" {
  type        = string
  description = "Taille des VMs du node pool"
  default     = "Standard_D2s_v3"
}

variable "tags" {
  type        = map(string)
  description = "Tags Azure à appliquer aux ressources"
  default     = {}
}
