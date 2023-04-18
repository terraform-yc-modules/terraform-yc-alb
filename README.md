
# Application Load Balancer (ALB) module for Yandex.Cloud

## Features

- Create Application Load Balancer and all it components
- Create managed or self signed CM certificates and DNS zones for ALB on demand
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

> Note: The `alb_load_balancer` variable describes parameters for all ALB component in the description section.

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

### Load balancer example

The example below creates a load balancer with two target groups, HTTP and GRPC backend groups, two HTTP routers, virtual hosts for each backend group, and ALB listeners with ALB locations:

```
module "alb" {
  source              = "../../"

  network_id          = "enpneopbt180nusgut3q"
  
  // ALB load balancer
  alb_load_balancer = {
    name = "load-balancer-test"
    
    alb_target_groups  = {
      "target-group-test" = {
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
      }
    }

    alb_backend_groups         = {
      "http-backend-group-test"   = {
        http_backends          = [
          {
            name               = "http-backend"
            port               = 8080
            weight             = 100
            target_groups_list = ["target-group-test"]
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

### ALB CM certificates

You can define ALB certificates with the `alb_certificates` variable. It supports two types of certificates: managed and self signed. A managed certificate is issued by Let's Encrypt, it requires `domains` list and managed options, such as `challenge_type` and `challenge_count`. Self signed certificates can be created on your own, e.g., using the OpenSSL tool. 

The ALB module uses the following variables:
1. `create_certificate`: Flag that enables or disables a block with a CM certificate.
2. `using_self_signed`: Set it to `true` if you are using a self-signed certificate.
3. `alb_certificates`: List of all certificates.
4. `public_dns_zone_id`: Public DNS zone ID for issuing certificates with Let's Encrypt.
5. `cert_waiting_timer`: Timer for waiting for a certificate issued by Let's Encrypt.

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

### How to configure Terraform for Yandex.Cloud

- Install [YC CLI](https://cloud.yandex.com/docs/cli/quickstart)
- Add environment variables for `terraform auth` in Yandex.Cloud:

```
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.0.0 or higher |
| <a name="requirement_time"></a> [time](#requirement\_time) | 0.9.1 |
| <a name="requirement_yandex"></a> [yandex](#requirement\_yandex) | 0.87.0 or higher |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | N/A |
| <a name="provider_time"></a> [time](#provider\_time) | 0.9.1 |
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) | 0.87.0 or higher |

## Modules

There are no modules available.

## Resources

| Name | Type |
|------|------|
| [random_string.unique_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | Resource |
| [time_sleep.wait_for_cert_will_be_issued](https://registry.terraform.io/providers/hashicorp/time/0.9.1/docs/resources/sleep) | Resource |
| [yandex_alb_backend_group.backend_group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_backend_group) | Resource |
| [yandex_alb_http_router.http_router](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_http_router) | Resource |
| [yandex_alb_load_balancer.alb_load_balancer](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_load_balancer) | Resource |
| [yandex_alb_target_group.target_group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_target_group) | Resource |
| [yandex_alb_virtual_host.virtual_router](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/alb_virtual_host) | Resource |
| [yandex_cm_certificate.alb_cm_certificate](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/cm_certificate) | Resource |
| [yandex_dns_recordset.alb_cm_certificate_dns_name](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/dns_recordset) | Resource |
| [yandex_vpc_security_group.alb_custom_rules_sg](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group) | Resource |
| [yandex_vpc_security_group.alb_main_sg](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group) | Resource |
| [yandex_vpc_security_group_rule.egress_rules](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group_rule) | Resource |
| [yandex_vpc_security_group_rule.ingress_rules](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_security_group_rule) | Resource |
| [yandex_client_config.client](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/data-sources/client_config) | Data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_backend_groups_labels"></a> [alb\_backend\_groups\_labels](#input\_alb\_backend\_groups\_labels) | Default backend group labels | `map(string)` | <pre>{<br>  "component": "alb-backend-group",<br>  "owner": "example"<br>}</pre> | No |
| <a name="input_alb_certificates"></a> [alb\_certificates](#input\_alb\_certificates) | List of maps for ALB certificates.<br><br>    Notes:<br>      - Use only one type, either `managed` or `self\_managed`.<br>      - Crating a resource includes getting challenges from the issue provider.<br>      - Self-managed certificates support only one type of `private\_key` or `private\_key\_lockbox\_secret`. <br>      - You can provide self managed certificates and private keys as both strings and file names.<br>      - All self-signed certificates must be located in `<path.module>/content/tls/<your_folder>`.<br>      - Self-managed private keys can be read from Lockbox; for this, you need to specify the Lockbox private key secret ID and secret key.<br><br>    Parameters:<br>      - `name`<br>      - `description`<br>      - `labels`<br>      - `domains`: List of domains for this certificate.<br>      - `managed`:<br>        - `challenge\_type` (required): Domain owner check method. Possible values:<br>          `DNS\_CNAME`: You will need to create a CNAME DNS record with the specified value. Recommended for fully automated certificate renewal.<br>          `DNS\_TXT`: You will need to create a TXT DNS record with the specified value.<br>          `HTTP`: You will need to place the specified value into the specified URL.<br>        - `challenge\_count` (optional): Expected number of challenges required to validate a certificate.<br>      - `self\_managed`:<br>        - `certificate\_string`(required): Certificate as a string with chain.<br>        - `private\_key\_string` (optional): Private key as a string of certificate.<br>        - `certificate\_filename` (required): Certificate file name with chain.<br>        - `private\_key\_filename` (optional): Certificate private key file name.<br>        - `private\_key\_lockbox\_secret` (optional): Lockbox secret specification for getting private key.<br>          - `private\_key\_lockbox\_secret\_id`<br>          - `private\_key\_lockbox\_secret\_key` | `any` | `{}` | No |
| <a name="input_alb_certificates_labels"></a> [alb\_certificates\_labels](#input\_alb\_certificates\_labels) | Default certificate labels | `map(string)` | <pre>{<br>  "component": "certificate-manager",<br>  "owner": "example"<br>}</pre> | No |
| <a name="input_alb_http_routers_labels"></a> [alb\_http\_routers\_labels](#input\_alb\_http\_routers\_labels) | Default ALB HTTP router labels | `map(string)` | <pre>{<br>  "component": "alb-http-router",<br>  "owner": "example"<br>}</pre> | No |
| <a name="input_alb_load_balancer"></a> [alb\_load\_balancer](#input\_alb\_load\_balancer) | ALB map that defines all required resources for target groups, backend groups, HTTP routers, virtual hosts, and the load balancer.<br><br>    Required components:<br>      1. Target groups<br>      2. Backend groups<br>      3. HTTP routers<br>      4. Virtual hosts<br>      5. Load balancer<br><br>    1. Target groups<br><br>      Specify a map of maps for each target group.<br><br>      Parameters:<br>        - `targets`: List of targets.<br>          - `ip\_address` (required): IP address of the target.<br>          - `subnet\_id` (required): ID of the subnet the targets are connected to. All targets in the target group must be connected to the same subnet within a single availability zone.<br><br>      Example:<pre>alb_target_groups  = {<br>          "target-group-1" = {<br>            targets = [<br>              {<br>                subnet_id  = "e9b5udt8asf9r9qn6nf6"<br>                ip_address = "10.128.0.1"<br>              },<br>              {<br>                subnet_id  = "e2lu07tr481h35012c8p"<br>                ip_address = "10.129.0.1"<br>              },<br>              {<br>                subnet_id  = "b0c7h1g3ffdcpee488at"<br>                ip_address = "10.130.0.1"<br>              }<br>            ]<br>          }<br>        }</pre>2. Backend groups<br><br>      Specify a map for maps for each Backend group.<br><br>      Parameters:<br>        - `name`: Name of the backend group.<br>        - `labels`: Labels to assign to this backend group.<br>        - `backend`<br>          - `http\_backend` (optional): HTTP backend specification that will be used by the ALB backend group.<br>          - `grpc\_backend` (optional): GRPC backend specification that will be used by the ALB backend group.<br>          - `stream\_backend` (optional): Stream backend specification that will be used by the ALB backend group.<br><br>        Backend parameters:<br>          - `name` (required): Name of the backend.<br>          - `port` (optional): Port for incoming traffic.<br>          - `weight` (optional): Weight of the backend. Traffic will be split across backends of the same backend group according to their weights.<br>          - `http2` (optional): Enables HTTP2 for upstream requests. If not specified, HTTP 1.1 will be used by default.<br>          - `target\_group\_ids` (required): References target groups for the backend.<br>          - `load\_balancing\_config` (optional): Load Balancing Config specification that will be used by this backend.<br>            - `panic\_threshold` (optional): If the percentage of healthy hosts in the backend is lower than `panic\_threshold`, the traffic will be routed to all backends, no matter what the health status is. This helps to avoid overloading healthy backends in complex situations. When `panic\_threshold` is set to `0`, it means there is no panic threshold.<br>            - `locality\_aware\_routing\_percent` (optional): Percentage of traffic to send to the same availability zone. The rest will be equally distributed across other zones.<br>            - `strict\_locality` (optional): If provided, the requests will only be routed to the specified availability zone. The balancer will be unaware of the endpoints in other zones.<br>            - `mode` (optional): Load balancing mode for the backend. The possible values are `ROUND\_ROBIN`, `RANDOM`, `LEAST\_REQUEST`, and `MAGLEV\_HASH`.<br>          - `healthcheck` (optional): Healthcheck specification that will be used by this backend. <br>            - `timeout` (required): Time to wait for a health check response.<br>            - `interval` (required): Interval between health checks.<br>            - `interval\_jitter\_percent` (optional): Optional jitter amount as an interval percentage. If specified, the `(interval\_ms * interval\_jitter\_percent / 100)` value will be added to the wait time for every interval.<br>            - `healthy\_threshold` (optional): Number of consecutive successful health checks required to switch an endpoint to the healthy status. `0` means one health check. During startup, only one successful health check is required to consider a host healthy.<br>            - `unhealthy\_threshold` (optional): Number of consecutive failed health checks required to switch the endpoint to the unhealthy status. `0` means one health check. For HTTP health checks, a single 503 immediately makes the endpoint unhealthy.<br>            - `healthcheck\_port` (optional): Optional alternative port for health checking.<br>            - `stream\_healthcheck` (optional): Stream health check specification that will be used by this health check. See below for the structure.<br>              - `send` (optional): Message sent to targets during TCP data transfer. If not specified, no data is sent to the target.<br>              - `receive` (optional): Data that must be contained in the messages received from targets for a successful health check. If not specified, no messages are expected from targets, and those that are received are not checked.<br>            - `http\_healthcheck` (optional): HTTP health check specification that will be used by this health check. See below for the structure.<br>              - `host` (optional): **Host** HTTP header value.<br>              - path (required): HTTP path.<br>              - `http2` (optional): If specified, health checks will use HTTP2.<br>            - `grpc\_healthcheck` (optional): GRPC health check specification that will be used by this health check. See below for the structure.<br>              - `service\_name` (optional): Service name for the `grpc.health.v1.HealthCheckRequest` message.<br>          - `tls` (optional): TLS specification that will be used by this backend.<br>            - `sni` (optional): SNI string for TLS connections.<br>            - `validation\_context.0.trusted\_ca\_id` (optional): Trusted CA certificate ID in Certificate Manager.<br>            - `validation\_context.0.trusted\_ca\_bytes` (optional): PEM-encoded trusted CA certificate chain.<br> <br>        Notes:<br>          1. Specify only one backend type: `http\_backend`, `grpc\_backend`, or `stream\_backend`.<br>          2. Specify either `validation\_context.0.trusted\_ca\_id` or `validation\_context.0.trusted\_ca\_bytes`, not both.<br>          3. Specify only one health check type: `stream\_healthcheck`, `http\_healthcheck`, or `grpc\_healthcheck`.<br><br>      Example:<pre>alb_backend_groups  = {<br>          "http-backend-group-1" = {<br>            http_backend  = {<br>              name   = "http-backend-1"<br>              port   = 8080<br>              healthcheck = {<br>                healthcheck_port = 8081<br>                http_healthcheck = {<br>                  path = "/"<br>                }<br>              }<br>              http2 = "true"<br>            }   <br>          }<br>        }</pre>3. HTTP routers<br><br>      Specify a list of HTTP router names.<br><br>      Example:<pre>alb_http_routers  = ["http-router-1", "http-router-2"]</pre>4. Virtual hosts<br><br>      Specify a map of maps for ALB virtual hosts.<br>      ALB virtual host support only two types of routes: HTTP and GRPC. Stream is not supported.<br><br>      Parameters:<br>        - `name`: Name of a specific ALB virtual router.<br>        - `http\_router\_id` (required): ID of the HTTP router the virtual host belongs to.<br>        - `authority` (optional): List of domains (host/authority header) that will be matched to this virtual host.<br>          Wildcard hosts are supported in the `.foo.com` or `-bar.foo.com` form. <br>          If not specified, all domains will be matched.<br>        - `modify\_request\_headers OR modify\_response\_headers`: Apply the following modifications to the request or response headers:<br>            - `name` (required): Name of the header to modify.<br>            - `append` (optional): Append string to the header value.<br>            - `replace` (optional): New value for a header. Header values support the following formatters:<br>            - `remove` (optional): If set, remove the header.<br>        - `route` (optional): Route resource. Routes are matched in-order. <br>          Use caution when adding them to the end. For instance, having http `/` match first makes all other routes unused. <br>            - `name`: (required): Name of the route.<br>            - `http\_route` (optional): HTTP route resource.<br>              - `http\_match` (optional): Checks the `/` prefix by default.<br>                - `http\_method` (optional): List of methods (strings).<br>                - `path` (optional): If not specified, `/` is assumed.<br>                  - `exact` (optional): Match exactly.<br>                  - `prefix` (optional): Match prefix.<br>                  - `regex` (optional): Match regex.<br>              - `http\_route\_action` (optional): HTTP route action resource.<br>                - `backend\_group\_id ` (required): Backend group to route requests to.<br>                - `timeout` (optional): Specifies the request timeout for the route (overall time request processing is allowed). If not specified, the default value of 60 seconds is used.<br>                - `idle\_timeout` (optional): Specifies the idle timeout (time without any data transfer for the active request) for the route. This may be useful for streaming scenarios, such as long-polling or server-sent events, when you should set `idle\_timeout` to a meaningful value and `timeout`, to the maximum time the stream is allowed to be alive. If you skip this parameter, there will be no per-route idle timeout.<br>                - `host\_rewrite` (optional): Host rewrite specifier.<br>                - `auto\_host\_rewrite` (optional): If specified, the host will be automatically rewritten.<br>                - `prefix\_rewrite` (optional): If not empty, the matched path prefix will be replaced by this value.<br>                - `upgrade\_types` (optional): List of upgrade types. Only specified upgrade types, e.g., `websocket`, will be allowed.<br>              - `redirect\_action` (optional): Redirects action resource.<br>                - `replace\_scheme` (optional): Replaces scheme. If the original scheme is HTTP or HTTPS, it will also remove port 80 or 443, if applicable.<br>                - replace\_host (optional): Replaces host name.<br>                - `replace\_port` (optional): Replaces port.<br>                - `replace\_path` (optional): Replaces path.<br>                - `replace\_prefix` (optional) Replaces only matched prefix. <br>                  Example: match:{ prefx\_match: "/some" }<br>                          redirect: { replace\_prefix: "/other" }<br>                          This will redirect "/something" to "/otherthing".<br>                - `remove query` (optional): If specified, it removes the query part.<br>                - `response\_code` (optional): HTTP status code to use in the redirect response. The supported values are `moved\_permanently`, `found`, `see\_other`, `temporary\_redirect`, and `permanent\_redirect`.<br>              - `direct\_response\_action` (required): Direct response action resource.<br>                - `status` (optional): HTTP response status. The value must be between 100 and 599.<br>                - `body` (optional): Response body text.<br>            - `grpc\_route` (optional): GRPC route resource.<br>              - `grpc\_match` (optional): Checks the `/` prefix by default.<br>                - `fqmn` (optional): If not specified, all services and methods are assumed.<br>                  - `exact` (optional): Match exactly.<br>                  - `prefix` (optional): Match prefix.<br>                  - `regex` (optional): Match regex.<br>              - `grpc\_route\_action` (optional): GRPC route action resource.<br>                - `backend\_group\_id` (required): Backend group to route requests.<br>                - `max\_timeout` (optional): Client may specify lower timeout using the `grpc-timeout` header. If not specified, the default value of 60 seconds is used.<br>                - `idle\_timeout` (optional): Specifies the idle timeout (time without any data transfer for the active request) for the route. This may be useful for streaming scenarios, when you should set `idle\_timeout` to a meaningful value and `max\_timeout`, to the maximum time the stream is allowed to be alive. If you skip this parameter, there will be no per-route idle timeout.<br>                - `host\_rewrite` (optional): Host rewrite specifier.<br>                - `auto\_host\_rewrite` (optional): If specified, it will automatically rewrite host.<br>              - `grpc\_status\_response\_action` (required): GRPC status response action resource.<br>                - `status` (optional): Response status. The supported values are `ok`, `invalid\_argument`, `not\_found`, `permission\_denied`, `unauthenticated`, `unimplemented`, `internal`, and `unavailable`.<br>  <br>      Notes:<br>        - Specify only one listener type: `http`, `tls`, or `stream`.<br>        - Specify only one address type: `external\_ipv4\_address`, `internal\_ipv4\_address`, or `external\_ipv6\_address`.<br>        - Specify only one type of HTTP protocol settings: either `http2\_options` or `allow\_http10`.<br>        - For `modify\_request\_headers` or `modify\_response\_headers`, specify only one action type: `append`, `replace`, or `remove`.<br>        - Specify only one action type: `http\_route\_action` or `redirect\_action or direct\_response\_action`.<br>        - Specify only one type of host rewrite specifiers: either `host\_rewrite` or `auto\_host\_rewrite`.<br>        - Specify only one path type: either `replace\_path` or `replace\_prefix`.<br>        - Specify only one action type: `grpc\_route\_action` or `grpc\_status\_response\_action`.<br>        - Specify only one type of string matches: `exact`, `prefix`, or `regex`.<br><br>      Example:<pre>alb_virtual_hosts = {<br>          "virtual-router-1" = {<br>            http_router_name = "http-router-1"<br>            route = {<br>              name = "http-virtual-route"<br>              http_route = {<br>                http_route_action = {<br>                  backend_group_name = "http-backend-group-1"<br>                }<br>              }<br>            }<br>          }<br>        }</pre>5. Load balancer<br><br>      Default parameters:<br>        - `description` (optional): Load balancer description.<br>        - `labels` (optional): Set of key/value label pairs to assign load balancer.<br>        - `region\_id` (optional): ID of the region where the load balancer is located.<br>        - `network\_id` (required): ID of the network where the Load Balancer is located.<br>        - `security\_groups\_ids` (optional): List of IDs of the security groups attached to the load balancer.<br><br>      All supported parameters:<br>        - `alb\_allocations` (required): Allocation zones for the load balancer instance.<br>          - `zone\_id` (required): ID of the zone location.<br>          - `subnet\_id` (required): ID of the subnet.<br>          - `disable\_traffic ` (optional): If specified, it will disable all L7 instances in the zone for request handling.<br>        - `listener` (optional): List of listeners for the load balancer.<br>          - `name` (required): Name of the backend.<br>          - `endpoint` (required): Network endpoints (addresses and ports) of the listener.<br>            - `address` (required): One or more addresses to listen on.<br>              - `external\_ipv4\_address` (optional): External IPv4 address.<br>                - `address` (optional): Provided by the client or computed automatically.<br>              - `internal\_ipv4\_address` (optional): Internal IPv4 address.<br>                - `address` (optional): Provided by the client or computed automatically.<br>                - `subnet\_id` (optional): Provided by the client or computed automatically.<br>              - `external\_ipv6\_address` (optional): External IPv6 address.<br>                - `address` (optional): Provided by the client or computed automatically.<br>            - `ports` (required): One or more ports to listen on.<br>          - `http` (optional): HTTP listener resource. Note: You should only specify one type of the `handler` or `redirects` field.<br>            - `handler` (optional): HTTP handler that sets plaintext HTTP router. See below for the structure.<br>              - `http\_router\_id` (optional): HTTP router ID.<br>              - `rewrite\_request\_id` (optional): If not specified, it will preserve the incoming `x-request-id` header; otherwise, it will rewrite it with a new value.<br>              - `http2\_options` (optional): If specified, it will enable HTTP2 protocol for the handler.<br>                - `max\_concurrent\_streams` (optional): Maximum number of concurrent streams.<br>              - `allow\_http10` (optional): If specified, it will only enable HTTP1 protocol with HTTP1.0 support.<br>            - `redirects` (optional): Shortcut for adding redirects from HTTP to HTTPS.<br>              - `http\_to\_https` (optional): If specified, it redirects all unencrypted HTTP requests to the same URI with a scheme changed to HTTPS.<br>          - `stream` (optional): Stream listener resource.<br>            - `handler` (optional): Stream handler that sets plaintext Stream backend group. <br>              - `backend\_group\_id` (optional): Backend group ID.<br>          - `tls` (optional): TLS listener resource.<br>            - `default\_handler` (required): TLS handler resource.<br>              - `http\_handler` (required): HTTP handler resource.<br>                - `http\_router\_id` (optional): HTTP router ID.<br>                - `rewrite\_request\_id` (optional): If not specified, it will preserve the incoming `x-request-id` header; otherwise, it will rewrite it with a new value.<br>                - `http2\_options` (optional): If specified, it will enable HTTP2 protocol for the handler.<br>                  - `max\_concurrent\_streams` (optional): Maximum number of concurrent streams.<br>                - `allow\_http10` (optional): If specified, it will only enable HTTP1 protocol with HTTP1.0 support.<br>              - `stream\_handler` (required): Stream handler resource.<br>                - `backend\_group\_id` (optional): Backend group ID.<br>              - `certificate\_ids` (required): Certificate IDs in Certificate Manager. Multiple TLS certificates can be associated with the same context to allow both RSA and ECDSA certificates. Only the first certificate of each type will be used.<br>            - `sni\_handler` (optional): SNI match resource.<br>              - `name` (required): Name of SNI match.<br>              - `server\_names` (required): Set of server names.<br>              - `handler` (required): TLS handler resource.<br>                - `http\_handler` (required): HTTP handler resource. See below for the structure.<br>                - `stream\_handler` (required): Stream handler resource. See below for the structure.<br>                - `certificate\_ids` (required): Certificate IDs in Certificate Manager. Multiple TLS certificates can be associated with the same context to allow both RSA and ECDSA certificates. Only the first certificate of each type will be used.<br>        - `log\_options` (optional): Cloud logging settings.<br>          - `disable` (optional): Set to true to disable cloud logging for the balancer.<br>          - `log\_group\_id` (optional): Cloud logging group ID to send logs to. Leave blank to use the default log group of the balancer folder.<br>          - `discard\_rule` (optional): List of rules to discard a fraction of logs.<br>            - `http\_codes` (optional): List of HTTP codes from 100 to 599.<br>            - `http\_code\_intervals` (optional): List of HTTP code intervals from 1XX to 5XX, or `ALL`.<br>            - grpc\_codes (optional): List of GRPC codes by name, e.g, `["NOT\_FOUND", "RESOURCE\_EXHAUSTED"]`.<br><br>      Notes:<br>        1. Use only one listener type: `http`, `tls`, or `stream`.<br>        2. `sni\_handler` is a list of SNI handlers.<br>        3. If you set `create\_certificate` to `true`, the certificate should be provided as a name of newly created certificate or a list of previously created CM certificate IDs.<br><br>      Example:<pre>alb_locations = [<br>          {<br>            zone_id = "ru-central1-a"<br>            subnet_id = "e9b5udt8asf9r9qn6nf6"<br>          },<br>          {<br>            zone_id = "ru-central1-b"<br>            subnet_id = "e2lu07tr481h35012c8p"<br>          },<br>          {<br>            zone_id = "ru-central1-c"<br>            subnet_id = "b0c7h1g3ffdcpee488at"<br>          }<br>        ]<br><br>        alb_listeners = [<br>          {<br>            name = "alb-listener-1"<br>            endpoint = {<br>              address = {<br>                external_ipv4_address = {}<br>              }<br>              ports = ["8080", "443"]<br>            }<br>            http = {<br>              handler = {}<br>            }<br>          }<br>        ]<br><br>        log_options = {<br>          disable = true<br>        }</pre> | `any` | `{}` | No |
| <a name="input_alb_load_balancer_labels"></a> [alb\_load\_balancer\_labels](#input\_alb\_load\_balancer\_labels) | Default load balancer labels | `map(string)` | <pre>{<br>  "component": "alb-load-balancer",<br>  "owner": "example"<br>}</pre> | No |
| <a name="input_alb_target_group_labels"></a> [alb\_target\_group\_labels](#input\_alb\_target\_group\_labels) | Default target group labels | `map(string)` | <pre>{<br>  "component": "alb-target-group",<br>  "owner": "example"<br>}</pre> | No |
| <a name="input_allowed_ips"></a> [allowed\_ips](#input\_allowed\_ips) | List of allowed IPv4 CIDR blocks | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | No |
| <a name="input_cert_waiting_timer"></a> [cert\_waiting\_timer](#input\_cert\_waiting\_timer) | Timer value for waiting until ALB TLS certificate will be issued. | `string` | `"300s"` | No |
| <a name="input_create_certificate"></a> [create\_certificate](#input\_create\_certificate) | Flag for enabling or disabling creation of a CM certificate and a DNS name for it. | `bool` | `false` | No |
| <a name="input_custom_egress_rules"></a> [custom\_egress\_rules](#input\_custom\_egress\_rules) | Map definition of custom security egress rules.<br><br>Example:<pre>custom_egress_rules = {<br>  "rule1" = {<br>    protocol       = "ANY"<br>    description    = "rule-1"<br>    v4_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]<br>    from_port      = 8090<br>    to_port        = 8099<br>  },<br>  "rule2" = {<br>    protocol       = "UDP"<br>    description    = "rule-2"<br>    v4_cidr_blocks = ["10.0.1.0/24"]<br>    from_port      = 8090<br>    to_port        = 8099<br>  }<br>}</pre> | `any` | `{}` | No |
| <a name="input_custom_ingress_rules"></a> [custom\_ingress\_rules](#input\_custom\_ingress\_rules) | Map definition of custom security ingress rules.<br><br>Example:<pre>custom_ingress_rules = {<br>  "rule1" = {<br>    protocol = "TCP"<br>    description = "rule-1"<br>    v4_cidr_blocks = ["0.0.0.0/0"]<br>    from_port = 3000<br>    to_port = 32767<br>  },<br>  "rule2" = {<br>    protocol = "TCP"<br>    description = "rule-2"<br>    v4_cidr_blocks = ["0.0.0.0/0"]<br>    port = 443<br>  },<br>  "rule3" = {<br>    protocol = "TCP"<br>    description = "rule-3"<br>    predefined_target = "self_security_group"<br>    from_port         = 0<br>    to_port           = 65535<br>  }<br>}</pre> | `any` | `{}` | No |
| <a name="input_dns_zone_labels"></a> [dns\_zone\_labels](#input\_dns\_zone\_labels) | Default certificate labels | `map(string)` | <pre>{<br>  "component": "cloud-dns",<br>  "owner": "example"<br>}</pre> | No |
| <a name="input_enable_default_rules"></a> [enable\_default\_rules](#input\_enable\_default\_rules) | Manages creation of default security rules.<br><br>Default security rules:<br> - Allow all incoming traffic from any protocol.<br> - Allow all outgoing traffic. Nodes can connect to Yandex Container Registry, Yandex Object Storage, Docker Hub, etc.<br> - Allow access to Kubernetes API through port 6443 from the subnet.<br> - Allow access to Kubernetes API through port 443 from the subnet.<br> - Allow access to worker nodes through SSH from the allowed IPs range. | `bool` | `true` | No |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | ID of the folder the resource belongs to. If skipped, the provider folder is used. | `string` | `null` | No |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | ID of the network the load balancer is located at. | `string` | N/A | Yes |
| <a name="input_public_dns_zone_id"></a> [public\_dns\_zone\_id](#input\_public\_dns\_zone\_id) | Public DNS zone ID for ALB CM certificates.<br>    The default value is `PLACEHOLDER`, and you can change it to a valid DNS zone ID. | `string` | `"PUBLIC_DNS_ZONE_ID"` | No |
| <a name="input_security_groups_ids_list"></a> [security\_groups\_ids\_list](#input\_security\_groups\_ids\_list) | List of security group IDs the ALB belongs to. | `list(string)` | `[]` | No |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Target group timeouts | `map(string)` | <pre>{<br>  "create": "15m",<br>  "delete": "15m",<br>  "update": "15m"<br>}</pre> | No |
| <a name="input_traffic_disabled"></a> [traffic\_disabled](#input\_traffic\_disabled) | If specified, it will disable all L7 instances in the zone for request handling. | `bool` | `false` | No |
| <a name="input_using_self_signed"></a> [using\_self\_signed](#input\_using\_self\_signed) | Flag indicating that a self signed certificate is being used. | `bool` | `false` | No |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_backend_group_ids"></a> [alb\_backend\_group\_ids](#output\_alb\_backend\_group\_ids) | ALB backend group IDs |
| <a name="output_alb_backend_group_names"></a> [alb\_backend\_group\_names](#output\_alb\_backend\_group\_names) | ALB backend group names |
| <a name="output_alb_http_router_ids"></a> [alb\_http\_router\_ids](#output\_alb\_http\_router\_ids) | ALB HTTP router IDs |
| <a name="output_alb_http_router_names"></a> [alb\_http\_router\_names](#output\_alb\_http\_router\_names) | ALB HTTP routers names |
| <a name="output_alb_load_balancer_id"></a> [alb\_load\_balancer\_id](#output\_alb\_load\_balancer\_id) | ALB load balancer ID |
| <a name="output_alb_load_balancer_name"></a> [alb\_load\_balancer\_name](#output\_alb\_load\_balancer\_name) | ALB load balancer name |
| <a name="output_alb_load_balancer_private_ips"></a> [alb\_load\_balancer\_private\_ips](#output\_alb\_load\_balancer\_private\_ips) | ALB load balancer private IPs |
| <a name="output_alb_load_balancer_public_ips"></a> [alb\_load\_balancer\_public\_ips](#output\_alb\_load\_balancer\_public\_ips) | ALB load balancer public IPs |
| <a name="output_alb_target_group_ids"></a> [alb\_target\_group\_ids](#output\_alb\_target\_group\_ids) | ALB target group IDs |
| <a name="output_alb_target_group_names"></a> [alb\_target\_group\_names](#output\_alb\_target\_group\_names) | ALB target group names |
| <a name="output_alb_virtual_host_ids"></a> [alb\_virtual\_host\_ids](#output\_alb\_virtual\_host\_ids) | ALB virtual router IDs |
| <a name="output_alb_virtual_host_names"></a> [alb\_virtual\_host\_names](#output\_alb\_virtual\_host\_names) | ALB virtual hosts names |
| <a name="output_dns_records_names"></a> [dns\_records\_names](#output\_dns\_records\_names) | DNS records names |
<!-- END_TF_DOCS -->

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
