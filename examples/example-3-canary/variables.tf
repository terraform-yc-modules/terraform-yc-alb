variable "folder_id" {
  description = "The ID of the folder to which the resource belongs. If omitted, the provider folder is used."
  type        = string
  default     = null
}

variable "network_id" {
  description = "ID of the network that the Load Balancer is located at."
  type        = string
}

#
# ALB Load Balancer
#
variable "alb_load_balancer" {
  description = <<EOF
    ALB load balancer map that defines all required resources for target groups, backend groups, HTTP routers, virtual hosts and alb load balancer.

    Required components:
      1. Target groups
      2. Backend groups
      3. HTTP routers
      4. Virtual hosts
      5. Load balancer

    1. Target groups

      A map of maps for each target group

      Parameters:
        - targets - a list of targets
          - ip_address - (Required) IP address of the target.
          - subnet_id - (Required) ID of the subnet that targets are connected to. All targets in the target group must be connected to the same subnet within a single availability zone.

      Example:
      ```
        alb_target_groups  = {
          "target-group-1" = {
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
      ```

    2. Backend groups

      A map for maps for each Backend group

      Parameters:
        - name        - Name of the Backend Group.
        - labels      - Labels to assign to this backend group.
        - backend
          - http_backend - (Optional) Http backend specification that will be used by the ALB Backend Group.
          - grpc_backend - (Optional) Grpc backend specification that will be used by the ALB Backend Group.
          - stream_backend - (Optional) Stream backend specification that will be used by the ALB Backend Group.

        Backend parameters:
          - name - (Required) Name of the backend.
          - port - (Optional) Port for incoming traffic.
          - weight - (Optional) Weight of the backend. Traffic will be split between backends of the same BackendGroup according to their weights.
          - http2 - (Optional) Enables HTTP2 for upstream requests. If not set, HTTP 1.1 will be used by default.
          - target_group_ids - (Required) References target groups for the backend.
          - load_balancing_config - (Optional) Load Balancing Config specification that will be used by this backend.
            - panic_threshold - (Optional) If percentage of healthy hosts in the backend is lower than panic_threshold, traffic will be routed to all backends no matter what the health status is. This helps to avoid healthy backends overloading when everything is bad. Zero means no panic threshold.
            - locality_aware_routing_percent - (Optional) Percent of traffic to be sent to the same availability zone. The rest will be equally divided between other zones.
            - strict_locality - (Optional) If set, will route requests only to the same availability zone. Balancer won't know about endpoints in other zones.
            - mode - (Optional) Load balancing mode for the backend. Possible values: "ROUND_ROBIN", "RANDOM", "LEAST_REQUEST", "MAGLEV_HASH".
          - healthcheck - (Optional) Healthcheck specification that will be used by this backend. 
            - timeout - (Required) Time to wait for a health check response.
            - interval - (Required) Interval between health checks.
            - interval_jitter_percent - (Optional) An optional jitter amount as a percentage of interval. If specified, during every interval value of (interval_ms * interval_jitter_percent / 100) will be added to the wait time.
            - healthy_threshold - (Optional) Number of consecutive successful health checks required to promote endpoint into the healthy state. 0 means 1. Note that during startup, only a single successful health check is required to mark a host healthy.
            - unhealthy_threshold - (Optional) Number of consecutive failed health checks required to demote endpoint into the unhealthy state. 0 means 1. Note that for HTTP health checks, a single 503 immediately makes endpoint unhealthy.
            - healthcheck_port - (Optional) Optional alternative port for health checking.
            - stream_healthcheck - (Optional) Stream Healthcheck specification that will be used by this healthcheck. Structure is documented below.
              - send - (Optional) Message sent to targets during TCP data transfer. If not specified, no data is sent to the target.
              - receive - (Optional) Data that must be contained in the messages received from targets for a successful health check. If not specified, no messages are expected from targets, and those that are received are not checked.
            - http_healthcheck - (Optional) Http Healthcheck specification that will be used by this healthcheck. Structure is documented below.
              - host - (Optional) "Host" HTTP header value.
              - path - (Required) HTTP path.
              - http2 - (Optional) If set, health checks will use HTTP2.
            - grpc_healthcheck - (Optional) Grpc Healthcheck specification that will be used by this healthcheck. Structure is documented below.
              - service_name - (Optional) Service name for grpc.health.v1.HealthCheckRequest message.
          - tls - (Optional) Tls specification that will be used by this backend.
            - sni - (Optional) SNI string for TLS connections.
            - validation_context.0.trusted_ca_id - (Optional) Trusted CA certificate ID in the Certificate Manager.
            - validation_context.0.trusted_ca_bytes - (Optional) PEM-encoded trusted CA certificate chain.
 
        Notes:
          1. Only one type of backends http_backend or grpc_backend or stream_backend should be specified.
          2. Only one of validation_context.0.trusted_ca_id or validation_context.0.trusted_ca_bytes should be specified.
          3. Only one of stream_healthcheck or http_healthcheck or grpc_healthcheck should be specified.

      Example:
      ```
        alb_backend_groups  = {
          "http-backend-group-1" = {
            http_backend  = {
              name   = "http-backend-1"
              port   = 8080
              healthcheck = {
                healthcheck_port = 8081
                http_healthcheck = {
                  path = "/"
                }
              }
              http2 = "true"
            }   
          }
        }
      ```

    3. HTTP routers

      A list of HTTP routers names

      Example:
      ```
      alb_http_routers  = ["http-router-1", "http-router-2"]
      ```

    4. Virtual hosts

      ALB virtual hosts map of maps.
      ALB virtual host support only two types of routes - HTTP and GRPC. Stream is not supported!

      Parameters:
        - name - Name of a specific ALB virtual router.
        - http_router_id - (Required) The ID of the HTTP router to which the virtual host belongs.
        - authority - (Optional) A list of domains (host/authority header) that will be matched to this virtual host.
          Wildcard hosts are supported in the form of '.foo.com' or '-bar.foo.com'. 
          If not specified, all domains will be matched.
        - modify_request_headers OR modify_response_headers - Apply the following modifications to the request or response headers.
            - name - (Required) name of the header to modify.
            - append - (Optional) Append string to the header value.
            - replace - (Optional) New value for a header. Header values support the following formatters.
            - remove - (Optional) If set, remove the header.
        - route - (Optional) A Route resource. Routes are matched in-order. 
          Be careful when adding them to the end. For instance, having http '/' match first makes all other routes unused. 
            - name - (Required) name of the route.
            - http_route - (Optional) HTTP route resource.
              - http_match - (Optional) Checks "/" prefix by default.
                - http_method - (Optional) List of methods(strings).
                - path - (Optional) If not set, '/' is assumed.
                  - exact - (Optional) Match exactly.
                  - prefix - (Optional) Match prefix.
                  - regex - (Optional) Match regex.
              - http_route_action - (Optional) HTTP route action resource.
                - backend_group_id - (Required) Backend group to route requests.
                - timeout - (Optional) Specifies the request timeout (overall time request processing is allowed to take) for the route. If not set, default is 60 seconds.
                - idle_timeout - (Optional) Specifies the idle timeout (time without any data transfer for the active request) for the route. It is useful for streaming scenarios (i.e. long-polling, server-sent events) - one should set idle_timeout to something meaningful and timeout to the maximum time the stream is allowed to be alive. If not specified, there is no per-route idle timeout.
                - host_rewrite - (Optional) Host rewrite specifier.
                - auto_host_rewrite - (Optional) If set, will automatically rewrite host.
                - prefix_rewrite - (Optional) If not empty, matched path prefix will be replaced by this value.
                - upgrade_types - (Optional) List of upgrade types. Only specified upgrade types will be allowed. For example, "websocket".
              - redirect_action - (Optional) Redirect action resource.
                - replace_scheme - (Optional) Replaces scheme. If the original scheme is http or https, will also remove the 80 or 443 port, if present.
                - replace_host - (Optional) Replaces hostname.
                - replace_port - (Optional) Replaces port.
                - replace_path - (Optional) Replace path.
                - replace_prefix - (Optional) Replace only matched prefix. 
                  Example: match:{ prefx_match: "/some" }
                          redirect: { replace_prefix: "/other" }
                          will redirect "/something" to "/otherthing".
                - remove query - (Optional) If set, remove query part.
                - response_code - (Optional) The HTTP status code to use in the redirect response. Supported values are: moved_permanently, found, see_other, temporary_redirect, permanent_redirect.
              - direct_response_action - (Required) Direct response action resource.
                - status - (Optional) HTTP response status. Should be between 100 and 599.
                - body - (Optional) Response body text.
            - grpc_route - (Optional) GRPC route resource.
              - grpc_match - (Optional) Checks "/" prefix by default.
                - fqmn - (Optional) If not set, all services/methods are assumed.
                  - exact - (Optional) Match exactly.
                  - prefix - (Optional) Match prefix.
                  - regex - (Optional) Match regex.
              - grpc_route_action - (Optional) GRPC route action resource.
                - backend_group_id - (Required) Backend group to route requests.
                - max_timeout - (Optional) Lower timeout may be specified by the client (using grpc-timeout header). If not set, default is 60 seconds.
                - idle_timeout - (Optional) Specifies the idle timeout (time without any data transfer for the active request) for the route. It is useful for streaming scenarios - one should set idle_timeout to something meaningful and max_timeout to the maximum time the stream is allowed to be alive. If not specified, there is no per-route idle timeout.
                - host_rewrite - (Optional) Host rewrite specifier.
                - auto_host_rewrite - (Optional) If set, will automatically rewrite host.
              - grpc_status_response_action - (Required) GRPC status response action resource.
                - status - (Optional) The status of the response. Supported values are: ok, invalid_argumet, not_found, permission_denied, unauthenticated, unimplemented, internal, unavailable.
      
      Notes:
        - Exactly one listener type: http or tls or stream should be specified.
        - Exactly one type of addresses external_ipv4_address or internal_ipv4_address or external_ipv6_address should be specified.
        - Only one type of HTTP protocol settings http2_options or allow_http10 should be specified.
        - For modify_request_headers OR modify_response_headers only one type of actions 'append' or 'replace' or 'remove' should be specified.  
        - Exactly one type of actions http_route_action or redirect_action or direct_response_action should be specified.
        - Only one type of host rewrite specifiers host_rewrite or auto_host_rewrite should be specified.
        - Only one type of paths replace_path or replace_prefix should be specified.
        - Exactly one type of actions grpc_route_action or grpc_status_response_action should be specified.
        - Only one type of host rewrite specifiers host_rewrite or auto_host_rewrite should be specified.
        - Exactly one type of string matches exact, prefix or regex should be specified.

      Example:
      ```
        alb_virtual_hosts = {
          "virtual-router-1" = {
            http_router_name = "http-router-1"
            route = {
              name = "http-virtual-route"
              http_route = {
                http_route_action = {
                  backend_group_name = "http-backend-group-1"
                }
              }
            }
          }
        }
      ```

    5. ALB load balancer  

      Default parameters:
        - description - (Optional) A description of the ALB Load Balancer.
        - labels - (Optional) A set of key/value label pairs to assign ALB Load Balancer.
        - region_id - (Optional) ID of the region that the Load Balancer is located at.
        - network_id - (Required) ID of the network that the Load Balancer is located at.
        - security_groups_ids - (Optional) A list of ID's of security groups attached to the Load Balancer.
    
      All supported parameters:
        - alb_allocations - (Required) Allocation zones for the Load Balancer instance.
          - zone_id - (Required) ID of the zone that location is located at.
          - subnet_id - (Required) ID of the subnet that location is located at.
          - disable_traffic - (Optional) If set, will disable all L7 instances in the zone for request handling.
        - listener - (Optional) List of listeners for the Load Balancer.
          - name - (Required) Name of the backend.
          - endpoint  - (Required) Network endpoints (addresses and ports) of the listener.
            - address - (Required) One or more addresses to listen on.
              - external_ipv4_address - (Optional) External IPv4 address.
                - address - (Optional) Provided by the client or computed automatically.
              - internal_ipv4_address - (Optional) Internal IPv4 address.
                - address - (Optional) Provided by the client or computed automatically.
                - subnet_id - (Optional) Provided by the client or computed automatically
              - external_ipv6_address - (Optional) External IPv6 address.
                - address - (Optional) Provided by the client or computed automatically.
            - ports   - (Required) One or more ports to listen on.
          - http - (Optional) HTTP listener resource. Note: Only one type of fields handler or redirects should be specified.
            - handler - (Optional) HTTP handler that sets plaintext HTTP router. The structure is documented below.
              - http_router_id - (Optional) HTTP router id.
              - rewrite_request_id - (Optional) When unset, will preserve the incoming x-request-id header, otherwise would rewrite it with a new value.
              - http2_options - (Optional) If set, will enable HTTP2 protocol for the handler.
                - max_concurrent_streams - (Optional) Maximum number of concurrent streams.
              - allow_http10 - (Optional) If set, will enable only HTTP1 protocol with HTTP1.0 support.
            - redirects - (Optional) Shortcut for adding http -> https redirects.
              - http_to_https - (Optional) If set redirects all unencrypted HTTP requests to the same URI with scheme changed to https.
          - stream - (Optional) Stream listener resource.
            - handler - (Optional) Stream handler that sets plaintext Stream backend group. 
              - backend_group_id - (Optional) Backend group id.
          - tls - (Optional) TLS listener resource.
            - default_handler - (Required) TLS handler resource.
              - http_handler - (Required) HTTP handler resource.
                - http_router_id - (Optional) HTTP router id.
                - rewrite_request_id - (Optional) When unset, will preserve the incoming x-request-id header, otherwise would rewrite it with a new value.
                - http2_options - (Optional) If set, will enable HTTP2 protocol for the handler.
                  - max_concurrent_streams - (Optional) Maximum number of concurrent streams.
                - allow_http10 - (Optional) If set, will enable only HTTP1 protocol with HTTP1.0 support.
              - stream_handler - (Required) Stream handler resource.
                - backend_group_id - (Optional) Backend group id.
              - certificate_ids - (Required) Certificate IDs in the Certificate Manager. Multiple TLS certificates can be associated with the same context to allow both RSA and ECDSA certificates. Only the first certificate of each type will be used.
            - sni_handler - (Optional) SNI match resource.
              - name - (Required) name of SNI match.
              - server_names - (Required) A set of server names.
              - handler - (Required) TLS handler resource.
                - http_handler - (Required) HTTP handler resource. The structure is documented below.
                - stream_handler - (Required) Stream handler resource. The structure is documented below.
                - certificate_ids - (Required) Certificate IDs in the Certificate Manager. Multiple TLS certificates can be associated with the same context to allow both RSA and ECDSA certificates. Only the first certificate of each type will be used.
        - log_options - (Optional) Cloud Logging settings.
          - disable (Optional) Set to true to disable Cloud Logging for the balancer
          - log_group_id (Optional) Cloud Logging group ID to send logs to. Leave empty to use the balancer folder default log group.
          - discard_rule (Optional) List of rules to discard a fraction of logs.
            - http_codes (Optional) list of http codes 100-599
            - http_code_intervals (Optional) list of http code intervals 1XX-5XX or ALL
            - grpc_codes (Optional) list of grpc codes by name, e.g, ["NOT_FOUND", "RESOURCE_EXHAUSTED"]

      Notes:
        1. Exactly one listener type: http or tls or stream should be specified.
        2. sni_handler is a list of SNI handlers.
        3. if create_certificate = true, certificate should be passed as a name of newly created certificate or as a list of previously created CM certificate ids.

      Example:
      ```
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
            name = "alb-listener-1"
            endpoint = {
              address = {
                external_ipv4_address = {}
              }
              ports = ["8080", "443"]
            }
            http = {
              handler = {}
            }
          }
        ]

        log_options = {
          disable = true
        }
      ```

  EOF
  type = any
  default = {}
}

variable "traffic_disabled" {
  description = "If set, will disable all L7 instances in the zone for request handling."
  type        = bool
  default     = false
}

variable "security_groups_ids_list" {
  description = "List of security group IDs to which the ALB belongs"
  type        = list(string)
  default     = []
  nullable    = true
}

# Certificate Manager
variable "create_certificate" {
  description = "Flag for enabling / disabling creation of a CM certificates and DNS name for it."
  type        = bool
  default     = false
}
variable "using_self_signed" {
  description = "This flag indicates that self signed certificate is using."
  type        = bool
  default     = false
}
variable "cert_waiting_timer" {
  description = "A timer value for waiting until ALB TLS certificate will be ISSUED."
  type        = string
  default     = "300s"
}
variable "public_dns_zone_id" {
  description = <<EOF
    Public DNS zone ID for ALB CM certificates.
    As a default value is specified a PLACEHOLDER, changed it to a valid DNS zone ID.
  EOF
  type        = string
  default     = "PUBLIC_DNS_ZONE_ID"
}
variable "alb_certificates" {
  description = <<EOF
    ALB certificates list of maps.

    Notes:
      - Only one type 'managed' or 'self_managed' should be used.
      - Resource creation awaits getting challenges from issue provider.
      - Self managed certificate supports only one type of private_key or private_key_lockbox_secret. 
      - Self managed certificates and private_keys could be passed as strings or filenames.
      - All self signed certificates should be located in `<path.module>/content/tls/ folder`.
      - Self managed private keys could be read from LockBox, Lockbox private key secret ID and secret key should be specified.

    Parameters:
      - name
      - description
      - labels
      - domains - a list of domains for this certificate.
      - managed:
        - challenge_type - (Required) Domain owner-check method. Possible values:
          "DNS_CNAME" - you will need to create a CNAME dns record with the specified value. Recommended for fully automated certificate renewal;
          "DNS_TXT" - you will need to create a TXT dns record with specified value;
          "HTTP" - you will need to place specified value into specified url.
        - challenge_count - (Optional). Expected number of challenge count needed to validate certificate.
      - self_managed:
        - certificate_string         - (Required) Certificate as a string with chain.
        - private_key_string         - (Optional) Private key as a string of certificate.
        - certificate_filename       - (Required) Certificate filename with chain.
        - private_key_filename       - (Optional) Private key filename of certificate.
        - private_key_lockbox_secret - (Optional) Lockbox secret specification for getting private key.
          - private_key_lockbox_secret_id
          - private_key_lockbox_secret_key
  EOF
  type = any
  default = {}
}

# Labels
variable "alb_load_balancer_labels" {
  description = "ALB Load Balancer default labels."
  type    = map(string)
  default = {
    owner = "example"
    component = "alb-load-balancer"
  }
}
variable "alb_target_group_labels" {
  description = "Target group default labels."
  type    = map(string)
  default = {
    owner = "example"
    component = "alb-target-group"
  }
}
variable "alb_backend_groups_labels" {
  description = "Backend group default labels."
  type    = map(string)
  default = {
    owner = "example"
    component = "alb-backend-group"
  }
}
variable "alb_http_routers_labels" {
  description = "ALB HTTP Routers default labels."
  type    = map(string)
  default = {
    owner = "example"
    component = "alb-http-router"
  }
}
variable "alb_certificates_labels" {
  description = "Certificates default labels."
  type    = map(string)
  default = {
    owner = "example"
    component = "certificate-manager"
  }
}
variable "dns_zone_labels" {
  description = "Certificates default labels."
  type    = map(string)
  default = {
    owner = "example"
    component = "cloud-dns"
  }
}

variable "timeouts" {
  description = "Target group timeouts."
  type    = map(string)
  default = {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}
#
# Security groups
#
variable "enable_default_rules" {
  description = <<-EOF
    Controls creation of default security rules.

    Default security rules:
     - allows all outgoing traffic. Nodes can connect to Yandex Container Registry, Yandex Object Storage, Docker Hub, and so on
     - allow access to ALB via port 80
     - allow access to ALB via port 443
     - allows availability checks from load balancer's address range
  EOF
  type = bool
  default = true
}

variable "custom_ingress_rules" {
  description = <<-EOF
    A map definition of custom security ingress rules.
    
    Example:
    ```
    custom_ingress_rules = {
      "rule1" = {
        protocol = "TCP"
        description = "rule-1"
        v4_cidr_blocks = ["0.0.0.0/0"]
        from_port = 3000
        to_port = 32767
      },
      "rule2" = {
        protocol = "TCP"
        description = "rule-2"
        v4_cidr_blocks = ["0.0.0.0/0"]
        port = 443
      },
      "rule3" = {
        protocol = "TCP"
        description = "rule-3"
        predefined_target = "self_security_group"
        from_port         = 0
        to_port           = 65535
      }
    }
    ```
  EOF
  type = any
  default = {}
}

variable "custom_egress_rules" {
  description = <<-EOF
    A map definition of custom security egress rules.
    
    Example:
    ```
    custom_egress_rules = {
      "rule1" = {
        protocol       = "ANY"
        description    = "rule-1"
        v4_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
        from_port      = 8090
        to_port        = 8099
      },
      "rule2" = {
        protocol       = "UDP"
        description    = "rule-2"
        v4_cidr_blocks = ["10.0.1.0/24"]
        from_port      = 8090
        to_port        = 8099
      }
    }
    ```
  EOF
  type = any
  default = {}
}

variable "allowed_ips" {
  description = "A list of allowed IPv4 CIDR blocks."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

resource "random_string" "unique_id" {
   length  = 8
   upper   = false
   lower   = true
   numeric = true
   special = false
}
