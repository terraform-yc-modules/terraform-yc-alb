data "yandex_client_config" "client" {}

module "yc-alb" {
  source              = "../../"

  network_id           = "<NETWORK_ID>"
  public_dns_zone_id   = "<PUBLIC_DNS_ZONE_ID>"
  public_dns_zone_name = "<PUBLIC_DNS_ZONE_NAME>"

  alb_load_balancer = {
    name = "canary-load-balancer"
    
    alb_target_groups  = {
      "target-group-prod-blue" = {
        targets = [
          {
            subnet_id  = "<SUBNET-ID-A>"
            ip_address = "<INSTANCE-IP>"
          },
          {
            subnet_id  = "<SUBNET-ID-B>"
            ip_address = "<INSTANCE-IP>"
          },
          {
            ip_address = "<INSTANCE-IP>"
            private_ipv4_address = true
          }
        ]
      },
      "target-group-prod-green" = {
        targets = [
          {
            ip_address = "<INSTANCE-IP>"
            private_ipv4_address = true
          },
          {
            subnet_id  = "<SUBNET-ID-B>"
            ip_address = "<INSTANCE-IP>"
          },
          {
            subnet_id  = "<SUBNET-ID-C>"
            ip_address = "<INSTANCE-IP>"
          }
        ]
      },
      "target-group-stage-blue" = {
        targets = [
          {
            subnet_id  = "<SUBNET-ID-A>"
            ip_address = "<INSTANCE-IP>"
          },
          {
            subnet_id  = "<SUBNET-ID-B>"
            ip_address = "<INSTANCE-IP>"
          },
          {
            ip_address = "<INSTANCE-IP>"
            private_ipv4_address = true
          }
        ]
      },
      "target-group-stage-green" = {
        targets = [
          {
            subnet_id  = "<SUBNET-ID-A>"
            ip_address = "<INSTANCE-IP>"
          },
          {
            ip_address = "<INSTANCE-IP>"
            private_ipv4_address = true
          },
          {
            subnet_id  = "<SUBNET-ID-C>"
            ip_address = "<INSTANCE-IP>"
          }
        ]
      }
    }

    alb_backend_groups  = {
      "http-canary-bg-prod" = {
        http_backends  = [
          {
            name                       = "http-canary-prod-bg-blue"
            port                       = 8080
            weight                     = 50
            existing_target_groups_ids = ["<TARGET-GROUP-ID>"]
            healthcheck                = {
              healthcheck_port         = 8080
              http_healthcheck         = {}
            }
          },
          {
            name                     = "http-canary-prod-bg-green"
            port                     = 8081
            weight                   = 50
            target_groups_names_list = ["target-group-prod-green"]
            healthcheck              = {
              healthcheck_port       = 8081
              http_healthcheck       = {}
            }
          }
        ]
      },
      "http-canary-bg-stage" = {
        http_backends  = [
          {
            name                     = "http-canary-stage-bg-blue"
            port                     =  8082
            weight                   = 50
            target_groups_names_list = ["target-group-stage-blue"]
            healthcheck              = {
              healthcheck_port       = 8082
              http_healthcheck       = {}
            }
          },
          {
            name                     = "http-canary-stage-bg-green"
            port                     = 8083
            weight                   = 50
            target_groups_names_list = ["target-group-stage-green"]
            healthcheck              = {
              healthcheck_port       = 8083
              http_healthcheck       = {}
            }
          }
        ]
      }
    }

    // HTTP virtual router
    alb_http_routers  = ["canary-router"]

    // Virtual host requires:
    //  - each http route is using own backend group
    //  - each virtual host points to own list of `authorities`
    alb_virtual_hosts = {
      "canary-vh-production" = {
        http_router_name = "canary-router"
        authority = ["service-production.yandexcloud.example"]
        route = {
          name = "canary-vh-production"
          http_route = {
            http_route_action = {
              backend_group_name = "http-canary-bg-prod"
            }
          }
        }
      },
      "canary-vh-staging" = {
        http_router_name = "canary-router"
        authority = ["service-staging.yandexcloud.example"]
        route = {
          name = "canary-vh-staging"
          http_route = {
            http_route_action = {
              backend_group_name = "http-canary-bg-stage"
            }
          }
        }
      }
    }

    // ALB locations
    alb_locations = [
      {
        zone      = "ru-central1-a"
        subnet_id = "<SUBNET-ID-A>"
      },
      {
        zone      = "ru-central1-b"
        subnet_id = "<SUBNET-ID-B>"
      },
      {
        zone      = "ru-central1-c"
        subnet_id = "<SUBNET-ID-C>"
      }
    ]

    alb_listeners = [
      {
        name = "canary-listener"
        endpoint = {
          address = {
            external_ipv4_address = {}
          }
          ports = ["80"]
        }
        http = {
          handler = {
            http_router_name = "canary-router"
          }
        }
      }
    ]

    log_options = {
      disable = true
    }
  }
}