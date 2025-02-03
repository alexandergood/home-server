variable "plex_claim" {
  type = str
}

resource "helm_release" "plex" {
  name             = "plex"
  namespace        = "plex"
  create_namespace = true

  # The Plex chart has no Release.Namespace references
  # and the Helm Provider cannot set the context namespace.
  postrender = {
    binary_path = "${path.module}/scripts/change-namespace.py"
    args = [
      "--namespace",
      "plex",
    ]
  }

  repository = "https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages"
  chart      = "plex-media-server"
  version    = "0.8.0"

  values = [
    jsonencode({
      ingress = {
        enabled = false
      }

      pms = {
        configStorage = "16Gi"
        gpu = {
          nvidia = {
            enabled = true
          }
        }
      }

      extraEnv = {
        PLEX_CLAIM       = var.plex_claim
        ALLOWED_NETWORKS = ""
      }
    })
  ]

}

resource "kubernetes_manifest" "plex_ingress" {
  depends_on = [helm_release.plex]

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"

    metadata = {
      name      = "plex-plex-media-server-ingress"
      namespace = "plex"
    }

    spec = {
      ingressClassName = "public-traefik"

      rules = [
        {
          host = "plex.${var.domain}"
          http = {
            paths = [
              {
                backend = {
                  service = {
                    name = "plex-plex-media-server"
                    port = {
                      number = 32400
                    }
                  }
                }
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        }
      ]
      tls = [
        {
          hosts = [
            "plex.${var.domain}"
          ]
        }
      ]
    }
  }

}