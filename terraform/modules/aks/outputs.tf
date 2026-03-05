output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive = true
}

output "host" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive = true
}
