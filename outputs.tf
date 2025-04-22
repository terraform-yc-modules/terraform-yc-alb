output "alb_target_group_ids" {
  description = "ALB target group IDs"
  value       = [for target_group in yandex_alb_target_group.target_group : target_group.id]
}
output "alb_target_group_names" {
  description = "ALB target group names"
  value       = [for target_group in yandex_alb_target_group.target_group : target_group.name]
}

output "alb_backend_group_ids" {
  description = "ALB backend group IDs"
  value       = [for backend_group in yandex_alb_backend_group.backend_group : backend_group.id]
}
output "alb_backend_group_names" {
  description = "ALB backend group names"
  value       = [for backend_group in yandex_alb_backend_group.backend_group : backend_group.name]
}

output "alb_http_router_ids" {
  description = "ALB HTTP router IDs"
  value       = var.create_alb ? [for http_router in yandex_alb_http_router.http_router : http_router.id] : []
}
output "alb_http_router_names" {
  description = "ALB HTTP routers names"
  value       = var.create_alb ? [for http_router in yandex_alb_http_router.http_router : http_router.name] : []
}

output "alb_virtual_host_ids" {
  description = "ALB virtual router IDs"
  value       = [for virtual_router in yandex_alb_virtual_host.virtual_router : virtual_router.id]
}
output "alb_virtual_host_names" {
  description = "ALB virtual hosts names"
  value       = [for virtual_router in yandex_alb_virtual_host.virtual_router : virtual_router.name]
}

output "alb_load_balancer_id" {
  description = "ALB ID"
  value       = var.create_alb ? "${yandex_alb_load_balancer.alb_load_balancer[0].id}" : ""
}
output "alb_load_balancer_name" {
  description = "ALB name"
  value       = var.create_alb ? "${yandex_alb_load_balancer.alb_load_balancer[0].name}" : ""
}

output "alb_load_balancer_public_ips" {
  description = "ALB public IPs"
  value       = [for ip in local.alb_external_ip_adresses : ip.address]
}

output "alb_dns_record_cname" {
  description = "ALB DNS record with external IP address"
  value       = var.create_alb && var.public_dns_record ==true ? "${yandex_dns_recordset.alb_external_ip_dns_name[0].name}.${var.public_dns_zone_name}" : ""
}
