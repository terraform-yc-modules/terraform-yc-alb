data "yandex_client_config" "client" {}

module "alb" {
  source              = "../../"
  network_id          = "enpneopbt180nusgut3q"
  
  alb_load_balancer   = {
    name = "alb-test"

    alb_target_groups  = {
      "target-group-a" = {
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
      "target-group-b" = {
        targets = [
          {
            subnet_id  = "e9b5udt8asf9r9qn6nf6"
            ip_address = "10.128.0.10"
          },
          {
            subnet_id  = "e2lu07tr481h35012c8p"
            ip_address = "10.129.0.10"
          },
          {
            subnet_id  = "b0c7h1g3ffdcpee488at"
            ip_address = "10.130.0.10"
          }
        ]
      }
    }

    alb_backend_groups         = {
      "test-bg-a"              = {
        http_backends          = [
          {
            name               = "test-backend-a"
            port               = 80
            weight             = 100
            target_groups_list = ["target-group-a"]
            healthcheck = {
              healthcheck_port = 80
              http_healthcheck = {
                path = "/"
              }
            }
          }
        ]
      },
      "test-bg-b"              = {
        http_backends          = [
          {
            name               = "test-backend-b"
            port               = 80
            weight             = 100
            target_groups_list = ["target-group-b"]
            healthcheck = {
              healthcheck_port = 80
              http_healthcheck = {
                path = "/"
              }
            }
          }
        ]
      }
    }

    alb_http_routers  = ["http-router-test"]

    alb_virtual_hosts = {
      "virtual-host-a" = {
        http_router_name = "http-router-test"
        authority = ["site-a.example.net"]
        route = {
          name = "http-virtual-route-a"
          http_route = {
            http_route_action = {
              backend_group_name = "test-bg-a"
            }
          }
        }
      },
      "virtual-host-b" = {
        http_router_name = "http-router-test"
        authority = ["site-b.example.net"]
        route = {
          name = "http-virtual-route-b"
          http_route = {
            http_route_action = {
              backend_group_name = "test-bg-b"
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
        name = "test-listener-http"
        endpoint = {
          address = {
            external_ipv4_address = {}
          }
          ports = ["80"]
        }
        http = {
          handler = {
            http_router_name = "http-router-test"
          }
        }
      }
    ]

    log_options = {
      disable = true
    }
  }
}
