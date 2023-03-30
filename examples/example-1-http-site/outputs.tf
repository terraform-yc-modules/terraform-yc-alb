# ALB TG IDs / Names
output "alb_target_group_ids" {
  description = "ALB target group IDs."
  value       = try(module.alb.alb_target_group_ids, null)
}
output "alb_target_group_names" {
  description = "ALB target group names."
  value       = try(module.alb.alb_target_group_names, null)
}

# ALB BG IDs / Names
output "alb_backend_group_ids" {
  description = "ALB backend group IDs."
  value       = try(module.alb.alb_backend_group_ids, null)
}
output "alb_backend_group_names" {
  description = "ALB backend group names."
  value       = try(module.alb.alb_backend_group_names, null)
}

# ALB HR IDs / Names
output "alb_http_router_ids" {
  description = "ALB http router IDs."
  value       = try(module.alb.alb_http_router_ids, null)
}
output "alb_http_router_names" {
  description = "ALB http router names."
  value       = try(module.alb.alb_http_router_names, null)
}

# ALB VH IDs / Names
output "alb_virtual_host_ids" {
  description = "ALB virtual host IDs."
  value       = try(module.alb.alb_virtual_host_ids, null)
}
output "alb_virtual_host_names" {
  description = "ALB virtual host names."
  value       = try(module.alb.alb_virtual_host_names, null)
}

# ALB LB ID / Name
output "alb_load_balancer_id" {
  description = "ALB laod balancer ID."
  value       = try(module.alb.alb_load_balancer_id, null)
}
output "alb_load_balancer_name" {
  description = "ALB laod balancer name."
  value       = try(module.alb.alb_load_balancer_name, null)
}

# ALB LB Public / Private IPs
output "alb_load_balancer_public_ips" {
  description = "ALB Load Balancer Public IPs."
  value = try(module.alb.alb_load_balancer_public_ips, null)
}

output "alb_load_balancer_private_ips" {
  description = "ALB Load Balancer Private IPs."
  value = try(module.alb.alb_load_balancer_private_ips, null)
}

# DNS
output "dns_records_names" {
  description = "DNS records names"
  value = try(module.alb.dns_records_names, null)
}