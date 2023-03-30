data "yandex_client_config" "client" {}

module "yc-alb" {
  source              = "../../"

  network_id          = "enpneopbt180nusgut3q"

  alb_load_balancer = {
    name = "canary-load-balancer"
    
    alb_target_groups  = {
      "target-group-prod-blue" = {
        targets = [
          {
            subnet_id  = "e9b5udt8asf9r9qn6nf6"
            ip_address = "10.128.0.1"
          },
          {
            subnet_id  = "e2lu07tr481h35012c8p"
            ip_address = "10.129.0.1"
          },
          {
            subnet_id  = "b0c7h1g3ffdcpee488at"
            ip_address = "10.130.0.1"
          }
        ]
      },
      "target-group-prod-green" = {
        targets = [
          {
            subnet_id  = "e9b5udt8asf9r9qn6nf6"
            ip_address = "10.128.0.2"
          },
          {
            subnet_id  = "e2lu07tr481h35012c8p"
            ip_address = "10.129.0.2"
          },
          {
            subnet_id  = "b0c7h1g3ffdcpee488at"
            ip_address = "10.130.0.2"
          }
        ]
      },
      "target-group-stage-blue" = {
        targets = [
          {
            subnet_id  = "e9b5udt8asf9r9qn6nf6"
            ip_address = "10.128.0.3"
          },
          {
            subnet_id  = "e2lu07tr481h35012c8p"
            ip_address = "10.129.0.3"
          },
          {
            subnet_id  = "b0c7h1g3ffdcpee488at"
            ip_address = "10.130.0.3"
          }
        ]
      },
      "target-group-stage-green" = {
        targets = [
          {
            subnet_id  = "e9b5udt8asf9r9qn6nf6"
            ip_address = "10.128.0.4"
          },
          {
            subnet_id  = "e2lu07tr481h35012c8p"
            ip_address = "10.129.0.4"
          },
          {
            subnet_id  = "b0c7h1g3ffdcpee488at"
            ip_address = "10.130.0.4"
          }
        ]
      }
    }

    alb_backend_groups  = {
      "http-canary-bg-prod" = {
        http_backends  = [
          {
            name                    = "http-canary-prod-bg-blue"
            port                    = 8080
            weight                  = 50
            target_groups_list      = ["target-group-prod-blue"]
            healthcheck             = {
              healthcheck_port      = 8080
              http_healthcheck      = {}
            }
          },
          {
            name                    = "http-canary-prod-bg-green"
            port                    = 8081
            weight                  = 50
            target_groups_list      = ["target-group-prod-green"]
            healthcheck             = {
              healthcheck_port      = 8081
              http_healthcheck      = {}
            }
          }
        ]
      },
      "http-canary-bg-stage" = {
        http_backends  = [
          {
            name                    = "http-canary-stage-bg-blue"
            port                    =  8082
            weight                  = 50
            target_groups_list      = ["target-group-stage-blue"]
            healthcheck             = {
              healthcheck_port      = 8082
              http_healthcheck      = {}
            }
          },
          {
            name                    = "http-canary-stage-bg-green"
            port                    = 8083
            weight                  = 50
            target_groups_list      = ["target-group-stage-green"]
            healthcheck             = {
              healthcheck_port      = 8083
              http_healthcheck      = {}
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
        zone_id = "ru-central1-a"
        subnet_id = "e9b5udt8asf9r9qn6nf6"
      },
      {
        zone_id = "ru-central1-b"
        subnet_id = "e2lu07tr481h35012c8p"
      },
      {
        zone_id = "ru-central1-c"
        subnet_id = "b0c7h1g3ffdcpee488at"
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