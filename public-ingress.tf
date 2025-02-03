variable "cloudflare_dns_api_token" {
  type = string
}

variable "cloudflare_zone_api_token" {
  type = string
}

variable "domain" {
  type = string
}

variable "email" {
  type = string
}

locals {
  public_namespace = "public"
}


resource "kubernetes_namespace" "example" {
  metadata {
    name = local.public_namespace
  }
}

resource "kubernetes_secret_v1" "cloudflare_api_credentials" {
  metadata {
    name      = "cloudflare-api-credentials"
    namespace = local.public_namespace
  }

  data = {
    email                  = var.email
    cloudflareDNSApiToken  = var.cloudflare_dns_api_token
    cloudflareZoneApiToken = var.cloudflare_zone_api_token
  }
}

resource "helm_release" "public_traefik" {
  name      = "public-traefik"
  namespace = local.public_namespace

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "34.2.0"

  values = [jsonencode({
    ingressClass = {
      enabled        = true
      isDefaultClass = false
      name           = "public-traefik"
    }

    providers = {
      kubernetesCRD = {
        enabled      = true
        ingressClass = "public-traefik"
      }

      kubernetesIngress = {
        enabled      = true
        ingressClass = "public-traefik"
      }
    }

    logs = {
      access = {
        enabled = true
      }
    }

    globalArguments = ["--global.checknewversion"]

    certificatesResolvers : {
      cloudflare = {
        acme = {
          email : var.email
          storage : "/certs/acme.json"
          dnsChallenge : {
            provider  = "cloudflare"
            resolvers = ["1.1.1.1:53", "8.8.8.8:53"]
          }
      } }
    }

    env = [
      {
        name = "CF_DNS_API_TOKEN"
        valueFrom = {
          secretKeyRef = {
            key  = "cloudflareDNSApiToken"
            name = "cloudflare-api-credentials"
          }
        }
      },
      {
        name = "CF_ZONE_API_TOKEN"
        valueFrom = {
          secretKeyRef = {
            key  = "cloudflareZoneApiToken"
            name = "cloudflare-api-credentials"
          }
        }
      }
    ]

    ports = {
      web = {
        redirections = {
          entryPoint = {
            to     = "websecure"
            scheme = "https"
          }
        }
        middlewares = []
      }

      websecure = {
        tls = {
          certResolver : "cloudflare"
          domains : [{
            main = var.domain
            sans = ["*.${var.domain}"]
          }]
        }
        middlewares = [
          "${local.public_namespace}-traefik-modsecurity-plugin@kubernetescrd"
        ]
      }
    }

    experimental = {
      plugins = {
        traefik-modsecurity-plugin = {
          moduleName = "github.com/acouvreur/traefik-modsecurity-plugin"
          version    = "v1.3.0"
        }
      }
    }

    service = {
      type           = "LoadBalancer"
      ipFamilyPolicy = "PreferDualStack"
    }

    ingressRoute = {
      dashboard = {
        enabled = false
      }
    }

    persistence = {
      enabled = true
      path    = "/certs"
      size    = "128Mi"
    }

  })]

}


resource "kubernetes_manifest" "traefik_modsecurity_plugin" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"

    metadata = {
      name      = "traefik-modsecurity-plugin"
      namespace = local.public_namespace
    }

    spec = {
      plugin = {
        "traefik-modsecurity-plugin" = {
          ModsecurityUrl = "http://${helm_release.waf.name}-${helm_release.waf.chart}:8081"
          # Optional
          MaxBodySize   = "10485760"
          TimeoutMillis = "2000"
        }
      }
    }
  }
}

resource "helm_release" "waf" {
  name      = "modsecurity"
  namespace = local.public_namespace

  repository = "oci://tccr.io/truecharts"
  chart      = "modsecurity-crs"
  version    = "5.5.1"

  values = [jsonencode({
    workload = {
      main = {
        podSpec = {
          containers = {
            main = {
              env = {
                BACKEND                 = "http://localhost:8081/healthz"
                BLOCKING_PARANOIA       = 1
                ANOMALY_INBOUND         = 5
                ANOMALY_OUTBOUND        = 4
                REPORTING_LEVEL         = 2
                MODSEC_AUDIT_LOG_FORMAT = "JSON"
                MODSEC_RULE_ENGINE      = "On"
              }
            }
          }
        }
      }
    }

  })]
}