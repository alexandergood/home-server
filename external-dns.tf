

resource "helm_release" "etcd" {
  name             = "etcd"
  namespace        = "external-dns"
  create_namespace = true

  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "etcd"
  version    = "11.0.5"

  values = [
    jsonencode({
      auth = {
        rbac = { create = false }
      }
      fullnameOverride = "etcd"
    })
  ]
}

resource "helm_release" "coredns" {
  name             = "coredns"
  namespace        = "external-dns"
  create_namespace = true

  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  version    = "1.39.0"

  values = [
    jsonencode({
      rbac = {
        create = true
      }
      serviceType      = "LoadBalancer"
      isClusterService = false
      servers = [{
        zones = [{
          zone = "."
        }]
        port = 53
        plugins = [
          { name = "errors" },
          {
            name        = "health"
            configBlock = "lameduck 5s"
          }, { name = "ready" },
          {
            name       = "cache"
            parameters = 30
          },
          { name = "loop" },
          { name = "reload" },
          { name = "loadbalance" },
          {
            name       = "forward"
            parameters = ". /etc/resolv.conf"
          },
          {
            name       = "etcd"
            parameters = var.domain
            configBlock : <<-EOT
              stubzones
              path /skydns
              endpoint http://etcd:2379
            EOT
          }
        ]
      }]

    })
  ]

}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  namespace        = "external-dns"
  create_namespace = true

  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.15.1"

  values = [jsonencode({
    provider = {
      name = "coredns"
    }
    env = [
      {
        name  = "ETCD_URLS"
        value = "http://etcd:2379"
      }
    ]



  })]

}