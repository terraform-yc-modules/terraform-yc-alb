data "yandex_client_config" "client" {}

locals {
  folder_id = var.folder_id == null ? data.yandex_client_config.client.folder_id : var.folder_id

  default_values = {
    region_id          = "ru-central1"
    alb_lb_name        = "alb-load-balancer"
    alb_lb_description = "ALB Load Balancer"
  }

  backend_defaults = {
    weight = 1
    load_balancing_config = {
      panic_threshold                = 50
      locality_aware_routing_percent = 50
      mode                           = "ROUND_ROBIN" # Value: ROUND_ROBIN, RANDOM, LEAST_REQUEST, MAGLEV_HASH
    }
    healthcheck = {
      timeout                 = "1s"
      interval                = "1s"
      interval_jitter_percent = 50
      healthy_threshold       = 50
      unhealthy_threshold     = 50
    }
    http2 = "true"
    http_healthcheck = {
      path = "/"
    }
  }

  handlers_defaults = {
    http2_options = {
      max_concurrent_streams = "10"
    }
  }

  dns_defaults = {
    ttl = 60
  }

  security_groups_list = concat(var.security_groups_ids_list, var.enable_default_rules == true ? [
    yandex_vpc_security_group.alb_main_sg[0].id
    ] : [], length(var.custom_ingress_rules) > 0 || length(var.custom_egress_rules) > 0 ? [
    yandex_vpc_security_group.alb_custom_rules_sg[0].id
  ] : [])
}
#
# ALB Target Group
#
resource "yandex_alb_target_group" "target_group" {
  for_each = try(var.alb_load_balancer.alb_target_groups, {})

  name        = each.key
  description = lookup(each.value, "description", "ALB target group - ${each.key}")
  folder_id   = local.folder_id
  labels      = lookup(each.value, "labels", var.alb_target_group_labels)

  dynamic "target" {
    for_each = lookup(each.value, "targets", [])
    content {
      subnet_id            = try(target.value["subnet_id"], null)
      ip_address           = try(target.value["ip_address"], null)
      private_ipv4_address = try(target.value["private_ipv4_address"], null)
    }
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}
#
# ALB Backend Group
#
resource "yandex_alb_backend_group" "backend_group" {
  for_each = var.alb_load_balancer.alb_backend_groups

  name        = each.key
  folder_id   = local.folder_id
  description = lookup(each.value, "description", "ALB backend group - ${each.key}")
  labels      = lookup(each.value, "labels", var.alb_backend_groups_labels)

  # Only one type of backends http_backend or grpc_backend or stream_backend should be specified.
  dynamic "http_backend" {
    for_each = flatten([lookup(each.value, "http_backends", [])])
    content {
      name             = lookup(http_backend.value, "name", null)
      weight           = lookup(http_backend.value, "weight", local.backend_defaults.weight)
      port             = lookup(http_backend.value, "port", null)
      target_group_ids = concat([for target in try(http_backend.value.target_groups_names_list, []) : yandex_alb_target_group.target_group[target].id], try(http_backend.value.existing_target_groups_ids, []))

      dynamic "tls" {
        for_each = flatten([lookup(http_backend.value, "tls", [])])
        content {
          sni = lookup(tls.value, "sni", null)
          #validation_context.0.trusted_ca_id = lookup(tls.value, "validation_context_trusted_ca_id", null)
          #validation_context.0.trusted_ca_bytes = lookup(tls.value, "validation_context_trusted_ca_bytes", null)
        }
      }

      dynamic "load_balancing_config" {
        for_each = flatten([lookup(http_backend.value, "load_balancing_config", [])])
        content {
          panic_threshold                = lookup(load_balancing_config.value, "panic_threshold", local.backend_defaults.load_balancing_config.panic_threshold)
          locality_aware_routing_percent = lookup(load_balancing_config.value, "locality_aware_routing_percent", local.backend_defaults.load_balancing_config.locality_aware_routing_percent)
          strict_locality                = lookup(load_balancing_config.value, "strict_locality", null)
          mode                           = lookup(load_balancing_config.value, "mode", local.backend_defaults.load_balancing_config.mode)
        }
      }

      dynamic "healthcheck" {
        for_each = flatten([lookup(http_backend.value, "healthcheck", [])])
        content {
          timeout                 = lookup(healthcheck.value, "timeout", local.backend_defaults.healthcheck.timeout)
          interval                = lookup(healthcheck.value, "interval", local.backend_defaults.healthcheck.interval)
          interval_jitter_percent = lookup(healthcheck.value, "interval_jitter_percent", local.backend_defaults.healthcheck.interval_jitter_percent)
          healthy_threshold       = lookup(healthcheck.value, "healthy_threshold", local.backend_defaults.healthcheck.healthy_threshold)
          unhealthy_threshold     = lookup(healthcheck.value, "unhealthy_threshold", local.backend_defaults.healthcheck.unhealthy_threshold)
          healthcheck_port        = lookup(healthcheck.value, "healthcheck_port", null)

          dynamic "http_healthcheck" {
            for_each = flatten([lookup(healthcheck.value, "http_healthcheck", [])])
            content {
              host  = lookup(http_healthcheck.value, "host", null)
              path  = lookup(http_healthcheck.value, "path", local.backend_defaults.http_healthcheck.path)
              http2 = lookup(http_healthcheck.value, "http2", local.backend_defaults.http2)
            }
          }
        }
      }
      http2 = lookup(http_backend.value, "http2", local.backend_defaults.http2)
    }
  }

  dynamic "stream_backend" {
    for_each = flatten([lookup(each.value, "stream_backends", [])])
    content {
      name             = lookup(stream_backend.value, "name", null)
      weight           = lookup(stream_backend.value, "weight", local.backend_defaults.weight)
      port             = lookup(stream_backend.value, "port", null)
      target_group_ids = concat([for target in try(stream_backend.value.target_groups_names_list, []) : yandex_alb_target_group.target_group[target].id], try(stream_backend.value.existing_target_groups_ids, []))

      dynamic "tls" {
        for_each = flatten([lookup(stream_backend.value, "tls", [])])
        content {
          sni = lookup(tls.value, "sni", null)
          #validation_context.0.trusted_ca_id = lookup(tls.value["validation_context_trusted_ca_id"], null)
          #validation_context.0.trusted_ca_bytes = lookup(tls.value["validation_context_trusted_ca_bytes"], null)
        }
      }

      dynamic "load_balancing_config" {
        for_each = flatten([lookup(stream_backend.value, "load_balancing_config", [])])
        content {
          panic_threshold                = lookup(load_balancing_config.value, "panic_threshold", local.backend_defaults.load_balancing_config.panic_threshold)
          locality_aware_routing_percent = lookup(load_balancing_config.value, "locality_aware_routing_percent", local.backend_defaults.load_balancing_config.locality_aware_routing_percent)
          strict_locality                = lookup(load_balancing_config.value, "strict_locality", null)
          mode                           = lookup(load_balancing_config.value, "mode", local.backend_defaults.load_balancing_config.mode)
        }
      }

      dynamic "healthcheck" {
        for_each = flatten([lookup(stream_backend.value, "healthcheck", [])])
        content {
          timeout                 = lookup(healthcheck.value, "timeout", local.backend_defaults.healthcheck.timeout)
          interval                = lookup(healthcheck.value, "interval", local.backend_defaults.healthcheck.interval)
          interval_jitter_percent = lookup(healthcheck.value, "interval_jitter_percent", local.backend_defaults.healthcheck.interval_jitter_percent)
          healthy_threshold       = lookup(healthcheck.value, "healthy_threshold", local.backend_defaults.healthcheck.healthy_threshold)
          unhealthy_threshold     = lookup(healthcheck.value, "unhealthy_threshold", local.backend_defaults.healthcheck.unhealthy_threshold)
          healthcheck_port        = lookup(healthcheck.value, "healthcheck_port", null)

          dynamic "stream_healthcheck" {
            for_each = flatten([lookup(healthcheck.value, "stream_healthcheck", [])])
            content {
              send    = lookup(stream_healthcheck.value, "send", null)
              receive = lookup(stream_healthcheck.value, "receive", null)
            }
          }
        }
      }
    }
  }

  dynamic "grpc_backend" {
    for_each = flatten([lookup(each.value, "grpc_backends", [])])
    content {
      name             = lookup(grpc_backend.value, "name", "grpc-backend-group")
      weight           = lookup(grpc_backend.value, "weight", local.backend_defaults.weight)
      port             = lookup(grpc_backend.value, "port", null)
      target_group_ids = concat([for target in try(grpc_backend.value.target_groups_names_list, []) : yandex_alb_target_group.target_group[target].id], try(grpc_backend.value.existing_target_groups_ids, []))

      dynamic "tls" {
        for_each = flatten([lookup(grpc_backend.value, "tls", [])])
        content {
          sni = lookup(tls.value, "sni", null)
          #validation_context.0.trusted_ca_id = lookup(tls.value["validation_context_trusted_ca_id"], null)
          #validation_context.0.trusted_ca_bytes = lookup(tls.value["validation_context_trusted_ca_bytes"], null)
        }
      }

      dynamic "load_balancing_config" {
        for_each = flatten([lookup(grpc_backend.value, "load_balancing_config", [])])
        content {
          panic_threshold                = lookup(load_balancing_config.value, "panic_threshold", local.backend_defaults.load_balancing_config.panic_threshold)
          locality_aware_routing_percent = lookup(load_balancing_config.value, "locality_aware_routing_percent", local.backend_defaults.load_balancing_config.locality_aware_routing_percent)
          strict_locality                = lookup(load_balancing_config.value, "strict_locality", null)
          mode                           = lookup(load_balancing_config.value, "mode", local.backend_defaults.load_balancing_config.mode)
        }
      }

      dynamic "healthcheck" {
        for_each = flatten([lookup(grpc_backend.value, "healthcheck", [])])
        content {
          timeout                 = lookup(healthcheck.value, "timeout", local.backend_defaults.healthcheck.timeout)
          interval                = lookup(healthcheck.value, "interval", local.backend_defaults.healthcheck.interval)
          interval_jitter_percent = lookup(healthcheck.value, "interval_jitter_percent", local.backend_defaults.healthcheck.interval_jitter_percent)
          healthy_threshold       = lookup(healthcheck.value, "healthy_threshold", local.backend_defaults.healthcheck.healthy_threshold)
          unhealthy_threshold     = lookup(healthcheck.value, "unhealthy_threshold", local.backend_defaults.healthcheck.unhealthy_threshold)
          healthcheck_port        = lookup(healthcheck.value, "healthcheck_port", null)

          dynamic "grpc_healthcheck" {
            for_each = flatten([lookup(healthcheck.value, "grpc_healthcheck", [])])
            content {
              service_name = lookup(grpc_healthcheck.value, "service_name", null)
            }
          }
        }
      }
    }
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  depends_on = [yandex_alb_target_group.target_group]
}

# ALB HTTP Router
resource "yandex_alb_http_router" "http_router" {
  for_each = var.create_alb ? length(var.alb_load_balancer.alb_http_routers) > 0 ? toset(var.alb_load_balancer.alb_http_routers) : toset([]) : toset([])

  name        = each.value
  folder_id   = local.folder_id
  description = "ALB HTTP router - ${each.value}"
  labels      = var.alb_http_routers_labels

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}
#
# ALB Virtual Host
#
resource "yandex_alb_virtual_host" "virtual_router" {
  for_each = var.alb_load_balancer.alb_virtual_hosts

  name           = each.key
  http_router_id = var.create_alb ? "${yandex_alb_http_router.http_router["${each.value.http_router_name}"].id}" : "${var.http_router_id}"
  authority      = lookup(each.value, "authority", [])

  dynamic "modify_request_headers" {
    for_each = flatten([lookup(each.value, "modify_request_headers", [])])
    content {
      name    = lookup(modify_request_headers.value, "name", "${each.key}-modify-request-headers")
      append  = lookup(modify_request_headers.value, "append", null)
      replace = lookup(modify_request_headers.value, "replace", null)
      remove  = lookup(modify_request_headers.value, "remove", null)
    }
  }
  dynamic "modify_response_headers" {
    for_each = flatten([lookup(each.value, "modify_response_headers", [])])
    content {
      name    = lookup(modify_response_headers.value, "name", "${each.key}-modify-response-headers")
      append  = lookup(modify_response_headers.value, "append", null)
      replace = lookup(modify_response_headers.value, "replace", null)
      remove  = lookup(modify_response_headers.value, "remove", null)
    }
  }

  dynamic "route" {
    for_each = flatten([lookup(each.value, "route", [])])

    content {
      name = lookup(route.value, "name", null)
      dynamic "http_route" {
        for_each = flatten([lookup(route.value, "http_route", [])])
        content {
          dynamic "http_match" {
            for_each = flatten([lookup(http_route.value, "http_match", [])])
            content {
              http_method = lookup(http_match.value, "http_method", null)
              dynamic "path" {
                for_each = flatten([lookup(http_match.value, "path", [])])
                # Exactly one type of string matches 'exact', 'prefix' or 'regex' should be specified.
                content {
                  exact  = lookup(http_match.value, "exact", null)
                  prefix = lookup(http_match.value, "prefix", null)
                  regex  = lookup(http_match.value, "regex", null)
                }
              }
            }
          }
          # NOTE: Exactly one type of actions 'http_route_action' or 'redirect_action' or 'direct_response_action' should be specified.
          dynamic "http_route_action" {
            for_each = flatten([lookup(http_route.value, "http_route_action", [])])
            content {
              backend_group_id  = yandex_alb_backend_group.backend_group["${http_route_action.value.backend_group_name}"].id
              timeout           = lookup(http_route_action.value, "timeout", null)
              idle_timeout      = lookup(http_route_action.value, "idle_timeout", null)
              host_rewrite      = lookup(http_route_action.value, "host_rewrite", null)
              auto_host_rewrite = lookup(http_route_action.value, "auto_host_rewrite", null)
              prefix_rewrite    = lookup(http_route_action.value, "prefix_rewrite", null)
              upgrade_types     = lookup(http_route_action.value, "upgrade_types", [])
            }
          }
          dynamic "redirect_action" {
            for_each = flatten([lookup(http_route.value, "redirect_action", [])])
            content {
              replace_scheme = lookup(redirect_action.value, "replace_scheme", null)
              replace_host   = lookup(redirect_action.value, "replace_host", null)
              replace_port   = lookup(redirect_action.value, "replace_port", null)
              replace_path   = lookup(redirect_action.value, "replace_path", null)
              replace_prefix = lookup(redirect_action.value, "replace_prefix", null)
              remove_query   = lookup(redirect_action.value, "remove_query", null)
              response_code  = lookup(redirect_action.value, "response_code", null)
            }
          }
          dynamic "direct_response_action" {
            for_each = flatten([lookup(http_route.value, "direct_response_action", [])])
            content {
              status = lookup(direct_response_action.value, "status", null)
              body   = lookup(direct_response_action.value, "body", null)
            }
          }
        }
      }
      dynamic "grpc_route" {
        for_each = flatten([lookup(route.value, "grpc_route", [])])
        content {
          dynamic "grpc_match" {
            for_each = flatten([lookup(grpc_route.value, "grpc_match", [])])
            content {
              dynamic "fqmn" {
                for_each = flatten([lookup(grpc_match.value, "fqmn", [])])
                content {
                  exact  = lookup(fqmn.value, "exact", null)
                  prefix = lookup(fqmn.value, "prefix", null)
                  regex  = lookup(fqmn.value, "regex", null)
                }
              }
            }
          }
          dynamic "grpc_route_action" {
            for_each = flatten([lookup(grpc_route.value, "grpc_route_action", [])])
            content {
              backend_group_id  = yandex_alb_backend_group.backend_group["${grpc_route_action.value.backend_group_name}"].id
              max_timeout       = lookup(grpc_route_action.value, "max_timeout", null)
              idle_timeout      = lookup(grpc_route_action.value, "idle_timeout", null)
              host_rewrite      = lookup(grpc_route_action.value, "host_rewrite", null)
              auto_host_rewrite = lookup(grpc_route_action.value, "auto_host_rewrite", null)
            }
          }
          dynamic "grpc_status_response_action" {
            for_each = flatten([lookup(grpc_route.value, "grpc_status_response_action", [])])
            content {
              status = lookup(grpc_status_response_action.value, "status", null)
            }
          }
        }
      }
    }
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  depends_on = [
    yandex_alb_target_group.target_group,
    yandex_alb_backend_group.backend_group,
    yandex_alb_http_router.http_router
  ]
}

# Certificate Manager
resource "yandex_cm_certificate" "alb_cm_certificate" {
  count = var.create_certificate ? length(var.alb_certificates) : 0

  name        = var.alb_certificates[count.index].name
  description = try(var.alb_certificates[count.index].description, "ALB CM certificate - ${var.alb_certificates[count.index].name}")
  labels      = try(var.alb_certificates[count.index].labels, var.alb_certificates_labels)
  domains     = can(var.alb_certificates[count.index].self_managed) ? try(var.alb_certificates[count.index].domains, null) : null

  dynamic "managed" {
    for_each = flatten([try(var.alb_certificates[count.index].managed, [])])
    content {
      challenge_type  = lookup(managed.value, "challenge_type", "DNS_CNAME")
      challenge_count = lookup(managed.value, "challenge_count", 1)
    }
  }

  dynamic "self_managed" {
    for_each = flatten([try(var.alb_certificates[count.index].self_managed, [])])
    content {
      certificate = try(self_managed.value.certificate_string, file("${path.module}/${var.tls_cert_path}/${self_managed.value.certificate_filename}"))
      private_key = try(self_managed.value.private_key_string, file("${path.module}/${var.tls_cert_path}/${self_managed.value.private_key_filename}"))
      dynamic "private_key_lockbox_secret" {
        for_each = flatten([lookup(self_managed.value, "private_key_lockbox_secret", [])])
        content {
          id  = lookup(private_key_lockbox_secret.value, "private_key_lockbox_secret_id", null)
          key = lookup(private_key_lockbox_secret.value, "private_key_lockbox_secret_key", null)
        }
      }
    }
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  depends_on = [yandex_alb_virtual_host.virtual_router]
}

resource "yandex_dns_recordset" "alb_cm_certificate_dns_name" {
  count      = var.create_certificate && var.using_self_signed == false ? length(var.alb_certificates) : 0
  zone_id    = try(var.public_dns_zone_id, null)
  name       = yandex_cm_certificate.alb_cm_certificate[count.index].challenges[0].dns_name
  type       = yandex_cm_certificate.alb_cm_certificate[count.index].challenges[0].dns_type
  data       = [yandex_cm_certificate.alb_cm_certificate[count.index].challenges[0].dns_value]
  ttl        = local.dns_defaults.ttl
  depends_on = [yandex_cm_certificate.alb_cm_certificate]
}

# a timer for waiting for ALB certificate will be ISSUED
resource "time_sleep" "wait_for_cert_will_be_issued" {
  count           = var.create_certificate && var.using_self_signed == false ? 1 : 0
  create_duration = var.cert_waiting_timer
  depends_on      = [yandex_dns_recordset.alb_cm_certificate_dns_name]
}

# ALB Load Balancer
resource "yandex_alb_load_balancer" "alb_load_balancer" {
  count      = var.create_alb ? 1 : 0
  folder_id  = local.folder_id
  network_id = var.network_id

  name               = try(var.alb_load_balancer.name, local.default_values.alb_lb_name)
  description        = try(var.alb_load_balancer.description, local.default_values.alb_lb_description)
  labels             = try(var.alb_load_balancer.labels, var.alb_load_balancer_labels)
  region_id          = try(var.alb_load_balancer.region_id, local.default_values.region_id)
  security_group_ids = local.security_groups_list

  allocation_policy {
    dynamic "location" {
      for_each = flatten([try(var.alb_load_balancer.alb_locations, [])])
      content {
        zone_id         = lookup(location.value, "zone", null)
        subnet_id       = lookup(location.value, "subnet_id", null)
        disable_traffic = lookup(location.value, "disable_traffic", var.traffic_disabled)
      }
    }
  }

  dynamic "listener" {
    for_each = flatten([try(var.alb_load_balancer.alb_listeners, [])])
    content {
      name = lookup(listener.value, "name", null)
      dynamic "endpoint" {
        for_each = flatten([lookup(listener.value, "endpoint", [])])
        content {
          # Exactly one type of addresses external_ipv4_address or internal_ipv4_address or external_ipv6_address should be specified.
          dynamic "address" {
            for_each = flatten([lookup(endpoint.value, "address", [])])
            content {
              dynamic "external_ipv4_address" {
                for_each = flatten([lookup(address.value, "external_ipv4_address", [])])
                content {
                  address = lookup(external_ipv4_address.value, "address", null)
                }
              }
              dynamic "internal_ipv4_address" {
                for_each = flatten([lookup(address.value, "internal_ipv4_address", [])])
                content {
                  address   = lookup(internal_ipv4_address.value, "address", null)
                  subnet_id = lookup(internal_ipv4_address.value, "subnet_id", null)
                }
              }
              dynamic "external_ipv6_address" {
                for_each = flatten([lookup(address.value, "external_ipv6_address", [])])
                content {
                  address = lookup(external_ipv6_address.value, "address", null)
                }
              }
            }
          }
          ports = lookup(endpoint.value, "ports", [])
        }
      }
      dynamic "http" {
        for_each = flatten([lookup(listener.value, "http", [])])
        content {
          dynamic "handler" {
            for_each = flatten([lookup(http.value, "handler", [])])
            content {
              http_router_id     = yandex_alb_http_router.http_router["${handler.value.http_router_name}"].id
              rewrite_request_id = lookup(handler.value, "rewrite_request_id", null)
              dynamic "http2_options" {
                for_each = flatten([lookup(handler.value, "http2_options", [])])
                content {
                  max_concurrent_streams = lookup(http2_options.value, "max_concurrent_streams", local.handlers_defaults.http2_options.max_concurrent_streams)
                }
              }
              allow_http10 = lookup(handler.value, "allow_http10", null)
            }
          }
          dynamic "redirects" {
            for_each = flatten([lookup(http.value, "redirects", [])])
            content {
              http_to_https = lookup(redirects.value, "http_to_https", null)
            }
          }
        }
      }
      dynamic "stream" {
        for_each = flatten([lookup(listener.value, "stream", [])])
        content {
          dynamic "handler" {
            for_each = flatten([lookup(stream.value, "handler", [])])
            content {
              backend_group_id = yandex_alb_backend_group.backend_group[handler.value.backend_group_name].id
            }
          }
        }
      }
      dynamic "tls" {
        for_each = flatten([lookup(listener.value, "tls", [])])
        content {
          dynamic "default_handler" {
            for_each = flatten([lookup(tls.value, "default_handler", [])])
            content {
              dynamic "http_handler" {
                for_each = flatten([lookup(default_handler.value, "http_handler", [])])
                content {
                  http_router_id     = yandex_alb_http_router.http_router["${http_handler.value.http_router_name}"].id
                  rewrite_request_id = lookup(http_handler.value, "rewrite_request_id", null)
                  dynamic "http2_options" {
                    for_each = flatten([lookup(http_handler.value, "http2_options", [])])
                    content {
                      max_concurrent_streams = lookup(http2_options.value, "max_concurrent_streams", local.handlers_defaults.http2_options.max_concurrent_streams)
                    }
                  }
                  allow_http10 = lookup(http_handler.value, "allow_http10", null)
                }
              }
              dynamic "stream_handler" {
                for_each = flatten([lookup(default_handler.value, "stream_handler", [])])
                content {
                  backend_group_id = yandex_alb_backend_group.backend_group[stream_handler.value.backend_group_name].id
                }
              }
              # NOTE: if create_certificate = true, certificate should be passed as a name of newly created certificate or as a list of previously created CM certificate ids 
              certificate_ids = var.create_certificate ? compact([for cert in yandex_cm_certificate.alb_cm_certificate : cert.name == default_handler.value.cert_name ? "${cert.id}" : ""]) : default_handler.value.certificate_ids
            }
          }
          dynamic "sni_handler" {
            for_each = flatten([lookup(tls.value, "sni_handlers", [])])
            content {
              name         = lookup(sni_handler.value, "name", null)
              server_names = lookup(sni_handler.value, "server_names", [])
              dynamic "handler" {
                for_each = flatten([lookup(sni_handler.value, "handler", [])])
                content {
                  dynamic "http_handler" {
                    for_each = flatten([lookup(handler.value, "http_handler", [])])
                    content {
                      http_router_id     = yandex_alb_http_router.http_router["${http_handler.value.http_router_name}"].id
                      rewrite_request_id = lookup(http_handler.value, "rewrite_request_id", null)
                      dynamic "http2_options" {
                        for_each = flatten([lookup(http_handler.value, "http2_options", [])])
                        content {
                          max_concurrent_streams = lookup(http2_options.value, "max_concurrent_streams", local.handlers_defaults.http2_options.max_concurrent_streams)
                        }
                      }
                      allow_http10 = lookup(http_handler.value, "allow_http10", null)
                    }
                  }
                  dynamic "stream_handler" {
                    for_each = flatten([lookup(handler.value, "stream_handler", [])])
                    content {
                      backend_group_id = yandex_alb_backend_group.backend_group[stream_handler.value.backend_group_name].id
                    }
                  }
                  certificate_ids = var.create_certificate ? compact([for cert in yandex_cm_certificate.alb_cm_certificate : cert.name == handler.value.cert_name ? "${cert.id}" : ""]) : handler.value.certificate_ids
                }
              }
            }
          }
        }
      }
    }
  }

  dynamic "log_options" {
    for_each = flatten([try(var.alb_load_balancer.log_options, [])])
    content {
      disable      = lookup(log_options.value, "disable", true)
      log_group_id = lookup(log_options.value, "log_group_id", null)
      dynamic "discard_rule" {
        for_each = flatten([lookup(log_options.value, "discard_rules", [])])
        content {
          http_codes          = lookup(discard_rule.value, "http_codes", null)
          http_code_intervals = lookup(discard_rule.value, "http_code_intervals", null)
          grpc_codes          = lookup(discard_rule.value, "gprc_codes", null)
          discard_percent     = lookup(discard_rule.value, "discard_percent", null)
        }
      }
    }
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  depends_on = [
    yandex_alb_http_router.http_router,
    yandex_alb_virtual_host.virtual_router,
    yandex_cm_certificate.alb_cm_certificate,
    yandex_dns_recordset.alb_cm_certificate_dns_name,
    time_sleep.wait_for_cert_will_be_issued
  ]
}

locals {
  alb_external_ip_adresses = var.create_alb ? concat(flatten([
    for listener in yandex_alb_load_balancer.alb_load_balancer[0].listener : [
      for endpoint in listener.endpoint : [
        for addr in endpoint.address : addr.external_ipv4_address
      ]
    ]
  ])) : []
}

resource "yandex_dns_recordset" "alb_external_ip_dns_name" {
  count      = var.create_alb && var.public_dns_record ==true ? 1 : 0
  zone_id    = try(var.public_dns_zone_id, null)
  name       = try(var.alb_load_balancer.name, null)
  type       = "CNAME"
  data       = [local.alb_external_ip_adresses[count.index].address]
  ttl        = local.dns_defaults.ttl
  depends_on = [yandex_alb_load_balancer.alb_load_balancer]
}
