# Application Load Balancer (ALB) module for Yandex.Cloud

## Features

- Create Application Load Balancer and all it components
- Create managed or self signed CM certificates for ALB on demand
- Create a DNS record with external ALB IP address
- Create a security group with default rules and define custom security rules
- Easy to use in other resources via outputs

## ALB definition

First of all, Application Load Balancer requires the following input data: 
1. One or more VPC networks with subnets (you will need to specify network ID, zone names, and subnet IDs).
2. Security group with all required ingress and egress rules.
3. Public DNS zone for ALB certificate (for this, you will need public zone ID).
4. Virtual machine group that will act as a target group.

Next, you need to define a variable that describes all required ALB components:
 - `alb_load_balancer` : Map of all ALB components, such as target groups, backend groups, HTTP routers, virtual hosts, ALB locations, and ALB listeners.

For ALB TLS listeners, you need to:
1. Set the `create_certificate` parameter value to `true`.
2. Define the `alb_certificates` variable with all required certificates.
3. Specify `public_dns_zone_id`.
4. List `certificate_ids` for specifying uploaded certificates to Certificate Manager as a list of IDs.

> As an optional step, you can set a time interval using `cert_waiting_timer`. This is a timer for waiting until a certificate will be issued by Let's Encrypt.

> You can provide self managed certificates as both strings and file names.

<b>NOTES:</b>

1. `alb_load_balancer` variable describes parameters for all ALB component in a description section.
2. Flag `create_alb` is `true` by default, so all ALM components will be create by `alb_load_balancer` definition. If it is `false`, you should to provide an ID of existing ALB HTTP router to `http_router_id` variable and define only `alb_target_groups`, `alb_backend_groups` and `alb_virtual_hosts` structures.
3. `alb_backend_group` is linked with target groups by two additional variables - `target_groups_names_list` and `existing_target_groups_ids`.
3.1. First variable points to a list of target groups names defined in a `alb_target_groups` variable. These target groups will be created before backend group.
3.2. Second one defines a list of previously created target groups IDs. You should to know it's ID and pass it a list.
4. `ALB components dependencies` section describes dependencies between all ALB components.

### ALB component dependencies

ALB components are linked together with a name. The components are organized as a three-tier structure:
 - Top tier: Load balancer.
 - Middle tier: ALB listener, which may point to ALB HTTP router and other infrastructure elements.
 - Bottom tier: Target group.

The `canary_balancer` example shows these dependencies as a nested map of objects, while the `example-3-canary` example implements this scenario. You could find these examples in the `Examples` folder.

```
// this is just a pseudocode example
canary_balancer = {
  canary_listener = {
    canary_http_router = {
      canary-vh-production = {
        canary-bg-production = {
          canary-backend-blue = {
            target-group-prod-blue = {
              targets = []
            }
          },
          canary-backend-green = {
            target-group-prod-green = {
              targets = []
            }
          }
        }
      },
      canary-vh-staging = {
        canary-bg-staging = {
          canary-backend-blue = {
            target-group-stage-blue = {
              targets = []
            }
          },
          canary-backend-green = {
            target-group-stage-green = {
              targets = []
            }
          }
        }
      }
    }
  }
}
```

### ALB load balancer example

This example creates ALB load balancer with two target groups, HTTP and GRPC backend groups, two HTTP routers, virtual hosts for each backend group and ALB listeners with ALB locations.

```
module "alb" {
  source               = "../../"

  network_id           = "<NETWORK-ID>"
  public_dns_zone_id   = "<PUBLIC_DNS_ZONE_ID>"
  public_dns_zone_name = "<PUBLIC_DNS_ZONE_NAME>"
  
  // ALB load balancer
  alb_load_balancer = {
    name = "load-balancer-test"
    
    alb_target_groups  = {
      "target-group-test" = {
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
      }
    }

    alb_backend_groups          = {
      "http-backend-group-test" = {
        http_backends           = [
          {
            name                       = "http-backend"
            port                       = 8080
            weight                     = 100
            target_groups_names_list   = ["target-group-test"]  // link to target group name from alb_target_groups variable
            //existing_target_groups_ids = ["<EXISTING-TARGET-GROUP-ID-1>", "<EXISTING-TARGET-GROUP-ID-2>"] // link to the list of exsisting target groups ids
            healthcheck = {
              healthcheck_port = 8080
              http_healthcheck = {
                path           = "/"
              }
            }
          }
        ]
      }
    }

    alb_http_routers  = ["http-router-test"]

    alb_virtual_hosts = {
      "virtual-router-test" = {
        http_router_name = "http-router-test"
        authority = ["test.example.com"]
        route = {
          name = "http-virtual-route"
          http_route = {
            http_route_action = {
              backend_group_name = "http-backend-group-test"
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
        name = "alb-listener-test"
        endpoint = {
          address = {
            external_ipv4_address = {}
          }
          ports = ["8080"]
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
```

### ALB components definition examples

`alb_load_balancer` defines next ALB components:

#### Target group 

```
alb_target_groups  = {
  "target-group-http" = {
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
  },
  "target-group-stream" = {
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
  },
  "target-group-grpc" = {
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
  }
}
```

#### Backend group 

Only one type of backends http_backend or grpc_backend or stream_backend should be specified.

```
alb_backend_groups  = {
  "http-bg" = {
    http_backends  = [
      {
        name   = "http-backend"
        port   = 80
        weight = 100
        http2  = "true"
        load_balancing_config = {
          panic_threshold = 50
          locality_aware_routing_percent = 50
          mode = "ROUND_ROBIN" // Value: ROUND_ROBIN, RANDOM, LEAST_REQUEST, MAGLEV_HASH
        }
        healthcheck = {
          healthcheck_port = 80
          timeout = "1s"
          interval = "1s"
          interval_jitter_percent = 50
          healthy_threshold = 50
          unhealthy_threshold = 50
          http_healthcheck = {
            host = ""
            path = "/"
            http2 = true
          }
        }
        target_groups_names_list     = ["target-group-http"]  // link to target group name from alb_target_groups variable
        //existing_target_groups_ids = ["<EXISTING-TARGET-GROUP-ID-1>", "<EXISTING-TARGET-GROUP-ID-2>"] // link to the list of exsisting target groups ids
      }
    ]
  },
  "stream-bg" = {
    stream_backends  = [
      {
        name   = "stream-backend"
        port   = 80
        weight = 100
        load_balancing_config = {
          panic_threshold = 50
          locality_aware_routing_percent = 50
          strict_locality = ""
          mode = "ROUND_ROBIN" // Value: ROUND_ROBIN, RANDOM, LEAST_REQUEST, MAGLEV_HASH
        }
        healthcheck = {
          healthcheck_port = 80
          timeout = "1s"
          interval = "1s"
          interval_jitter_percent = 50
          healthy_threshold = 50
          unhealthy_threshold = 50
          stream_healthcheck = {
            send = ""
            receive = ""
          }
        }
        target_groups_names_list     = ["target-group-stream"]  // link to target group name from alb_target_groups variable
        //existing_target_groups_ids = ["<EXISTING-TARGET-GROUP-ID-1>", "<EXISTING-TARGET-GROUP-ID-2>"] // link to the list of exsisting target groups ids
      }
    ]
  },
  "grpc-bg" = {
    grpc_backends  = [
      {
        name   = "grpc-backend"
        port   = 80
        weight = 100
        load_balancing_config = {
          panic_threshold = 50
          locality_aware_routing_percent = 50
          mode = "ROUND_ROBIN" // Value: ROUND_ROBIN, RANDOM, LEAST_REQUEST, MAGLEV_HASH
        }
        healthcheck = {
          healthcheck_port = 80
            timeout = "1s"
            interval = "1s"
            interval_jitter_percent = 50
            healthy_threshold = 50
            unhealthy_threshold = 50
          grpc_healthcheck = {
            service_name = "<grpc-service-name>"
          }
        }
        target_groups_names_list     = ["target-group-grpc"]  // link to target group name from alb_target_groups variable
        //existing_target_groups_ids = ["<EXISTING-TARGET-GROUP-ID-1>", "<EXISTING-TARGET-GROUP-ID-2>"] // link to the list of exsisting target groups ids
      }
    ]
  }
}
```

#### HTTP router

This list describes two HTTP routers with default values.

```
alb_http_routers  = ["http-router-a","http-router-b"]
```

#### Virtual host 

```
alb_virtual_hosts = {
  "vhost-a" = {
    http_router_name = "http-router-a"
    authority = ["site-a.example.net"]
    // Only one type of actions append or replace or remove should be specified.
    modify_request_headers = {
      name = "vhost-a-modify-request-headers"
      append = ""
      // replace
      // remove = ""
    }
    modify_response_headers = {
      name = "vhost-a-modify-response-headers"
      append = ""
      // replace
      // remove = ""
    }
    // Exactly one type of actions http_route_action or redirect_action or direct_response_action should be specified.
    route = {
      name = "route-a"
      http_route = {
        http_match = {
          http_method = ["GET"]
          path = "/"
        }
        http_route_action = {
          backend_group_name = "http-bg"  // link to backend group
          timeout = "60s"
          host_rewrite = "<host-rewrite-specifier>"
          prefix_rewrite = "<path-prefix>"
          upgrade_types = ["websocket"]
        }
      }
    }
  },
  "vhost-b" = {
    http_router_name = "http-router-b"
    authority = ["site-b.example.net"]
    route = {
      name = "route-b"
      grpc_route = {
        grpc_match = {
          fqmn = {
            prefix = "/prefix"
          }
        }
        grpc_route_action = {
          backend_group_name = "grpc-bg" // link to backend group
          max_timeout = "60s"
          idle_timeout = "60s"
          host_rewrite = "<host-rewrite-specifier>"
        }
      }
    }
  }
}
```

#### ALB Load balancer

ALB load balancer requires two structures - `alb_locations` and `alb_listeners` for it's definition.

Default parameters:
  - description - (Optional) A description of the ALB Load Balancer.
  - labels - (Optional) A set of key/value label pairs to assign ALB Load Balancer.
  - region_id - (Optional) ID of the region that the Load Balancer is located at.
  - network_id - (Required) ID of the network that the Load Balancer is located at.
  - security_groups_ids - (Optional) A list of ID's of security groups attached to the Load Balancer.

Mandatory parameters:
  - alb_allocations - (Required) Allocation zones for the Load Balancer instance.
    - alb_locations is using for it's definition
  - listener - (Optional) List of listeners for the Load Balancer.
    - name - (Required) Name of the backend.
    - endpoint  - (Required) Network endpoints (addresses and ports) of the listener.
      - address - (Required) One or more addresses to listen on. Exactly one type of addresses external_ipv4_address or internal_ipv4_address or external_ipv6_address should be specified.
        - external_ipv4_address - (Optional) External IPv4 address.
          - address - (Optional) Provided by the client or computed automatically.
        - internal_ipv4_address - (Optional) Internal IPv4 address.
          - address - (Optional) Provided by the client or computed automatically.
          - subnet_id - (Optional) Provided by the client or computed automatically
        - external_ipv6_address - (Optional) External IPv6 address.
          - address - (Optional) Provided by the client or computed automatically. 
      - ports - (Required) One or more ports to listen on.
    - http - (Optional) HTTP listener resource.
    - stream - (Optional) Stream listener resource.
    - tls - (Optional) TLS listener resource.

Exactly one listener type: http or tls or stream should be specified.

```
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
    name = "listener-http"
    endpoint = {
      address = {
        // Exactly one type of addresses external_ipv4_address or internal_ipv4_address or external_ipv6_address should be specified.
        external_ipv4_address = {
          adress = "<ADDRESS>"    // if empty it will be computed automatically
        }
        //internal_ipv4_address = {}
        //external_ipv6_address = {}
      }
      ports = ["80"]
    }
    // Exactly one listener type: http or tls or stream should be specified.
    http = {
      redirects = {
        http_to_https = true
      }
    }
  },
  {
    name = "listener-stream"
    endpoint = {
      address = {
        external_ipv4_address = {}
      }
      ports = ["8081"]
    }
    // Exactly one listener type: http or tls or stream should be specified.
    stream = {
      handler = {
        backend_group_name = "stream-backend" // link to backend group
      }
    }
  },
  {
    name = "listener-https-tls"
    endpoint = {
      address = {
        external_ipv4_address = {}  // if empty it will be computed automatically
      }
      ports = ["443"]
    }
    tls = {
      default_handler = {
        http_handler = {
          http_router_name = "router-default"
        }
        certificate_ids = ["asddj6ugadf43522dfsa"]  // certificate id from Certificate Manager 
      }
      sni_handlers = [
        {
          name = "vhosting-sni-a"
          server_names = ["site-a.example.net"]
          handler = {
            http_handler = {
              http_router_name = "http-router-a"
            }
            cert_name = "certificate-a"
          }
        },
        {
          name = "sni-b"
          server_names = ["site-b.example.net"]
          handler = {
            http_handler = {
              http_router_name = "http-router-b"
            }
            cert_name = "certificate-b" // a name of certificate from `alb_certificates` variable
          }
        }
      ]
    }
  }
]

// Cloud Logging settings
log_options = {
  disable = false
  discard_rule {
    http_code_intervals = ["2XX"]
    discard_percent = 75
  }
}
```

```
A common ALB use case is a virtual hosting. Example 2 implements this scenario. 
Example 3 defines a canary (blue-green) deployment scenario.
```

### ALB CM certificates

You can define ALB certificates with the `alb_certificates` variable. It supports two types of certificates: managed and self signed. A managed certificate is issued by Let's Encrypt, it requires `domains` list and managed options, such as `challenge_type` and `challenge_count`. Self signed certificates can be created on your own, e.g., using the OpenSSL tool.

The ALB module uses the following variables:
1. `create_certificate`: Flag that enables or disables a block with a CM certificate.
2. `using_self_signed`: Set it to `true` if you are using a self-signed certificate.
3. `alb_certificates`: List of all certificates.
4. `public_dns_zone_id`: Public DNS zone ID for issuing certificates with Let's Encrypt.
5. `cert_waiting_timer`: Timer for waiting for a certificate issued by Let's

The following examples describe managed and self-signed certificates:

```
// Managed certificates
module "alb" {
  source              = "../../"
  network_id          = "NETWORK_ID"
  
  create_certificate = true
  using_self_signed  = true
  alb_certificates = [
    {
      name    = "certificate-a"
      domains = ["app-a.example.net"]
      managed = {
        challenge_type  = "DNS_CNAME"
        challenge_count = 1
      }
    },
    {
      name    = "certificate-b"
      domains = ["app-b.example.net"]
      managed = {
        challenge_type  = "DNS_CNAME"
        challenge_count = 1
      }
    }
  ]
  public_dns_zone_id = "PUBLIC_DNS_ZONE_ID"
  cert_waiting_timer = "600s"   // waiting 10 minutes until CM certificates will be ISSUED

  // ...
}

// Self signed certificates
module "alb" {
  source              = "../../"
  network_id          = "NETWORK_ID"
  
  # Certificate Manager
  create_certificate = true
  using_self_signed  = true
  alb_certificates = [
    {
      name    = "certificate-a"
      self_managed = {
        certificate_filename = "site-a/server.crt"
        private_key_filename = "site-a/server.key"
      }
    },
    {
      name    = "certificate-b"
      self_managed = {
        certificate_filename = "site-b/server.crt"
        private_key_filename = "site-b/server.key"
      }
    }
  ]

  // ...
}
```

### How to configure Terraform for Yandex Cloud

- Install [YC CLI](https://cloud.yandex.com/docs/cli/quickstart)
- Add environment variables for terraform auth in Yandex.Cloud

```
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | > 3.3 |
| <a name="requirement_time"></a> [time](#requirement\_time) | 0.9.1 |
| <a name="requirement_yandex"></a> [yandex](#requirement\_yandex) | >= 0.88.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.5.1 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.9.1 |
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) | 0.89.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [random_string.unique_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.wait_for_cert_will_be_issued](https://registry.terraform.io/providers/hashicorp/time/0.9.1/docs/resources/sleep) | resource |
| [yandex_alb_backend_group.backend_group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_backend_group) | resource |
| [yandex_alb_http_router.http_router](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_http_router) | resource |
| [yandex_alb_load_balancer.alb_load_balancer](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_load_balancer) | resource |
| [yandex_alb_target_group.target_group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_target_group) | resource |
| [yandex_alb_virtual_host.virtual_router](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_virtual_host) | resource |
| [yandex_cm_certificate.alb_cm_certificate](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/cm_certificate) | resource |
| [yandex_dns_recordset.alb_cm_certificate_dns_name](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/dns_recordset) | resource |
| [yandex_dns_recordset.alb_external_ip_dns_name](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/dns_recordset) | resource |
| [yandex_vpc_security_group.alb_custom_rules_sg](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group) | resource |
| [yandex_vpc_security_group.alb_main_sg](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group) | resource |
| [yandex_vpc_security_group_rule.egress_rules](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group_rule) | resource |
| [yandex_vpc_security_group_rule.ingress_rules](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group_rule) | resource |
| [yandex_client_config.client](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_backend_groups_labels"></a> [alb\_backend\_groups\_labels](#input\_alb\_backend\_groups\_labels) | Default backend group labels | `map(string)` | <pre>{<br>  "created_by": "terraform_yc_module"<br>}</pre> | no |
| <a name="input_alb_certificates"></a> [alb\_certificates](#input\_alb\_certificates) | List of maps for ALB certificates.<br><br>    Notes:<br>      - Use only one type, either `managed` or `self_managed`<br>      - Resource creation awaits getting challenges from issue provider.<br>      - Self-managed certificates support only one type of `private_key` or `private_key_lockbox_secret`<br>      - You can provide self managed certificates and private keys as both strings and file names.<br>      - All self-signed certificates must be located in `<path.module>/content/tls/<your_folder>`.<br>      - Self-managed private keys can be read from Lockbox; for this, you need to specify the Lockbox private key secret ID and secret key.<br><br>    Parameters:<br>      - name<br>      - description<br>      - labels<br>      - domains - a list of domains for this certificate.<br>      - managed:<br>        - challenge\_type - (Required) Domain owner-check method. Possible values:<br>          "DNS\_CNAME" - you will need to create a CNAME dns record with the specified value. Recommended for fully automated certificate renewal;<br>          "DNS\_TXT" - you will need to create a TXT dns record with specified value;<br>          "HTTP" - you will need to place specified value into specified url.<br>        - challenge\_count - (Optional). Expected number of challenge count needed to validate certificate.<br>      - self\_managed:<br>        - certificate\_string         - (Required) Certificate as a string with chain.<br>        - private\_key\_string         - (Optional) Private key as a string of certificate.<br>        - certificate\_filename       - (Required) Certificate filename with chain.<br>        - private\_key\_filename       - (Optional) Private key filename of certificate.<br>        - private\_key\_lockbox\_secret - (Optional) Lockbox secret specification for getting private key.<br>          - private\_key\_lockbox\_secret\_id<br>          - private\_key\_lockbox\_secret\_key | `any` | `{}` | no |
| <a name="input_alb_certificates_labels"></a> [alb\_certificates\_labels](#input\_alb\_certificates\_labels) | Default certificates labels | `map(string)` | <pre>{<br>  "created_by": "terraform_yc_module"<br>}</pre> | no |
| <a name="input_alb_http_routers_labels"></a> [alb\_http\_routers\_labels](#input\_alb\_http\_routers\_labels) | Default ALB HTTP Routers labels | `map(string)` | <pre>{<br>  "created_by": "terraform_yc_module"<br>}</pre> | no |
| <a name="input_alb_load_balancer"></a> [alb\_load\_balancer](#input\_alb\_load\_balancer) | ALB load balancer map that defines all required resources for target groups, backend groups, HTTP routers, virtual hosts and alb load balancer.<br><br>    Required components:<br>      1. Target groups<br>      2. Backend groups<br>      3. HTTP routers<br>      4. Virtual hosts<br>      5. Load balancer<br><br>    1. Target groups<br><br>      A map of maps for each target group<br><br>      Parameters:<br>        - targets - a list of targets<br>          - ip\_address - (Required) IP address of the target.<br>          - subnet\_id - (Required) ID of the subnet that targets are connected to. All targets in the target group must be connected to the same subnet within a single availability zone.<br>          - private\_ipv4\_address - (Optional) Boolean. If it is True, ip\_address is only required parameter, subnet\_id needs to be omited.<br><br>      Example:<pre>alb_target_groups  = {<br>          "target-group-1" = {<br>            targets = [<br>              {<br>                subnet_id  = "e9b5udt8asf9r9qn6nf6"<br>                ip_address = "10.128.0.1"<br>              },<br>              {<br>                subnet_id  = "e2lu07tr481h35012c8p"<br>                ip_address = "10.129.0.1"<br>              },<br>              {<br>                ip_address = "10.130.0.1"<br>                private_ipv4_address = true<br>              }<br>            ]<br>          }<br>        }</pre>2. Backend groups<br><br>      A map for maps for each Backend group<br><br>      Parameters:<br>        - name        - Name of the Backend Group.<br>        - labels      - Labels to assign to this backend group.<br>        - backend<br>          - http\_backend - (Optional) Http backend specification that will be used by the ALB Backend Group.<br>          - grpc\_backend - (Optional) Grpc backend specification that will be used by the ALB Backend Group.<br>          - stream\_backend - (Optional) Stream backend specification that will be used by the ALB Backend Group.<br><br>        Backend parameters:<br>          - name - (Required) Name of the backend.<br>          - port - (Optional) Port for incoming traffic.<br>          - weight - (Optional) Weight of the backend. Traffic will be split between backends of the same BackendGroup according to their weights.<br>          - http2 - (Optional) Enables HTTP2 for upstream requests. If not set, HTTP 1.1 will be used by default.<br>          - target\_group\_ids - (Required) References target groups for the backend.<br>          - load\_balancing\_config - (Optional) Load Balancing Config specification that will be used by this backend.<br>            - panic\_threshold - (Optional) If percentage of healthy hosts in the backend is lower than panic\_threshold, traffic will be routed to all backends no matter what the health status is. This helps to avoid healthy backends overloading when everything is bad. Zero means no panic threshold.<br>            - locality\_aware\_routing\_percent - (Optional) Percent of traffic to be sent to the same availability zone. The rest will be equally divided between other zones.<br>            - strict\_locality - (Optional) If set, will route requests only to the same availability zone. Balancer won't know about endpoints in other zones.<br>            - mode - (Optional) Load balancing mode for the backend. Possible values: "ROUND\_ROBIN", "RANDOM", "LEAST\_REQUEST", "MAGLEV\_HASH".<br>          - healthcheck - (Optional) Healthcheck specification that will be used by this backend. <br>            - timeout - (Required) Time to wait for a health check response.<br>            - interval - (Required) Interval between health checks.<br>            - interval\_jitter\_percent - (Optional) An optional jitter amount as a percentage of interval. If specified, during every interval value of (interval\_ms * interval\_jitter\_percent / 100) will be added to the wait time.<br>            - healthy\_threshold - (Optional) Number of consecutive successful health checks required to promote endpoint into the healthy state. 0 means 1. Note that during startup, only a single successful health check is required to mark a host healthy.<br>            - unhealthy\_threshold - (Optional) Number of consecutive failed health checks required to demote endpoint into the unhealthy state. 0 means 1. Note that for HTTP health checks, a single 503 immediately makes endpoint unhealthy.<br>            - healthcheck\_port - (Optional) Optional alternative port for health checking.<br>            - stream\_healthcheck - (Optional) Stream Healthcheck specification that will be used by this healthcheck. Structure is documented below.<br>              - send - (Optional) Message sent to targets during TCP data transfer. If not specified, no data is sent to the target.<br>              - receive - (Optional) Data that must be contained in the messages received from targets for a successful health check. If not specified, no messages are expected from targets, and those that are received are not checked.<br>            - http\_healthcheck - (Optional) Http Healthcheck specification that will be used by this healthcheck. Structure is documented below.<br>              - host - (Optional) "Host" HTTP header value.<br>              - path - (Required) HTTP path.<br>              - http2 - (Optional) If set, health checks will use HTTP2.<br>            - grpc\_healthcheck - (Optional) Grpc Healthcheck specification that will be used by this healthcheck. Structure is documented below.<br>              - service\_name - (Optional) Service name for grpc.health.v1.HealthCheckRequest message.<br>          - tls - (Optional) Tls specification that will be used by this backend.<br>            - sni - (Optional) SNI string for TLS connections.<br>            - validation\_context.0.trusted\_ca\_id - (Optional) Trusted CA certificate ID in the Certificate Manager.<br>            - validation\_context.0.trusted\_ca\_bytes - (Optional) PEM-encoded trusted CA certificate chain.<br> <br>        Notes:<br>          1. Only one type of backends http\_backend or grpc\_backend or stream\_backend should be specified.<br>          2. Only one of validation\_context.0.trusted\_ca\_id or validation\_context.0.trusted\_ca\_bytes should be specified.<br>          3. Only one of stream\_healthcheck or http\_healthcheck or grpc\_healthcheck should be specified.<br><br>        How backend group is linked with target group:<br>          1. First of all, target\_groups\_names\_list variable is a list of target groups names from alb\_target\_groups variable. These target groups will be created before backend group!<br>          2. Second, existing\_target\_groups\_ids variable is a list of existing target groups IDs. Use it if you want to link backend group with an existing target groups.<br><br>      Example:<pre>alb_backend_groups         = {<br>          "test-bg-a"              = {<br>            http_backends          = [<br>              {<br>                name               = "bg-a"<br>                port               = 80<br>                weight             = 100<br>                healthcheck = {<br>                  healthcheck_port = 80<br>                  http_healthcheck = {<br>                    path = "/"<br>                  }<br>                }<br>                // <br>                target_groups_names_list   = ["tg-a"]<br>                //existing_target_groups_ids = ["<TG1-ID>", "TG2-ID"]<br>              }<br>            ]<br>          },<br>          "test-bg-b"              = {<br>            http_backends          = [<br>              {<br>                name               = "bg-b"<br>                port               = 80<br>                weight             = 100<br>                healthcheck = {<br>                  healthcheck_port = 80<br>                  http_healthcheck = {<br>                    path = "/"<br>                  }<br>                }<br>                target_groups_names_list   = ["tg-b"]<br>                //existing_target_groups_ids = ["<TG1-ID>", "TG2-ID"]<br>              }<br>            ]<br>          }<br>        }</pre>3. HTTP routers<br><br>      A list of HTTP routers names<br><br>      Example:<pre>alb_http_routers  = ["http-router-1", "http-router-2"]</pre>4. Virtual hosts<br><br>      ALB virtual hosts map of maps.<br>      ALB virtual host support only two types of routes - HTTP and GRPC. Stream is not supported!<br><br>      Parameters:<br>        - name - Name of a specific ALB virtual router.<br>        - http\_router\_id - (Required) The ID of the HTTP router to which the virtual host belongs.<br>        - authority - (Optional) A list of domains (host/authority header) that will be matched to this virtual host.<br>          Wildcard hosts are supported in the form of '.foo.com' or '-bar.foo.com'. <br>          If not specified, all domains will be matched.<br>        - modify\_request\_headers OR modify\_response\_headers - Apply the following modifications to the request or response headers.<br>            - name - (Required) name of the header to modify.<br>            - append - (Optional) Append string to the header value.<br>            - replace - (Optional) New value for a header. Header values support the following formatters.<br>            - remove - (Optional) If set, remove the header.<br>        - route - (Optional) A Route resource. Routes are matched in-order. <br>          Be careful when adding them to the end. For instance, having http '/' match first makes all other routes unused. <br>            - name - (Required) name of the route.<br>            - http\_route - (Optional) HTTP route resource.<br>              - http\_match - (Optional) Checks "/" prefix by default.<br>                - http\_method - (Optional) List of methods(strings).<br>                - path - (Optional) If not set, '/' is assumed.<br>                  - exact - (Optional) Match exactly.<br>                  - prefix - (Optional) Match prefix.<br>                  - regex - (Optional) Match regex.<br>              - http\_route\_action - (Optional) HTTP route action resource.<br>                - backend\_group\_id - (Required) Backend group to route requests.<br>                - timeout - (Optional) Specifies the request timeout (overall time request processing is allowed to take) for the route. If not set, default is 60 seconds.<br>                - idle\_timeout - (Optional) Specifies the idle timeout (time without any data transfer for the active request) for the route. It is useful for streaming scenarios (i.e. long-polling, server-sent events) - one should set idle\_timeout to something meaningful and timeout to the maximum time the stream is allowed to be alive. If not specified, there is no per-route idle timeout.<br>                - host\_rewrite - (Optional) Host rewrite specifier.<br>                - auto\_host\_rewrite - (Optional) If set, will automatically rewrite host.<br>                - prefix\_rewrite - (Optional) If not empty, matched path prefix will be replaced by this value.<br>                - upgrade\_types - (Optional) List of upgrade types. Only specified upgrade types will be allowed. For example, "websocket".<br>              - redirect\_action - (Optional) Redirect action resource.<br>                - replace\_scheme - (Optional) Replaces scheme. If the original scheme is http or https, will also remove the 80 or 443 port, if present.<br>                - replace\_host - (Optional) Replaces hostname.<br>                - replace\_port - (Optional) Replaces port.<br>                - replace\_path - (Optional) Replace path.<br>                - replace\_prefix - (Optional) Replace only matched prefix. <br>                  Example: match:{ prefx\_match: "/some" }<br>                          redirect: { replace\_prefix: "/other" }<br>                          will redirect "/something" to "/otherthing".<br>                - remove query - (Optional) If set, remove query part.<br>                - response\_code - (Optional) The HTTP status code to use in the redirect response. Supported values are: moved\_permanently, found, see\_other, temporary\_redirect, permanent\_redirect.<br>              - direct\_response\_action - (Required) Direct response action resource.<br>                - status - (Optional) HTTP response status. Should be between 100 and 599.<br>                - body - (Optional) Response body text.<br>            - grpc\_route - (Optional) GRPC route resource.<br>              - grpc\_match - (Optional) Checks "/" prefix by default.<br>                - fqmn - (Optional) If not set, all services/methods are assumed.<br>                  - exact - (Optional) Match exactly.<br>                  - prefix - (Optional) Match prefix.<br>                  - regex - (Optional) Match regex.<br>              - grpc\_route\_action - (Optional) GRPC route action resource.<br>                - backend\_group\_id - (Required) Backend group to route requests.<br>                - max\_timeout - (Optional) Lower timeout may be specified by the client (using grpc-timeout header). If not set, default is 60 seconds.<br>                - idle\_timeout - (Optional) Specifies the idle timeout (time without any data transfer for the active request) for the route. It is useful for streaming scenarios - one should set idle\_timeout to something meaningful and max\_timeout to the maximum time the stream is allowed to be alive. If not specified, there is no per-route idle timeout.<br>                - host\_rewrite - (Optional) Host rewrite specifier.<br>                - auto\_host\_rewrite - (Optional) If set, will automatically rewrite host.<br>              - grpc\_status\_response\_action - (Required) GRPC status response action resource.<br>                - status - (Optional) The status of the response. Supported values are: ok, invalid\_argumet, not\_found, permission\_denied, unauthenticated, unimplemented, internal, unavailable.<br>  <br>      Notes:<br>        - Exactly one listener type: http or tls or stream should be specified.<br>        - Exactly one type of addresses external\_ipv4\_address or internal\_ipv4\_address or external\_ipv6\_address should be specified.<br>        - Only one type of HTTP protocol settings http2\_options or allow\_http10 should be specified.<br>        - For modify\_request\_headers OR modify\_response\_headers only one type of actions 'append' or 'replace' or 'remove' should be specified.<br>        - Exactly one type of actions http\_route\_action or redirect\_action or direct\_response\_action should be specified.<br>        - Only one type of host rewrite specifiers host\_rewrite or auto\_host\_rewrite should be specified.<br>        - Only one type of paths replace\_path or replace\_prefix should be specified.<br>        - Exactly one type of actions grpc\_route\_action or grpc\_status\_response\_action should be specified.<br>        - Only one type of host rewrite specifiers host\_rewrite or auto\_host\_rewrite should be specified.<br>        - Exactly one type of string matches exact, prefix or regex should be specified.<br><br>      How virtual host is linked with HTTP router and Backend group?<br>        1. http\_router\_name variable is a link to HTTP router name.<br>        2. backend\_group\_name variable is a link to Backend group.<br><br>      Example:<pre>alb_virtual_hosts = {<br>          "virtual-router-1" = {<br>            http_router_name = "http-router-1"<br>            route = {<br>              name = "http-virtual-route"<br>              http_route = {<br>                http_route_action = {<br>                  backend_group_name = "http-backend-group-1"<br>                }<br>              }<br>            }<br>          }<br>        }</pre>5. ALB load balancer<br><br>      Default parameters:<br>        - description - (Optional) A description of the ALB Load Balancer.<br>        - labels - (Optional) A set of key/value label pairs to assign ALB Load Balancer.<br>        - region\_id - (Optional) ID of the region that the Load Balancer is located at.<br>        - network\_id - (Required) ID of the network that the Load Balancer is located at.<br>        - security\_groups\_ids - (Optional) A list of ID's of security groups attached to the Load Balancer.<br><br>      All supported parameters:<br>        - alb\_locations - (Required) Allocation zones for the Load Balancer instance.<br>          - zone      - (Required) ID of the zone that location is located at.<br>          - subnet\_id - (Required) ID of the subnet that location is located at.<br>          - disable\_traffic - (Optional) If set, will disable all L7 instances in the zone for request handling.<br>        - listener - (Optional) List of listeners for the Load Balancer.<br>          - name - (Required) Name of the backend.<br>          - endpoint  - (Required) Network endpoints (addresses and ports) of the listener.<br>            - address - (Required) One or more addresses to listen on.<br>              - external\_ipv4\_address - (Optional) External IPv4 address.<br>                - address - (Optional) Provided by the client or computed automatically.<br>              - internal\_ipv4\_address - (Optional) Internal IPv4 address.<br>                - address - (Optional) Provided by the client or computed automatically.<br>                - subnet\_id - (Optional) Provided by the client or computed automatically<br>              - external\_ipv6\_address - (Optional) External IPv6 address.<br>                - address - (Optional) Provided by the client or computed automatically.<br>            - ports   - (Required) One or more ports to listen on.<br>          - http - (Optional) HTTP listener resource. Note: Only one type of fields handler or redirects should be specified.<br>            - handler - (Optional) HTTP handler that sets plaintext HTTP router. The structure is documented below.<br>              - http\_router\_id - (Optional) HTTP router id.<br>              - rewrite\_request\_id - (Optional) When unset, will preserve the incoming x-request-id header, otherwise would rewrite it with a new value.<br>              - http2\_options - (Optional) If set, will enable HTTP2 protocol for the handler.<br>                - max\_concurrent\_streams - (Optional) Maximum number of concurrent streams.<br>              - allow\_http10 - (Optional) If set, will enable only HTTP1 protocol with HTTP1.0 support.<br>            - redirects - (Optional) Shortcut for adding http -> https redirects.<br>              - http\_to\_https - (Optional) If set redirects all unencrypted HTTP requests to the same URI with scheme changed to https.<br>          - stream - (Optional) Stream listener resource.<br>            - handler - (Optional) Stream handler that sets plaintext Stream backend group. <br>              - backend\_group\_id - (Optional) Backend group id.<br>          - tls - (Optional) TLS listener resource.<br>            - default\_handler - (Required) TLS handler resource.<br>              - http\_handler - (Required) HTTP handler resource.<br>                - http\_router\_id - (Optional) HTTP router id.<br>                - rewrite\_request\_id - (Optional) When unset, will preserve the incoming x-request-id header, otherwise would rewrite it with a new value.<br>                - http2\_options - (Optional) If set, will enable HTTP2 protocol for the handler.<br>                  - max\_concurrent\_streams - (Optional) Maximum number of concurrent streams.<br>                - allow\_http10 - (Optional) If set, will enable only HTTP1 protocol with HTTP1.0 support.<br>              - stream\_handler - (Required) Stream handler resource.<br>                - backend\_group\_id - (Optional) Backend group id.<br>              - certificate\_ids - (Required) Certificate IDs in the Certificate Manager. Multiple TLS certificates can be associated with the same context to allow both RSA and ECDSA certificates. Only the first certificate of each type will be used.<br>            - sni\_handler - (Optional) SNI match resource.<br>              - name - (Required) name of SNI match.<br>              - server\_names - (Required) A set of server names.<br>              - handler - (Required) TLS handler resource.<br>                - http\_handler - (Required) HTTP handler resource. The structure is documented below.<br>                - stream\_handler - (Required) Stream handler resource. The structure is documented below.<br>                - certificate\_ids - (Required) Certificate IDs in the Certificate Manager. Multiple TLS certificates can be associated with the same context to allow both RSA and ECDSA certificates. Only the first certificate of each type will be used.<br>        - log\_options - (Optional) Cloud Logging settings.<br>          - disable (Optional) Set to true to disable Cloud Logging for the balancer<br>          - log\_group\_id (Optional) Cloud Logging group ID to send logs to. Leave empty to use the balancer folder default log group.<br>          - discard\_rule (Optional) List of rules to discard a fraction of logs.<br>            - http\_codes (Optional) list of http codes 100-599<br>            - http\_code\_intervals (Optional) list of http code intervals 1XX-5XX or ALL<br>            - grpc\_codes (Optional) list of grpc codes by name, e.g, ["NOT\_FOUND", "RESOURCE\_EXHAUSTED"]<br><br>      Notes:<br>        1. Exactly one listener type: http or tls or stream should be specified.<br>        2. sni\_handler is a list of SNI handlers.<br>        3. if create\_certificate = true, certificate should be passed as a name of newly created certificates or as a list of previously created CM certificate ids.<br><br>      How ALB load balancers is linked with HTTP router and Backend group?<br>        1. http\_router\_name variable is a link to HTTP router name.<br>        2. backend\_group\_name variable is a link to Backend group.<br><br>      ALB TLS certificate could be passed by:<br>        1. certificate\_ids variable, it is a list of already created certificate ids<br>        2. cert\_name variable is a name for ONLY ONE certificate from alb\_certificates list!<br><br>      Example:<pre>alb_locations = [<br>          {<br>            zone      = "ru-central1-a"<br>            subnet_id = "<SUBNET-ID-ZONE-A>"<br>          },<br>          {<br>            zone     = "ru-central1-b"<br>            subnet_id = "<SUBNET-ID-ZONE-B>"<br>          },<br>          {<br>            zone      = "ru-central1-d"<br>            subnet_id = "<SUBNET-ID-ZONE-D>"<br>          }<br>        ]<br><br>        alb_listeners = [<br>          {<br>            name = "listener-http"<br>            endpoint = {<br>              address = {<br>                external_ipv4_address = {}<br>              }<br>              ports = ["80"]<br>            }<br>            http = {<br>              redirects = {<br>                http_to_https = true<br>              }<br>            }<br>          },<br>          {<br>            name = "listener-https"<br>            endpoint = {<br>              address = {<br>                external_ipv4_address = {}<br>              }<br>              ports = ["443"]<br>            }<br>            tls = {<br>              default_handler = {<br>                http_handler = {<br>                  http_router_name = "<ROUTER-DEFAULT>"<br>                }<br>                cert_name = "<DEFAULT-CERT-NAME>"  // a name of CM certificate<br>              }<br>              sni_handlers = [<br>                {<br>                  name = "sni-a"<br>                  server_names = ["site-a.example.net"]<br>                  handler = {<br>                    http_handler = {<br>                      http_router_name = "<ROUTER-A>"<br>                    }<br>                    cert_name = "<CERT-NAME-A>"<br>                  }<br>                },<br>                {<br>                  name = "vhosting-sni-b"<br>                  server_names = ["site-b.example.net"]<br>                  handler = {<br>                    http_handler = {<br>                      http_router_name = "<ROUTER-B>"<br>                    }<br>                    cert_name = "<CERT-NAME-B>"<br>                  }<br>                }<br>              ]<br>            }<br>          }<br>        ]<br><br>        log_options = {<br>          disable = true<br>        }</pre> | `any` | n/a | yes |
| <a name="input_alb_load_balancer_labels"></a> [alb\_load\_balancer\_labels](#input\_alb\_load\_balancer\_labels) | Default ALB Load Balancer labels | `map(string)` | <pre>{<br>  "created_by": "terraform_yc_module"<br>}</pre> | no |
| <a name="input_alb_target_group_labels"></a> [alb\_target\_group\_labels](#input\_alb\_target\_group\_labels) | Default target group labels | `map(string)` | <pre>{<br>  "created_by": "terraform_yc_module"<br>}</pre> | no |
| <a name="input_allowed_ips"></a> [allowed\_ips](#input\_allowed\_ips) | List of allowed IPv4 CIDR blocks | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_cert_waiting_timer"></a> [cert\_waiting\_timer](#input\_cert\_waiting\_timer) | A timer value for waiting until ALB TLS certificate will be ISSUED. | `string` | `"300s"` | no |
| <a name="input_create_alb"></a> [create\_alb](#input\_create\_alb) | Flag for enabling or disabling ALB load balancer creation | `bool` | `true` | no |
| <a name="input_create_certificate"></a> [create\_certificate](#input\_create\_certificate) | Flag for enabling / disabling creation of a CM certificates and DNS name for it. | `bool` | `false` | no |
| <a name="input_custom_egress_rules"></a> [custom\_egress\_rules](#input\_custom\_egress\_rules) | A map definition of custom security egress rules.<br><br>Example:<pre>custom_egress_rules = {<br>  "rule1" = {<br>    protocol       = "ANY"<br>    description    = "rule-1"<br>    v4_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]<br>    from_port      = 8090<br>    to_port        = 8099<br>  },<br>  "rule2" = {<br>    protocol       = "UDP"<br>    description    = "rule-2"<br>    v4_cidr_blocks = ["10.0.1.0/24"]<br>    from_port      = 8090<br>    to_port        = 8099<br>  }<br>}</pre> | `any` | `{}` | no |
| <a name="input_custom_ingress_rules"></a> [custom\_ingress\_rules](#input\_custom\_ingress\_rules) | A map definition of custom security ingress rules.<br><br>Example:<pre>custom_ingress_rules = {<br>  "rule1" = {<br>    protocol = "TCP"<br>    description = "rule-1"<br>    v4_cidr_blocks = ["0.0.0.0/0"]<br>    from_port = 3000<br>    to_port = 32767<br>  },<br>  "rule2" = {<br>    protocol = "TCP"<br>    description = "rule-2"<br>    v4_cidr_blocks = ["0.0.0.0/0"]<br>    port = 443<br>  },<br>  "rule3" = {<br>    protocol = "TCP"<br>    description = "rule-3"<br>    predefined_target = "self_security_group"<br>    from_port         = 0<br>    to_port           = 65535<br>  }<br>}</pre> | `any` | `{}` | no |
| <a name="input_enable_default_rules"></a> [enable\_default\_rules](#input\_enable\_default\_rules) | Controls creation of default security rules.<br><br>Default security rules:<br> - allows all outgoing traffic. Nodes can connect to Yandex Container Registry, Yandex Object Storage, Docker Hub, and so on<br> - allow access to ALB via port 80<br> - allow access to ALB via port 443<br> - allows availability checks from load balancer's address range | `bool` | `true` | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | ID of the folder to which the resource belongs. If omitted, the provider folder is used | `string` | `null` | no |
| <a name="input_http_router_id"></a> [http\_router\_id](#input\_http\_router\_id) | If flag create\_alb is False, you need to specify ID of existing ALB HTTP router. | `string` | `null` | no |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | ID of the network that the Load Balancer is located at | `string` | n/a | yes |
| <a name="input_public_dns_zone_id"></a> [public\_dns\_zone\_id](#input\_public\_dns\_zone\_id) | Public DNS zone ID for ALB CM certificates.<br>    As a default value is specified a PLACEHOLDER, changed it to a valid DNS zone ID. | `string` | `"<PUBLIC_DNS_ZONE_ID>"` | no |
| <a name="input_public_dns_zone_name"></a> [public\_dns\_zone\_name](#input\_public\_dns\_zone\_name) | Public DNS zone name<br>    As a default value is specified a PLACEHOLDER, changed it to a valid DNS zone name. | `string` | `"<PUBLIC_DNS_ZONE_NAME>"` | no |
| <a name="input_security_groups_ids_list"></a> [security\_groups\_ids\_list](#input\_security\_groups\_ids\_list) | List of security group IDs to which the ALB belongs | `list(string)` | `[]` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Target group timeouts | `map(string)` | <pre>{<br>  "create": "15m",<br>  "delete": "15m",<br>  "update": "15m"<br>}</pre> | no |
| <a name="input_tls_cert_path"></a> [tls\_cert\_path](#input\_tls\_cert\_path) | Relative path to self signed ALB TLS certificate according module.path. | `string` | `"content/tls"` | no |
| <a name="input_traffic_disabled"></a> [traffic\_disabled](#input\_traffic\_disabled) | If set, will disable all L7 instances in the zone for request handling. | `bool` | `false` | no |
| <a name="input_using_self_signed"></a> [using\_self\_signed](#input\_using\_self\_signed) | This flag indicates that self signed certificate is using. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_backend_group_ids"></a> [alb\_backend\_group\_ids](#output\_alb\_backend\_group\_ids) | ALB backend group IDs |
| <a name="output_alb_backend_group_names"></a> [alb\_backend\_group\_names](#output\_alb\_backend\_group\_names) | ALB backend group names |
| <a name="output_alb_dns_record_cname"></a> [alb\_dns\_record\_cname](#output\_alb\_dns\_record\_cname) | ALB DNS record with external IP address |
| <a name="output_alb_http_router_ids"></a> [alb\_http\_router\_ids](#output\_alb\_http\_router\_ids) | ALB HTTP router IDs |
| <a name="output_alb_http_router_names"></a> [alb\_http\_router\_names](#output\_alb\_http\_router\_names) | ALB HTTP routers names |
| <a name="output_alb_load_balancer_id"></a> [alb\_load\_balancer\_id](#output\_alb\_load\_balancer\_id) | ALB ID |
| <a name="output_alb_load_balancer_name"></a> [alb\_load\_balancer\_name](#output\_alb\_load\_balancer\_name) | ALB name |
| <a name="output_alb_load_balancer_public_ips"></a> [alb\_load\_balancer\_public\_ips](#output\_alb\_load\_balancer\_public\_ips) | ALB public IPs |
| <a name="output_alb_target_group_ids"></a> [alb\_target\_group\_ids](#output\_alb\_target\_group\_ids) | ALB target group IDs |
| <a name="output_alb_target_group_names"></a> [alb\_target\_group\_names](#output\_alb\_target\_group\_names) | ALB target group names |
| <a name="output_alb_virtual_host_ids"></a> [alb\_virtual\_host\_ids](#output\_alb\_virtual\_host\_ids) | ALB virtual router IDs |
| <a name="output_alb_virtual_host_names"></a> [alb\_virtual\_host\_names](#output\_alb\_virtual\_host\_names) | ALB virtual hosts names |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
