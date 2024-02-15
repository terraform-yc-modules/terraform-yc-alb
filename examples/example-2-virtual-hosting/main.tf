data "yandex_client_config" "client" {}

module "alb" {
  source               = "../../"
  network_id           = "<VPC_NETWORK_ID>"
  public_dns_zone_id   = "<PUBLIC_DNS_ZONE_ID>"
  public_dns_zone_name = "<PUBLIC_DNS_ZONE_NAME>"

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
    name = "vhosting-alb"

    alb_target_groups = {
      "target-group-a" = {
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
            subnet_id  = "<SUBNET-ID-C>"
            ip_address = "<INSTANCE-IP>"
          }
        ]
      },
      "target-group-b" = {
        targets = [
          {
            subnet_id  = "<SUBNET-ID-A>"
            ip_address = "<INSTANCE-IP>"
          },
          {
            ip_address           = "<INSTANCE-IP>"
            private_ipv4_address = true
          },
          {
            subnet_id  = "<SUBNET-ID-C>"
            ip_address = "<INSTANCE-IP>"
          }
        ]
      }
    }

    alb_backend_groups = {
      "vhosting-bg-a" = {
        http_backends = [
          {
            name   = "vhosting-backend-a"
            port   = 80
            weight = 100
            healthcheck = {
              healthcheck_port = 80
              http_healthcheck = {
                path = "/"
              }
            }
            target_groups_names_list = ["target-group-a"]
          }
        ]
      },
      "vhosting-bg-b" = {
        http_backends = [
          {
            name   = "vhosting-backend-b"
            port   = 80
            weight = 100
            healthcheck = {
              healthcheck_port = 80
              http_healthcheck = {
                path = "/"
              }
            }
            target_groups_names_list = ["target-group-b"]
          }
        ]
      }
    }

    alb_http_routers = ["vhosting-router-a", "vhosting-router-b", "vhosting-router-default"]

    alb_virtual_hosts = {
      "vhosting-vhost-a" = {
        http_router_name = "vhosting-router-a"
        authority        = ["site-a.vhosting.example.net"]
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
        authority        = ["site-b.vhosting.example.net"]
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
        authority        = ["default.vhosting.example.net"]
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
        zone      = "ru-central1-a"
        subnet_id = "<SUBNET-ID-ZONE-A>"
      },
      {
        zone      = "ru-central1-b"
        subnet_id = "<SUBNET-ID-ZONE-B>"
      },
      {
        zone      = "ru-central1-d"
        subnet_id = "<SUBNET-ID-ZONE-D>"
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
            cert_name = "vhosting-certificate-default" // a name of CM certificate
          }
          sni_handlers = [
            {
              name         = "vhosting-sni-a"
              server_names = ["site-a.vhosting.example.net"]
              handler = {
                http_handler = {
                  http_router_name = "vhosting-router-a"
                }
                cert_name = "vhosting-certificate-a"
                //certificate_ids = ""
              }
            },
            {
              name         = "vhosting-sni-b"
              server_names = ["site-b.vhosting.example.net"]
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
