network_id           = "<VPC_NETWORK_ID>"
public_dns_zone_id   = "<PUBLIC_DNS_ZONE_ID>"
public_dns_zone_name = "<PUBLIC_DNS_ZONE_NAME>"

alb_load_balancer   = {
  name = "alb-test"

  alb_target_groups  = {
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
          subnet_id  = "<SUBNET-ID-B>"
          ip_address = "<INSTANCE-IP>"
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
          healthcheck = {
            healthcheck_port = 80
            http_healthcheck = {
              path = "/"
            }
          }
          target_groups_names_list     = ["target-group-a"]
          //existing_target_groups_ids = ["<TARGET-GROUP-A-ID>"]
        }
      ]
    },
    "test-bg-b"              = {
      http_backends          = [
        {
          name               = "test-backend-b"
          port               = 80
          weight             = 100
          healthcheck = {
            healthcheck_port = 80
            http_healthcheck = {
              path = "/"
            }
          }
          target_groups_names_list     = ["target-group-b"]
          //existing_target_groups_ids = ["<TARGET-GROUP-B-ID>"]
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