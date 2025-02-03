
# Move pre-installed Traefik to 8080/8443
resource "kubernetes_manifest" "helm_chart_config_traefik" {
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "traefik"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = <<-EOT
          globalArguments:
            - "--serversTransport.insecureSkipVerify=true"
          ports:
            web:
              exposedPort: 8080
            websecure:
              exposedPort: 8443
      EOT
    }
  }
}


