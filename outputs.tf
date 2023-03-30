output "alb_target_group_ids" {
  description = "ALB target group IDs."
  value = [ for target_group in yandex_alb_target_group.target_group : target_group.id ]
}
output "alb_target_group_names" {
  description = "ALB target group names."
  value = [ for target_group in yandex_alb_target_group.target_group : target_group.name ]
}

output "alb_backend_group_ids" {
  description = "ALB backend group IDs."
  value = [ for backend_group in yandex_alb_backend_group.backend_group : backend_group.id ]
}
output "alb_backend_group_names" {
  description = "ALB backend group names."
  value = [ for backend_group in yandex_alb_backend_group.backend_group : backend_group.name ]
}

output "alb_http_router_ids" {
  description = "ALB http router IDs."
  value = [ for http_router in yandex_alb_http_router.http_router : http_router.id ]
}
output "alb_http_router_names" {
  description = "ALB HTTP routers names."
  value = [ for http_router in yandex_alb_http_router.http_router : http_router.name ]
}

output "alb_virtual_host_ids" {
  description = "ALB virtual router IDs."
  value = [ for virtual_router in yandex_alb_virtual_host.virtual_router : virtual_router.id ]
}
output "alb_virtual_host_names" {
  description = "ALB virtual hosts names."
  value = [ for virtual_router in yandex_alb_virtual_host.virtual_router : virtual_router.name ]
}

output "alb_load_balancer_id" {
  description = "ALB load balancer ID."
  value = "${yandex_alb_load_balancer.alb_load_balancer.id}"
}
output "alb_load_balancer_name" {
  description = "ALB load balancer name."
  value = "${yandex_alb_load_balancer.alb_load_balancer.name}"
}

output "alb_load_balancer_public_ips" {
  description = "ALB Load Balancer Public IPs."
  value = [ for addr in yandex_alb_load_balancer.alb_load_balancer.listener[0].endpoint[0].address: addr.external_ipv4_address ]
}

output "alb_load_balancer_private_ips" {
  description = "ALB Load Balancer Private IPs."
  value = [ for addr in yandex_alb_load_balancer.alb_load_balancer.listener[0].endpoint[0].address: addr.internal_ipv4_address ]
}

# DNS
output "dns_records_names" {
  description = "DNS records names"
  value       = var.create_certificate ? [ for record in yandex_dns_recordset.alb_cm_certificate_dns_name : record.name ] : []
}