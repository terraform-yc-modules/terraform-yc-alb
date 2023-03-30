data "yandex_client_config" "client" {}

module "alb" {
  source              = "../../"
  network_id          = "enpneopbt180nusgut3q"
  
  # Certificate Manager
  create_certificate = true
  using_self_signed  = true
  alb_certificates = [
    {
      name = "vhosting-certificate-a"
      self_managed = {
        certificate_filename = "site-a/server.crt"
        private_key_filename = "site-a/server.key"
      }
    },
    {
      name = "vhosting-certificate-b"
      self_managed = {
        certificate_filename = "site-b/server.crt"
        private_key_filename = "site-b/server.key"
      }
    },
    {
      name = "vhosting-certificate-default"
      self_managed = {
        certificate_filename = "site-default/server.crt"
        private_key_filename = "site-default/server.key"
      }
    }
  ]

  // ALB load balancer
  alb_load_balancer = {
    name                     = "vhosting-alb"

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

    alb_backend_groups  = {
      "vhosting-bg-a" = {
        http_backends  = [
          {
            name   = "vhosting-backend-a"
            port   = 80
            weight = 100
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
      "vhosting-bg-b" = {
        http_backends  = [
          {
            name   = "vhosting-backend-b"
            port   = 80
            weight = 100
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

    alb_http_routers  = ["vhosting-router-a","vhosting-router-b","vhosting-router-default"]

    alb_virtual_hosts = {
      "vhosting-vhost-a" = {
        http_router_name = "vhosting-router-a"
        authority = ["site-a.vhosting.express42.net"]
        route = {
          name = "vhosting-route-a"
          http_route = {
            http_route_action = {
              backend_group_name = "vhosting-bg-a"
            }
          }
        }
      },
      "vhosting-vhost-b" = {
        http_router_name = "vhosting-router-b"
        authority = ["site-b.vhosting.express42.net"]
        route = {
          name = "vhosting-route-b"
          http_route = {
            http_route_action = {
              backend_group_name = "vhosting-bg-b"
            }
          }
        }
      },
      "vhosting-vhost-default" = {
        http_router_name = "vhosting-router-default"
        authority = ["default.vhosting.express42.net"]
        route = {
          name = "vhosting-route-a"
          http_route = {
            http_route_action = {
              backend_group_name = "vhosting-bg-a"
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
        name = "vhosting-listener-http"
        endpoint = {
          address = {
            external_ipv4_address = {}
          }
          ports = ["80"]
        }
        http = {
          redirects = {
            http_to_https = true
          }
        }
      },
      {
        name = "vhosting-listener-https"
        endpoint = {
          address = {
            external_ipv4_address = {}
          }
          ports = ["443"]
        }
        tls = {
          default_handler = {
            http_handler = {
              http_router_name = "vhosting-router-default"
            }
            cert_name = "vhosting-certificate-default"  // a name of CM certificate
          }
          sni_handlers = [
            {
              name = "vhosting-sni-a"
              server_names = ["site-a.vhosting.express42.net"]
              handler = {
                http_handler = {
                  http_router_name = "vhosting-router-a"
                }
                cert_name = "vhosting-certificate-a"
                //certificate_ids = ""
              }
            },
            {
              name = "vhosting-sni-b"
              server_names = ["site-b.vhosting.express42.net"]
              handler = {
                http_handler = {
                  http_router_name = "vhosting-router-b"
                }
                cert_name = "vhosting-certificate-b"
              }
            }
          ]
        }
      }
    ]

    log_options = {
      disable = true
    }
  }
}
