output "aks_ops_name" {
  value = module.aks_ops.cluster_name
}

output "aks_demo_1_name" {
  value = module.aks_demo_1.cluster_name
}

output "aks_demo_2_name" {
  value = module.aks_demo_2.cluster_name
}

output "aks_demo_3_name" {
  value = module.aks_demo_3.cluster_name
}

output "resource_group" {
  value = azurerm_resource_group.demo.name
}

output "subscription_id" {
  value       = var.subscription_id
  description = "Souscription Azure de cette démo"
}
